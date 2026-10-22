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

    private fun zip(): ZipFile = zip ?: synchronized(lock) { zip ?: ZipFile(file).also { zip = it } }

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

        // 在 stripTitles 之前，先"剥开"首块里内嵌的章节标题
        val peeled = blocks.toMutableList()
        val firstBlock = peeled.firstOrNull()
        if (firstBlock is BookBlock.Paragraph) {
            var body = firstBlock.text
            var changed = false
            for (t in titleCandidates) {
                if (body == t) { 
                    peeled.removeAt(0);
                    changed = true;
                    break
                }
                if (body.startsWith(t) && body.getOrNull(t.length)?.let { it == '\n' || it == '\r' } == true) {
                    body = body.substring(t.length).trimStart('\n', '\r', ' ', '\u3000')
                    if (body.isBlank()) peeled.removeAt(0)
                    else peeled[0] = BookBlock.Paragraph(body)
                    changed = true
                    break
                }
            }
            // 同时支持首块是 Heading 但标题在前、正文串进 Heading 里的场景
            if (!changed) {
                for (t in titleCandidates) {
                    if (body.startsWith(t) && body.length > t.length) {
                        val rest = body.substring(t.length).trimStart()
                        if (rest.isNotBlank()) {
                            peeled.removeAt(0)
                            peeled.add(0, BookBlock.Paragraph(rest))
                        }
                        break
                    }
                }
            }
        }

        VolumeSplitter.stripTitles(blocks, listOf(chapter.title, VolumeSplitter.displayTitle(chapter)))
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
        return zf.entries().toList().firstOrNull {
            !it.isDirectory && (it.name.equals(clean, true) || it.name.endsWith("/$tail", true) ||
                it.name.equals(tail, true))
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

    private fun ensureCacheBudget(): Boolean = runCatching {
        FileUtil.dirSize(cacheDir) < Constants.BOOK_IMAGE_CACHE_MAX_BYTES
    }.getOrDefault(false)

    override fun close() {
        synchronized(lock) {
            runCatching { zip?.close() }
            zip = null
        }
    }

    private companion object {
        const val MAX_CHAPTER_BYTES = 8 * 1024 * 1024
    }
}