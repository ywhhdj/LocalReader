package com.demo.data.parser

import android.util.Xml

import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.URLDecoder
import java.nio.charset.Charset
import java.nio.charset.StandardCharsets
import java.util.zip.ZipEntry
import java.util.zip.ZipFile

import org.xmlpull.v1.XmlPullParser

import com.demo.core.common.AppError
import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.Logger
import com.demo.core.model.Book
import com.demo.core.model.BookBlock
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.core.model.Chapter
import com.demo.data.cover.CoverStore
import com.demo.data.cover.TextCoverFactory
import com.demo.domain.repository.NovelContent



/**
 * EPUB 解析（零第三方依赖）：container.xml → OPF → (nav.xhtml | toc.ncx) → spine 章节正文。
 *
 * 1. 命名空间：Android XmlPullParser 在 FEATURE_PROCESS_NAMESPACES=false 时 getName() 返回带前缀的
 *    原始名（如 dc:title），旧实现直接比较 "title" 导致标题/作者永远为空 —— 统一取 localName。
 * 2. 编码：OPF/章节按 XML 声明与 <meta charset> 探测，中文 GBK EPUB 不再乱码。
 * 3. 章节 href：剥离 #锚点，并按 nav/ncx 所在目录解析相对路径，避免"章节缺失"。
 * 4. 图片：按章节文件所在目录解析相对 src。
 * 5. 封面：meta cover → item[properties=cover-image] → 首章节首图 → 文字占位封面。
 */
