package com.demo.data.parser

import java.io.BufferedReader
import java.io.File
import java.io.FileInputStream
import java.io.InputStreamReader
import java.nio.charset.Charset
import java.util.Locale

import com.demo.core.common.util.FileUtil
import com.demo.core.model.Book
import com.demo.core.model.BookBlock
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.core.model.Chapter
import com.demo.domain.repository.NovelContent

/**
 * TXT 解析：先探测编码，再按常见章节标题正则切分。
 * 记录字符偏移，阅读时按章节区间读取，避免整本常驻内存。
 */
class TxtParser : NovelParser {

    private val patterns = listOf(
        Regex("""^\s*第\s*[0-9零一二三四五六七八九十百千万两]+\s*[章节節回卷篇部集].{0,40}$"""),
        Regex("""^\s*(Chapter|CHAPTER|chapter)\s*[0-9IVXLC]+.{0,40}$"""),
        Regex("""^\s*(序章|序言|前言|楔子|引子|尾声|后记|後記|番外|终章|終章).{0,30}$"""),
        Regex("""^\s*(卷[0-9零一二三四五六七八九十百千万]+).{0,40}$""")
    )

    override fun matches(file: File, ext: String): Boolean =
        ext.equals("txt", ignoreCase = true) || ext.equals("text", ignoreCase = true)

    override suspend fun parseMeta(file: File): Book? = runCatching {
        if (!file.exists() || file.length() <= 0) return null
        val charset = EncodingDetector.detect(file)
        val chapters = splitChapters(file, charset)
        Book(
            title = FileUtil.humanTitle(file.name),
            author = "",
            type = BookType.NOVEL,
            format = BookFormat.TXT,
            filePath = file.absolutePath,
            sizeBytes = file.length(),
            chapterCount = chapters.size,
            metaJson = TxtMetaCodec.encode(charset.name(), chapters)
        )
    }.getOrNull()

    override suspend fun openNovel(file: File, book: Book): NovelContent {
        val (charsetName, chapters) = TxtMetaCodec.decode(book.metaJson)
        val charset = runCatching { Charset.forName(charsetName) }.getOrDefault(Charsets.UTF_8)
        return TxtNovelContent(file, charset, chapters)
    }

    private fun splitChapters(file: File, charset: Charset): List<Chapter> {
        val chapters = ArrayList<Chapter>()
        val pendingTitles = ArrayList<Pair<Long, String>>()
        var position = 0L
        try {
            FileInputStream(file).use { fis ->
                BufferedReader(InputStreamReader(fis, charset)).use { reader ->
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        val raw = line ?: break
                        val len = raw.length + 1
                        val trimmed = raw.trim()
                        if (trimmed.length <= 40 && patterns.any { it.matches(trimmed) }) {
                            pendingTitles.add(position to trimmed)
                        }
                        position += len
                    }
                }
            }
        } catch (e: Exception) {
            return chapters
        }

        if (pendingTitles.isEmpty()) {
            // 无标题：按 20000 字符切分为若干部分
            var offset = 0L
            var index = 0
            val fileLength = estimateChars(file)
            while (offset < fileLength) {
                val end = offset + 20_000L
                chapters.add(
                    Chapter(
                        index = index,
                        title = "第 ${index + 1} 部分",
                        startOffset = offset,
                        endOffset = end
                    )
                )
                index++
                offset = end
            }
            return chapters
        }

        pendingTitles.forEachIndexed { index, (offset, title) ->
            val end = pendingTitles.getOrNull(index + 1)?.first ?: -1L
            chapters.add(Chapter(index = index, title = title, startOffset = offset, endOffset = end))
        }
        return chapters
    }

    private fun estimateChars(file: File): Long = (file.length() / 2L).coerceAtLeast(1L)

    private class TxtNovelContent(
        private val file: File,
        private val charset: Charset,
        override val chapters: List<Chapter>
    ) : NovelContent {

        override suspend fun loadChapter(index: Int): List<BookBlock> {
            val chapter = chapters.getOrNull(index) ?: return emptyList()
            val text = readRange(chapter)
            if (text.isBlank()) return listOf(BookBlock.Paragraph("（空章节）"))
            return text.split(Regex("""\n\s*\n+"""))
                .asSequence()
                .map { it.trim() }
                .filter { it.isNotBlank() }
                .map { paragraph ->
                    val trimmed = paragraph.trim()
                    if (chapters.getOrNull(index)?.title == trimmed) {
                        BookBlock.Heading(trimmed, 2)
                    } else {
                        BookBlock.Paragraph(trimmed.replace("\n", " "))
                    }
                }
                .toList()
                .ifEmpty { listOf(BookBlock.Paragraph(text.trim())) }
        }

        private fun readRange(chapter: Chapter): String = try {
            FileInputStream(file).use { fis ->
                InputStreamReader(fis, charset).use { isr ->
                    BufferedReader(isr).use { reader ->
                        if (chapter.startOffset > 0) {
                            var skipped = 0L
                            while (skipped < chapter.startOffset) {
                                val n = reader.skip(chapter.startOffset - skipped)
                                if (n <= 0) break
                                skipped += n
                            }
                        }
                        val total = if (chapter.endOffset > chapter.startOffset) {
                            (chapter.endOffset - chapter.startOffset).toInt().coerceAtMost(500_000)
                        } else 200_000
                        val buf = CharArray(total)
                        val read = reader.read(buf, 0, total)
                        if (read <= 0) "" else String(buf, 0, read)
                    }
                }
            }
        } catch (e: Exception) {
            ""
        }

        override fun close() {
            // 如果有流或资源需要释放，在这里处理；没有就留空
        }
    }
}
