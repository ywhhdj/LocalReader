package com.demo.data.parser.epub

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.Logger
import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.BookBlock
import com.demo.core.model.Chapter
import com.demo.data.parser.common.PathUtils
import com.demo.data.parser.common.XmlUtils
import com.demo.data.parser.common.ZipUtils
import com.demo.domain.repository.NovelContent

import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.util.zip.ZipEntry
import java.util.zip.ZipFile

internal class EpubNovelContent(
    private val file: File,
    private val bookId: Long,
    override val chapters: List<Chapter>,
    private val basePath: String,
    private val cacheDir: File
) : NovelContent {

    @Volatile
    private var zip: ZipFile? = null
    private val lock = Any()

    /** 条目名 → ZipEntry 的懒加载索引：避免每次解析失败/找图都全量枚举一遍 zip */
    @Volatile
    private var entryIndex: Map<String, ZipEntry>? = null

    /** 已写入缓存目录的字节数（-1 表示尚未统计）。避免每张图都递归统计一次目录 → O(N²) */
    @Volatile
    private var cachedBytes: Long = -1L

    /** 自上次真实统计以来的写入次数，用于周期性校正（外部清理缓存后不至于永远偏高） */
    @Volatile
    private var writesSinceMeasure = 0

    private fun zip(): ZipFile = zip ?: synchronized(lock) { zip ?: ZipFile(file).also { zip = it } }

    private fun entriesByName(zf: ZipFile): Map<String, ZipEntry> =
        entryIndex ?: synchronized(lock) {
            entryIndex ?: HashMap<String, ZipEntry>().apply {
                val e = zf.entries()
                while (e.hasMoreElements()) {
                    val ze = e.nextElement()
                    if (!ze.isDirectory) put(ze.name, ze)
                }
            }.also { entryIndex = it }
        }

    override suspend fun loadChapter(index: Int): List<BookBlock> = runCatching {
        val chapter = chapters.getOrNull(index) ?: return emptyList()
        val zf = zip()
        val entry = resolveEntry(zf, chapter.href)
            ?: return listOf(BookBlock.Paragraph("（章节缺失：${chapter.title}）"))
        val bytes = ZipUtils.readEntryBytes(zf, entry, MAX_CHAPTER_BYTES)
            ?: return listOf(BookBlock.Paragraph("（章节读取失败）"))
        val charset = XmlUtils.detectHtmlCharset(bytes)
        var html = String(bytes, charset)
        if (charset == StandardCharsets.UTF_8 && html.count { it == '\uFFFD' } > 8) {
            html = runCatching { String(bytes, XmlUtils.charsetOf("GBK")) }.getOrDefault(html)
        }
        val chapterDir = entry.name.substringBeforeLast('/', "")
        val blocks = HtmlExtractor.extract(html) { src -> resolveImageSafe(zf, chapterDir, src) }

        val displayTitle = VolumeSplitter.displayTitle(chapter)
        val titleCandidates = listOf(chapter.title, displayTitle)
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()

        // 顶部已单独显示章节名，正文开头的重复标题要剥掉：
        // 整块等于标题 → 删；标题 + 换行 + 正文挤在一块 / 标题后直接接正文 → 剥前缀。
        val peeled = VolumeSplitter.peelLeadingTitles(blocks, titleCandidates)
        return VolumeSplitter.stripTitles(peeled, titleCandidates)
            .ifEmpty { listOf(BookBlock.Paragraph("（本章无正文内容）")) }
    }.getOrElse { e ->
        Logger.w("章节加载失败 #$index：${e.javaClass.simpleName} ${e.message}", "EpubParser")
        listOf(BookBlock.Paragraph("（该章节内容无法解析）"))
    }

    private fun resolveImageSafe(zf: ZipFile, chapterDir: String, src: String): String? =
        runCatching { resolveImage(zf, chapterDir, src) }
            .onFailure { Logger.w("图片解析失败：$src", "EpubParser") }
            .getOrNull()

    private fun resolveEntry(zf: ZipFile, href: String): ZipEntry? {
        val clean = PathUtils.stripFragment(href)
        zf.getEntry(clean)?.let { return it }
        zf.getEntry(PathUtils.joinPath(basePath, clean))?.let { return it }
        zf.getEntry(PathUtils.decodePath(clean))?.let { return it }
        val tail = clean.substringAfterLast('/')
        if (tail.isBlank()) return null
        val index = entriesByName(zf)
        index[clean]?.let { return it }
        return index.values.firstOrNull {
            it.name.endsWith("/$tail", true) || it.name.equals(tail, true)
        }
    }

    private fun resolveImage(zf: ZipFile, chapterDir: String, src: String): String? {
        val clean = PathUtils.stripFragment(src)
        if (clean.startsWith("data:", true)) return null
        val candidates = listOf(
            PathUtils.joinPath(chapterDir, clean),
            PathUtils.joinPath(basePath, clean),
            clean
        )
        var entry: ZipEntry? = null
        for (c in candidates) {
            entry = zf.getEntry(c)
            if (entry != null) break
        }
        if (entry == null) {
            val tail = clean.substringAfterLast('/')
            entry = entriesByName(zf).values.firstOrNull {
                it.name.endsWith(tail, true)
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
            // 增量累加缓存体积：旧实现每张图都跑一次 dirSize() 递归统计，
            // 插图多的章节会退化成 O(N²) 次目录遍历。
            if (cachedBytes >= 0) cachedBytes += outFile.length()
            if (++writesSinceMeasure >= MEASURE_EVERY_WRITES) {
                cachedBytes = -1L   // 周期性用真实值校正（缓存被外部清理时不至于永远偏高）
                writesSinceMeasure = 0
            }
            outFile.absolutePath
        }.onFailure { outFile.delete() }.getOrNull()
    }

    /** 只在首次与每 N 次写入后统计一次真实目录大小 */
    private fun ensureCacheBudget(): Boolean = runCatching {
        val measured = cachedBytes
        val size = if (measured < 0) {
            FileUtil.dirSize(cacheDir).also { cachedBytes = it; writesSinceMeasure = 0 }
        } else measured
        size < Constants.BOOK_IMAGE_CACHE_MAX_BYTES
    }.getOrDefault(false)

    override fun close() {
        synchronized(lock) {
            runCatching { zip?.close() }
            zip = null
            entryIndex = null
        }
    }

    private companion object {
        const val MAX_CHAPTER_BYTES = 8 * 1024 * 1024
        /** 每写入这么多张图，重新统计一次缓存目录真实大小 */
        const val MEASURE_EVERY_WRITES = 32
    }
}