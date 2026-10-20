package com.demo.data.parser

import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.nio.charset.Charset

import com.demo.core.common.util.FileUtil
import com.demo.core.model.Book
import com.demo.core.model.BookBlock
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.core.model.Chapter
import com.demo.data.cover.CoverStore
import com.demo.data.cover.TextCoverFactory
import com.demo.domain.repository.NovelContent

/**
 * TXT 解析：编码探测 → 按常见章节标题正则切分 → 按字节区间惰性读取。
 *
 * 修复要点：
 * 1. 章节定位改用**字节偏移**保存，阅读时用 InputStream#skip 直接定位（旧实现用字符 skip，
 *    大文件翻到后面章节会逐字符扫描，卡顿数十秒）。
 * 2. 第一个标题之前的内容补一章（前言/简介不再丢失）。
 * 3. 20KB 兜底切分改为按文件实际大小切分，不再用 length/2 估算导致末章空白。
 * 4. 生成文字占位封面，书架不再出现空白卡片；作者缺省"未知"。
 */
class TxtParser(
    private val coverStore: CoverStore? = null,
    private val textCoverFactory: TextCoverFactory = TextCoverFactory()
) : NovelParser {

    private val patterns = listOf(
        Regex("""^\s*第\s*[0-9零一二三四五六七八九十百千万两]+\s*[章节節回卷篇部集].{0,40}$"""),
        Regex("""^\s*(Chapter|CHAPTER|chapter|CHAPTIR)\s*[0-9IVXLC]+.{0,40}$"""),
        Regex("""^\s*(序章|序言|前言|楔子|引子|尾声|后记|後記|番外|终章|終章|简介|內容簡介).{0,30}$"""),
        Regex("""^\s*(卷[0-9零一二三四五六七八九十百千万]+).{0,40}$"""),
        Regex("""^\s*[0-9]{1,4}\s*[.、]\s*\S.{0,30}$""")
    )

    override fun matches(file: File, ext: String): Boolean =
        ext.equals("txt", ignoreCase = true) || ext.equals("text", ignoreCase = true)

    override suspend fun parseMeta(file: File): Book? = runCatching {
        if (!file.exists() || file.length() <= 0L) return null
        val charset = EncodingDetector.detect(file)
        val chapters = splitChapters(file, charset)
        val title = FileUtil.humanTitle(file.name)
        val cover = runCatching {
            coverStore?.save(textCoverFactory.create(title, "TXT"), file.absolutePath)
        }.getOrNull()
        Book(
            title = title,
            author = "未知",
            type = BookType.NOVEL,
            format = BookFormat.TXT,
            filePath = file.absolutePath,
            coverPath = cover,
            sizeBytes = file.length(),
            chapterCount = chapters.size,
            metaJson = TxtMetaCodec.encode(charset.name(), chapters)
        )
    }.getOrNull()

    override suspend fun openNovel(file: File, book: Book): NovelContent {
        val (charsetName, chapters) = TxtMetaCodec.decode(book.metaJson)
        val charset = runCatching { Charset.forName(charsetName) }.getOrDefault(Charsets.UTF_8)
        val actual = if (chapters.isEmpty()) splitChapters(file, charset) else chapters
        return TxtNovelContent(file, charset, actual)
    }

    /**
     * 章节切分：以字节偏移记录每章起止。
     */
    private fun splitChapters(file: File, charset: Charset): List<Chapter> {
        val titles = ArrayList<Pair<Long, String>>() // 字节偏移 → 标题
        var offset = 0L
        var totalBytes = 0L
        runCatching {
            scanLines(file, charset) { text, start, byteLen ->
                totalBytes = start + byteLen
                val trimmed = text.trim()
                if (trimmed.length <= 40 && patterns.any { it.matches(trimmed) }) {
                    titles.add(start to trimmed)
                }
            }
        }.onFailure { 
            return fallbackChapters(file)
        }

        if (titles.isEmpty()) return fallbackChapters(file)

        val chapters = ArrayList<Chapter>()
        // 第一个标题之前的内容
        if (titles.first().first > 0) {
            chapters.add(
                Chapter(
                    index = 0,
                    title = "开头",
                    startOffset = 0L,
                    endOffset = titles.first().first
                )
            )
        }
        titles.forEachIndexed { i, (start, title) ->
            val end = titles.getOrNull(i + 1)?.first ?: -1L
            chapters.add(
                Chapter(
                    index = chapters.size,
                    title = title,
                    startOffset = start,
                    endOffset = end
                )
            )
        }
        totalBytes.coerceAtLeast(1L)
        return chapters
    }

    /** 无标题：按约 20KB 字节切分（中文约 1 万字/章） */
    private fun fallbackChapters(file: File): List<Chapter> {
        val size = file.length()
        if (size <= 0L) return listOf(Chapter(
            index = 0,
            title = "正文",
            startOffset = 0L,
            endOffset = -1L
        ))
        val chunk = 60_000L // 字节：约 2 万汉字
        val chapters = ArrayList<Chapter>()
        var offset = 0L
        var index = 0
        while (offset < size) {
            val end = (offset + chunk).coerceAtMost(size)
            chapters.add(Chapter(
                index = index++,
                title = "第 $index 部分",
                startOffset = offset,
                endOffset = if (end >= size) -1L else end
            ))
            offset = end
        }
        return chapters
    }

    /** 逐行扫描（保留字节偏移），避免整本读入内存 */
    private inline fun scanLines(
        file: File,
        charset: Charset,
        onLine: (text: String, byteStart: Long, byteLength: Int) -> Unit
    ) {
        FileInputStream(file).use { fis ->
            BufferedInputStream(fis, 1 shl 16).use { input ->
                val buf = ByteArray(1 shl 16)
                var pending = ByteArrayOutputStream(256)
                var pos = 0L
                while (true) {
                    val n = input.read(buf)
                    if (n <= 0) break
                    var start = 0
                    for (i in 0 until n) {
                        if (buf[i] == '\n'.code.toByte()) {
                            if (i > start) pending.write(buf, start, i - start)
                            val bytes = pending.toByteArray()
                            onLine(String(bytes, charset), pos, bytes.size + 1)
                            pos += bytes.size + 1L
                            pending = ByteArrayOutputStream(256)
                            start = i + 1
                        }
                    }
                    if (start < n) pending.write(buf, start, n - start)
                }
                val bytes = pending.toByteArray()
                if (bytes.isNotEmpty()) onLine(String(bytes, charset), pos, bytes.size)
            }
        }
    }

    private class TxtNovelContent(
        private val file: File,
        private val charset: Charset,
        override val chapters: List<Chapter>
    ) : NovelContent {

        override suspend fun loadChapter(index: Int): List<BookBlock> {
            val chapter = chapters.getOrNull(index) ?: return emptyList()
            val text = readRange(chapter)
            if (text.isBlank()) return listOf(BookBlock.Paragraph("（空章节）"))
            val blocks = ArrayList<BookBlock>()
            text.split(Regex("""\n\s*\n+"""))
                .asSequence()
                .map { it.trim() }
                .filter { it.isNotBlank() }
                .forEach { paragraph ->
                    if (chapter.title.isNotBlank() && paragraph == chapter.title) {
                        blocks.add(BookBlock.Heading(paragraph, 2))
                    } else {
                        blocks.add(BookBlock.Paragraph(paragraph.replace("\n", " ")))
                    }
                }
            if (blocks.isEmpty()) blocks.add(BookBlock.Paragraph(text.trim()))
            return blocks
        }

        /** 按字节区间读取：skip 定位 + 定长读取，避免整本解码 */
        private fun readRange(chapter: Chapter): String = try {
            FileInputStream(file).use { fis ->
                if (chapter.startOffset > 0) {
                    var skipped = 0L
                    while (skipped < chapter.startOffset) {
                        val n = fis.skip(chapter.startOffset - skipped)
                        if (n <= 0) break
                        skipped += n
                    }
                }
                val limit = if (chapter.endOffset > chapter.startOffset) {
                    (chapter.endOffset - chapter.startOffset).coerceAtMost(MAX_CHAPTER_BYTES.toLong())
                } else MAX_CHAPTER_BYTES
                val buf = ByteArray(limit.toInt())
                var read = 0
                while (read < buf.size) {
                    val n = fis.read(buf, read, buf.size - read)
                    if (n <= 0) break
                    read += n
                }
                if (read <= 0) "" else String(buf, 0, read, charset)
            }
        } catch (e: Exception) {
            ""
        }

        override fun close() {
            // TXT 没有持有流，留空即可
        }
    }

    companion object {
        /** 单章最大读取字节（约 2MB，超长章节截断保护） */
        const val MAX_CHAPTER_BYTES = 2 * 1024 * 1024
    }
}