class EpubParser(
    private val coverStore: CoverStore,
    private val bookCacheDir: File,
    private val textCoverFactory: TextCoverFactory = TextCoverFactory()
) : NovelParser {

    override fun matches(file: File, ext: String): Boolean =
        ext.equals("epub", ignoreCase = true)

    override suspend fun parseMeta(file: File): Book? = runCatching {
        ZipFile(file).use { zip ->
            val opfPath = resolveOpfPath(zip) ?: return null
            val opfBytes = readEntryBytes(zip, opfPath) ?: return null
            val opf = parseOpf(opfBytes)
            val basePath = opfPath.substringBeforeLast('/', "")
            val chapters = resolveChapters(zip, opf, basePath)

            val coverPath = resolveCover(zip, opf, basePath, file, chapters)

            Book(
                title = opf.title.ifBlank { FileUtil.humanTitle(file.name) },
                author = opf.author.ifBlank { "未知" },
                type = BookType.NOVEL,
                format = BookFormat.EPUB,
                filePath = file.absolutePath,
                coverPath = coverPath,
                sizeBytes = file.length(),
                chapterCount = chapters.size,
                metaJson = EpubMetaCodec.encode(opfPath, chapters)
            )
        }
    }.getOrNull()

    override suspend fun openNovel(file: File, book: Book): NovelContent {
        val (opfPath, chapters) = EpubMetaCodec.decode(book.metaJson)
        val basePath = opfPath.substringBeforeLast('/', "")
        return EpubNovelContent(
            file = file,
            bookId = book.id,
            chapters = chapters,
            basePath = basePath,
            cacheDir = File(bookCacheDir, book.id.toString())
        )
    }

    // ---------- container / OPF ----------

    private fun resolveOpfPath(zip: ZipFile): String? {
        val container = zip.getEntry("META-INF/container.xml")?.let { readEntryBytes(zip, it) }
        if (container != null) {
            val path = parseContainer(container)
            if (!path.isNullOrBlank() && zip.getEntry(path) != null) return path
            // 大小写/编码差异：按名字尾匹配
            val decoded = decodePath(path.orEmpty())
            zip.entries().toList().firstOrNull {
                it.name.equals(path, true) || it.name.equals(decoded, true) ||
                    it.name.endsWith(decoded.substringAfterLast('/'), true)
            }?.let { return it.name }
        }
        return zip.entries().toList().firstOrNull {
            !it.isDirectory && it.name.endsWith(".opf", true)
        }?.name
    }

    private fun parseContainer(bytes: ByteArray): String? {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(ByteArrayInputStream(bytes), detectXmlEncoding(bytes).name())
        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            if (event == XmlPullParser.START_TAG && localName(parser) == "rootfile") {
                val media = parser.getAttributeValue(null, "media-type")
                val path = parser.getAttributeValue(null, "full-path")
                if (!path.isNullOrBlank() && (media == null || media.contains("oebps-package"))) {
                    return decodePath(path)
                }
            }
            event = parser.next()
        }
        return null
    }

    private fun parseOpf(bytes: ByteArray): Opf {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(ByteArrayInputStream(bytes), detectXmlEncoding(bytes).name())
        var title = ""
        var author = ""
        var coverId: String? = null
        var tocId: String? = null
        var inMetadata = false
        var inSpine = false
        val manifest = LinkedHashMap<String, ManifestItem>()
        val spine = ArrayList<String>()
        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.START_TAG -> {
                    val name = localName(parser)
                    when {
                        name == "metadata" -> inMetadata = true
                        inMetadata && name == "title" -> if (title.isBlank()) title = readText(parser)
                        inMetadata && name == "creator" -> if (author.isBlank()) author = readText(parser)
                        name == "meta" && parser.getAttributeValue(null, "name") == "cover" ->
                            coverId = parser.getAttributeValue(null, "content")
                        name == "item" -> {
                            val id = parser.getAttributeValue(null, "id") ?: ""
                            val href = decodePath(parser.getAttributeValue(null, "href") ?: "")
                            val media = parser.getAttributeValue(null, "media-type") ?: ""
                            val props = parser.getAttributeValue(null, "properties") ?: ""
                            if (id.isNotBlank() && href.isNotBlank()) {
                                manifest[id] = ManifestItem(href, media, props)
                                if (props.contains("cover-image")) coverId = coverId ?: id
                                if (props.contains("nav")) tocId = id
                            }
                        }
                        name == "spine" -> {
                            inSpine = true
                            val toc = parser.getAttributeValue(null, "toc")
                            if (!toc.isNullOrBlank()) tocId = tocId ?: toc
                        }
                        name == "itemref" && inSpine ->
                            parser.getAttributeValue(null, "idref")?.let { spine.add(it) }
                    }
                }
                XmlPullParser.END_TAG -> when (localName(parser)) {
                    "metadata" -> inMetadata = false
                    "spine" -> inSpine = false
                }
            }
            event = parser.next()
        }
        return Opf(title.trim(), author.trim(), coverId, tocId, manifest, spine)
    }

    // ---------- 目录 ----------

    private fun resolveChapters(zip: ZipFile, opf: Opf, basePath: String): List<Chapter> {
        // EPUB3 nav
        opf.tocId?.let { id ->
            val navPath = opf.manifest[id]?.href?.let { joinPath(basePath, it) }
            val entry = navPath?.let { zip.getEntry(it) }
            if (entry != null) {
                val bytes = readEntryBytes(zip, entry)
                if (bytes != null) {
                    val navDir = entry.name.substringBeforeLast('/', "")
                    val nav = parseNavXhtml(bytes, navDir)
                    if (nav.isNotEmpty()) return nav
                }
            }
        }
        // EPUB2 ncx
        val ncxItem = opf.manifest.values.firstOrNull { it.mediaType == NCX_MEDIA_TYPE }
            ?: opf.manifest.values.firstOrNull { it.href.endsWith(".ncx", true) }
        if (ncxItem != null) {
            val ncxPath = joinPath(basePath, ncxItem.href)
            val entry = zip.getEntry(ncxPath)
            if (entry != null) {
                val bytes = readEntryBytes(zip, entry)
                if (bytes != null) {
                    val ncxDir = entry.name.substringBeforeLast('/', "")
                    val ncx = parseNcx(bytes, ncxDir)
                    if (ncx.isNotEmpty()) return ncx
                }
            }
        }
        // 兜底：spine 顺序
        return opf.spine.mapIndexedNotNull { index, idref ->
            val href = opf.manifest[idref]?.href ?: return@mapIndexedNotNull null
            Chapter(index, "第 ${index + 1} 章", joinPath(basePath, href))
        }
    }

    private fun parseNavXhtml(bytes: ByteArray, navDir: String): List<Chapter> {
        val text = String(bytes, detectHtmlCharset(bytes))
        val result = ArrayList<Chapter>()
        val anchor = Regex("""<a[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)</a>""", RegexOption.IGNORE_CASE)
        val navBlock = Regex("""<nav[\s\S]*?</nav>""", RegexOption.IGNORE_CASE).findAll(text)
            .map { it.value }
            .firstOrNull { it.contains("toc", true) || it.contains("nav", true) }
            ?: Regex("""<nav[\s\S]*?</nav>""", RegexOption.IGNORE_CASE).find(text)?.value
            ?: text
        var index = 0
        for (m in anchor.findAll(navBlock)) {
            val href = stripFragment(m.groupValues[1])
            val label = plainOf(m.groupValues[2])
            if (href.isBlank() || label.isBlank()) continue
            if (result.any { it.href == joinPath(navDir, href) }) continue
            result.add(Chapter(index++, label, joinPath(navDir, href)))
        }
        return result
    }

    private fun parseNcx(bytes: ByteArray, ncxDir: String): List<Chapter> {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        return runCatching {
            parser.setInput(ByteArrayInputStream(bytes), detectXmlEncoding(bytes).name())
            val result = ArrayList<Chapter>()
            var label = ""
            var src = ""
            var event = parser.eventType
            while (event != XmlPullParser.END_DOCUMENT) {
                when (event) {
                    XmlPullParser.START_TAG -> when (localName(parser)) {
                        "text" -> label = readText(parser)
                        "content" -> src = parser.getAttributeValue(null, "src") ?: ""
                    }
                    XmlPullParser.END_TAG -> if (localName(parser) == "navPoint") {
                        val clean = stripFragment(src)
                        if (clean.isNotBlank()) {
                            val href = joinPath(ncxDir, clean)
                            if (result.none { it.href == href }) {
                                result.add(Chapter(result.size, label.trim().ifBlank { "第 ${result.size + 1} 章" }, href))
                            }
                        }
                        label = ""
                        src = ""
                    }
                }
                event = parser.next()
            }
            result
        }.getOrDefault(emptyList())
    }

    // ---------- 封面 ----------

    private fun resolveCover(
        zip: ZipFile,
        opf: Opf,
        basePath: String,
        file: File,
        chapters: List<Chapter>
    ): String? {
        val hrefs = ArrayList<String>()
        opf.coverId?.let { opf.manifest[it]?.href }?.let { hrefs.add(joinPath(basePath, it)) }
        opf.manifest.values.firstOrNull { it.mediaType.startsWith("image/") }
            ?.let { hrefs.add(joinPath(basePath, it.href)) }
        chapters.firstNotNullOfOrNull { ch ->
            val entry = zip.getEntry(ch.href)
            if (entry == null) null
            else {
                val bytes = readEntryBytes(zip, entry)
                val html = bytes?.let { String(it, detectHtmlCharset(it)) }
                html?.let {
                    Regex("""<img[^>]*src\s*=\s*["']([^"']+)["']""", RegexOption.IGNORE_CASE).find(it)
                        ?.groupValues?.get(1)
                }?.let { joinPath(entry.name.substringBeforeLast('/', ""), it) }
            }
        }?.let { hrefs.add(it) }

        for (href in hrefs) {
            val entry = zip.getEntry(href) ?: zip.getEntry(decodePath(href)) ?: continue
            val cover = runCatching { coverStore.save(zip.getInputStream(entry), file.absolutePath) }.getOrNull()
            if (cover != null) return cover
        }
        // 兜底：文字占位封面
        return runCatching {
            coverStore.save(textCoverFactory.create(FileUtil.humanTitle(file.name)), file.absolutePath)
        }.getOrNull()
    }

    // ---------- 工具 ----------

    private fun localName(parser: XmlPullParser): String = parser.name.substringAfter(':')

    private fun readText(parser: XmlPullParser): String {
        val sb = StringBuilder()
        var event = parser.next()
        while (event != XmlPullParser.END_TAG && event != XmlPullParser.END_DOCUMENT) {
            if (event == XmlPullParser.TEXT || event == XmlPullParser.CDSECT) {
                sb.append(parser.text)
            } else if (event == XmlPullParser.START_TAG) {
                // 嵌套标签（如 <dc:title><b>xxx</b></dc:title>）：跳过标签本身
            }
            event = parser.next()
        }
        return sb.toString().trim()
    }

    private fun plainOf(html: String): String {
        val noTag = html.replace(Regex("""<[^>]+>"""), " ")
        return HtmlExtractor.decodeEntitiesStatic(noTag).replace(Regex("""\s+"""), " ").trim()
    }

    private fun stripFragment(href: String): String {
        val i = href.indexOf('#')
        return (if (i >= 0) href.substring(0, i) else href).trim()
    }

    private fun decodePath(path: String): String = runCatching {
        URLDecoder.decode(path, "UTF-8")
    }.getOrDefault(path)

    private fun joinPath(basePath: String, href: String): String {
        val decoded = decodePath(href).trim().trimStart('/')
        if (decoded.startsWith(basePath) && basePath.isNotBlank()) return decoded
        return if (basePath.isBlank()) decoded else "$basePath/$decoded"
    }

    private fun readEntryBytes(zip: ZipFile, path: String): ByteArray? =
        runCatching { zip.getInputStream(zip.getEntry(path) ?: return null).use { it.readBytes() } }.getOrNull()

    private fun readEntryBytes(zip: ZipFile, entry: ZipEntry): ByteArray? =
        runCatching { zip.getInputStream(entry).use { it.readBytes() } }.getOrNull()

    /** XML 声明编码探测 */
    private fun detectXmlEncoding(bytes: ByteArray): Charset {
        val head = String(bytes, 0, minOf(bytes.size, 256), StandardCharsets.ISO_8859_1)
        Regex("""encoding\s*=\s*["']([^"']+)""", RegexOption.IGNORE_CASE).find(head)
            ?.groupValues?.get(1)?.let { return charsetOf(it) }
        return StandardCharsets.UTF_8
    }

    /** HTML 编码探测：XML 声明 → <meta charset> → UTF-8 */
    private fun detectHtmlCharset(bytes: ByteArray): Charset {
        val head = String(bytes, 0, minOf(bytes.size, 2048), StandardCharsets.ISO_8859_1)
        Regex("""<meta[^>]+charset\s*=\s*["']?([A-Za-z0-9\-_]+)""", RegexOption.IGNORE_CASE).find(head)
            ?.groupValues?.get(1)?.let { return charsetOf(it) }
        return detectXmlEncoding(bytes)
    }

    private fun charsetOf(name: String): Charset = runCatching { Charset.forName(name.trim()) }
        .getOrDefault(StandardCharsets.UTF_8)

    private data class Opf(
        val title: String,
        val author: String,
        val coverId: String?,
        val tocId: String?,
        val manifest: Map<String, ManifestItem>,
        val spine: List<String>
    )

    private data class ManifestItem(val href: String, val mediaType: String, val properties: String)

    private companion object {
        const val NCX_MEDIA_TYPE = "application/x-dtbncx+xml"
    }

    // ---------- 已打开的书 ----------

    private inner class EpubNovelContent(
        private val file: File,
        private val bookId: Long,
        override val chapters: List<Chapter>,
        private val basePath: String,
        private val cacheDir: File
    ) : NovelContent {

        @Volatile
        private var zip: ZipFile? = null
        private val lock = Any()

        private fun zip(): ZipFile = zip ?: synchronized(lock) { zip ?: ZipFile(file).also { zip = it } }

        override suspend fun loadChapter(index: Int): List<BookBlock> {
            val chapter = chapters.getOrNull(index) ?: return emptyList()
            val zf = zip()
            val entry = resolveEntry(zf, chapter.href)
                ?: return listOf(BookBlock.Paragraph("（章节缺失：${chapter.title}）"))
            val bytes = readEntryBytes(zf, entry) ?: return listOf(BookBlock.Paragraph("（章节读取失败）"))
            val charset = detectHtmlCharset(bytes)
            var html = String(bytes, charset)
            // 少数中文 EPUB 声明为 UTF-8 实为 GBK：出现大量替换字符时回退
            if (charset == StandardCharsets.UTF_8 && html.count { it == '\uFFFD' } > 8) {
                html = String(bytes, charsetOf("GBK"))
            }
            val chapterDir = entry.name.substringBeforeLast('/', "")
            return HtmlExtractor.extract(html) { src -> resolveImage(zf, chapterDir, src) }
        }

        private fun resolveEntry(zf: ZipFile, href: String): ZipEntry? {
            val clean = stripFragment(href)
            zf.getEntry(clean)?.let { return it }
            zf.getEntry(joinPath(basePath, clean))?.let { return it }
            zf.getEntry(decodePath(clean))?.let { return it }
            val tail = clean.substringAfterLast('/')
            if (tail.isBlank()) return null
            return zf.entries().toList().firstOrNull {
                !it.isDirectory && (it.name.equals(clean, true) || it.name.endsWith("/$tail", true) ||
                    it.name.equals(tail, true))
            }
        }

        /** 图片按需落地：相对章节目录 → 相对 OPF 目录 → 全包名匹配 */
        private fun resolveImage(zf: ZipFile, chapterDir: String, src: String): String? {
            val clean = stripFragment(src)
            if (clean.startsWith("data:", true)) return null
            val candidates = listOf(
                joinPath(chapterDir, clean),
                joinPath(basePath, clean),
                clean
            )
            var entry: ZipEntry? = null
            for (c in candidates) {
                entry = zf.getEntry(c)
                if (entry != null) break
            }
            if (entry == null) {
                val tail = clean.substringAfterLast('/')
                entry = zf.entries().toList().firstOrNull {
                    !it.isDirectory && it.name.endsWith(tail, true)
                } ?: return null
            }
            if (!ensureCacheBudget()) return null
            val ext = FileUtil.extension(entry.name).ifBlank { "jpg" }
            val outFile = File(cacheDir, FileUtil.md5(entry.name) + "." + ext.take(5))
            if (outFile.exists() && outFile.length() > 0) return outFile.absolutePath
            return runCatching {
                cacheDir.mkdirs()
                zf.getInputStream(entry!!).use { input ->
                    FileOutputStream(outFile).use { output -> input.copyTo(output) }
                }
                outFile.absolutePath
            }.onFailure { outFile.delete() }.getOrNull()
        }

        /** 每本图片的磁盘预算（默认 20MB） */
        private fun ensureCacheBudget(): Boolean {
            return runCatching {
                FileUtil.dirSize(cacheDir) < Constants.BOOK_IMAGE_CACHE_MAX_BYTES
            }.getOrDefault(false)
        }

        override fun close() {
            synchronized(lock) {
                runCatching { zip?.close() }
                zip = null
            }
        }
    }
}
