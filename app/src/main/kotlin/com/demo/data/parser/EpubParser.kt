package com.demo.data.parser

import android.util.Xml

import com.demo.core.common.util.FileUtil
import com.demo.core.model.Book
import com.demo.core.model.BookBlock
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.core.model.Chapter
import com.demo.core.common.util.Logger
import com.demo.domain.repository.NovelContent


import org.xmlpull.v1.XmlPullParser

import java.io.File
import java.io.FileOutputStream
import java.net.URLDecoder
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.nio.charset.Charset

/**
 * EPUB 解析（零第三方依赖）：
 * container.xml → OPF → (nav.xhtml | toc.ncx) → spine 章节正文。
 * 章节惰性读取；图片按需解压到 files/bookcache/{bookId}/。
 */
class EpubParser(
    private val coverStore: com.demo.data.cache.CoverStore,
    private val bookCacheDir: File
) : NovelParser {

    override fun matches(file: File, ext: String): Boolean =
        ext.equals("epub", ignoreCase = true)

    override suspend fun parseMeta(file: File): Book? = runCatching {
        ZipFile(file).use { zip ->
            val containerEntry = zip.getEntry("META-INF/container.xml") ?: return null
            val opfPath = parseContainer(
                zip.getInputStream(containerEntry).use { it.readBytes().inputStream() }
            ) ?: return null
            val opfEntry = zip.getEntry(opfPath) ?: zip.entries().toList()
                .firstOrNull { it.name.endsWith(".opf") } ?: return null
            val opf = parseOpf(
                zip.getInputStream(opfEntry).use { it.readBytes().inputStream() }
            ) ?: return null

            val basePath = opfPath.substringBeforeLast('/', "")
            val chapters = resolveChapters(zip, opf, basePath)

            val coverHref = opf.coverId?.let { opf.manifest[it]?.href }?.let { joinPath(basePath, it) }
                ?: findFirstImageHref(zip, opf, basePath)
            val coverPath = coverHref?.let { href ->
                zip.getEntry(href)?.let { entry ->
                    runCatching { coverStore.save(zip.getInputStream(entry), file.absolutePath) }.getOrNull()
                }
            }

            Book(
                title = opf.title.ifBlank { FileUtil.humanTitle(file.name) },
                author = opf.author,
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

    // ---------- container / OPF / 目录 ----------

    private fun parseContainer(input: java.io.InputStream): String? {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(input, "UTF-8")
        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            if (event == XmlPullParser.START_TAG && parser.name == "rootfile") {
                val path = parser.getAttributeValue(null, "full-path")
                if (!path.isNullOrBlank()) return path
            }
            event = parser.next()
        }
        return null
    }

    private fun parseOpf(input: java.io.InputStream): Opf? {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(input, "UTF-8")
        var title = ""
        var author = ""
        var coverId: String? = null
        var tocId: String? = null
        val manifest = LinkedHashMap<String, ManifestItem>()
        val spine = ArrayList<String>()
        var event = parser.eventType
        var inSpine = false
        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.START_TAG -> when (parser.name) {
                    "title" -> if (title.isBlank()) title = readText(parser)
                    "creator" -> if (author.isBlank()) author = readText(parser)
                    "meta" -> {
                        if (parser.getAttributeValue(null, "name") == "cover") {
                            coverId = parser.getAttributeValue(null, "content")
                        }
                    }
                    "item" -> {
                        val id = parser.getAttributeValue(null, "id") ?: ""
                        val href = parser.getAttributeValue(null, "href") ?: ""
                        val media = parser.getAttributeValue(null, "media-type") ?: ""
                        val props = parser.getAttributeValue(null, "properties") ?: ""
                        if (id.isNotBlank() && href.isNotBlank()) {
                            manifest[id] = ManifestItem(href, media, props)
                            if (props.contains("nav")) tocId = id
                        }
                    }
                    "spine" -> {
                        inSpine = true
                        val toc = parser.getAttributeValue(null, "toc")
                        if (!toc.isNullOrBlank()) tocId = toc
                    }
                    "itemref" -> if (inSpine) {
                        parser.getAttributeValue(null, "idref")?.let { spine.add(it) }
                    }
                }
                XmlPullParser.END_TAG -> if (parser.name == "spine") inSpine = false
            }
            event = parser.next()
        }
        return Opf(title.trim(), author.trim(), coverId, tocId, manifest, spine)
    }

    private fun resolveChapters(zip: ZipFile, opf: Opf, basePath: String): List<Chapter> {
        // EPUB3 nav
        opf.tocId?.let { id ->
            val href = opf.manifest[id]?.href
            if (href != null) {
                val entry = zip.getEntry(joinPath(basePath, href))
                if (entry != null) {
                    val nav = parseNavXhtml(
                        zip.getInputStream(entry).use { it.readBytes().inputStream() }
                    )
                    if (nav.isNotEmpty()) return nav
                }
            }
        }
        // EPUB2 ncx
        val ncxEntry = opf.manifest.values.firstOrNull { it.mediaType == "application/x-dtbncx+xml" }
            ?.let { zip.getEntry(joinPath(basePath, it.href)) }
        if (ncxEntry != null) {
            val ncx = parseNcx(
                zip.getInputStream(ncxEntry).use { it.readBytes().inputStream() }
            )
            if (ncx.isNotEmpty()) return ncx
        }
        // 兜底：spine 顺序
        return opf.spine.mapIndexedNotNull { index, idref ->
            opf.manifest[idref]?.href?.let { Chapter(index, "第 ${index + 1} 章", it) }
        }
    }

    private fun parseNavXhtml(input: java.io.InputStream): List<Chapter> {
        val text = runCatching { input.readBytes().toString(Charsets.UTF_8) }.getOrNull() ?: return emptyList()
        val result = ArrayList<Chapter>()
        val anchor = Regex("""<a[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)</a>""", RegexOption.IGNORE_CASE)
        val navBlocks = Regex("""<nav[\s\S]*?</nav>""", RegexOption.IGNORE_CASE).findAll(text)
        val scope = navBlocks.firstOrNull()?.value ?: text
        var index = 0
        for (m in anchor.findAll(scope)) {
            val href = m.groupValues[1]
            val label = HtmlExtractor.extract(m.groupValues[2])
                .filterIsInstance<BookBlock.Paragraph>()
                .firstOrNull()?.text
                ?: m.groupValues[2].replace(Regex("""<[^>]+>"""), "").trim()
            if (label.isBlank()) continue
            result.add(Chapter(index++, label, href))
        }
        return result
    }

    private fun parseNcx(input: java.io.InputStream): List<Chapter> {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        return runCatching {
            parser.setInput(input, "UTF-8")
            val result = ArrayList<Chapter>()
            var event = parser.eventType
            var label = ""
            var src = ""
            while (event != XmlPullParser.END_DOCUMENT) {
                when (event) {
                    XmlPullParser.START_TAG -> when (parser.name) {
                        "text" -> label = readText(parser)
                        "content" -> src = parser.getAttributeValue(null, "src") ?: ""
                    }
                    XmlPullParser.END_TAG -> if (parser.name == "navPoint") {
                        if (src.isNotBlank()) result.add(Chapter(result.size, label.trim(), src))
                        label = ""
                        src = ""
                    }
                }
                event = parser.next()
            }
            result
        }.getOrDefault(emptyList())
    }

    private fun findFirstImageHref(zip: ZipFile, opf: Opf, basePath: String): String? {
        val spineHrefs = opf.spine.mapNotNull { opf.manifest[it]?.href }
        val firstHtml = spineHrefs.firstOrNull { it.endsWith(".html", true) || it.endsWith(".xhtml", true) }
        if (firstHtml != null) {
            val entry = zip.getEntry(joinPath(basePath, firstHtml))
            if (entry != null) {
                val html = runCatching { zip.getInputStream(entry).readBytes().toString(Charsets.UTF_8) }.getOrNull()
                if (html != null) {
                    val img = Regex("""<img[^>]*src\s*=\s*["']([^"']+)["']""", RegexOption.IGNORE_CASE).find(html)
                    img?.groupValues?.get(1)?.let { return joinPath(basePath, it) }
                }
            }
        }
        return opf.manifest.values.firstOrNull { it.mediaType.startsWith("image/") }
            ?.let { joinPath(basePath, it.href) }
    }

    private fun readText(parser: XmlPullParser): String {
        var text = ""
        if (parser.next() == XmlPullParser.TEXT) {
            text = parser.text
            parser.next()
        }
        return text
    }

    private fun joinPath(basePath: String, href: String): String {
        val decoded = runCatching { URLDecoder.decode(href, "UTF-8") }.getOrDefault(href)
        val clean = decoded.trimStart('/')
        return if (basePath.isBlank()) clean else "$basePath/$clean"
    }

    private data class Opf(
        val title: String,
        val author: String,
        val coverId: String?,
        val tocId: String?,
        val manifest: Map<String, ManifestItem>,
        val spine: List<String>
    )

    private data class ManifestItem(val href: String, val mediaType: String, val properties: String)

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

        private fun zip(): ZipFile = zip ?: synchronized(this) {
            zip ?: ZipFile(file).also { zip = it }
        }

        override suspend fun loadChapter(index: Int): List<BookBlock> {
            val chapter = chapters.getOrNull(index) ?: return emptyList()
            val zf = zip()
            val entry = zf.getEntry(chapter.href) ?: zf.getEntry(joinPath(basePath, chapter.href))
                ?: zf.entries().toList().firstOrNull { it.name.endsWith(chapter.href.substringAfterLast('/')) }
                ?: return listOf(BookBlock.Paragraph("（章节缺失：${chapter.title}）"))
            val html = runCatching {
                zf.getInputStream(entry).readBytes().toString(Charsets.UTF_8)
            }.getOrElse {
                zf.getInputStream(entry).readBytes().toString(Charset.forName("GBK"))
            }
            return HtmlExtractor.extract(html) { src -> resolveImage(zf, src) }
        }

        /** 图片按需落地：zip 内相对路径 → 缓存文件绝对路径 */
        private fun resolveImage(zf: ZipFile, src: String): String? {
            val target = joinPath(basePath, src)
            val entry: ZipEntry = zf.getEntry(target)
                ?: zf.getEntry(src)
                ?: zf.entries().toList().firstOrNull { it.name.endsWith(src.substringAfterLast('/')) }
                ?: return null
            val ext = src.substringAfterLast('.', "").ifBlank { "jpg" }
            val outFile = File(cacheDir, FileUtil.md5(entry.name) + "." + ext.take(5))
            if (outFile.exists() && outFile.length() > 0) return outFile.absolutePath
            return runCatching {
                cacheDir.mkdirs()
                zf.getInputStream(entry).use { input ->
                    FileOutputStream(outFile).use { output -> input.copyTo(output) }
                }
                outFile.absolutePath
            }.onFailure { outFile.delete() }.getOrNull()
        }

        override fun close() {
            synchronized(this) {
                runCatching { zip?.close() }
                zip = null
            }
        }
    }
}
