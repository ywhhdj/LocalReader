package com.demo.data.parser

import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.Book
import com.demo.core.model.BookBlock
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.core.model.Chapter
import com.demo.data.cover.CoverStore
import com.demo.data.cover.TextCoverFactory
import com.demo.domain.repository.NovelContent
import com.demo.data.parser.common.EncodingDetector
import com.demo.data.parser.txt.TxtMetaCodec

import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.nio.charset.Charset

/**
 * TXT 解析：编码探测 → 按常见章节标题正则切分 → 按字节区间惰性读取。
 *
 * 1. 章节定位改用字节偏移保存，阅读时用 InputStream#skip 直接定位
 * 2. 第一个标题之前的内容补一章（前言/简介不再丢失）。
 * 3. 20KB 兜底切分改为按文件实际大小切分，不再用 length/2 估算导致末章空白。
 * 4. 生成文字占位封面，书架不再出现空白卡片；作者缺省"未知"。
 */
class TxtParser(
    private val coverStore: CoverStore? = null,
    private val textCoverFactory: TextCoverFactory = TextCoverFactory()
) : NovelParser {

    private data class SniffedMeta(
        val title: String,
        val author: String
    )

    private val patterns = listOf(
        Regex("""^\s*第\s*[0-9零一二三四五六七八九十百千万两]+\s*[章节節回卷篇部集].{0,40}$"""),
        Regex("""^\s*(Chapter|CHAPTER|chapter|CHAPTIR)\s*[0-9IVXLC]+.{0,40}$"""),
        Regex("""^\s*(序章|序言|前言|楔子|引子|尾声|后记|後記|番外|终章|終章|(?:內容)?[简簡]介).{0,30}$"""),
        Regex("""^\s*(卷[0-9零一二三四五六七八九十百千万]+).{0,40}$"""),
    )

    private companion object {
        const val HEAD_SNIFF_BYTES = 8 * 1024
        /** 单章最大读取字节（约 2MB，超长章节截断保护） */
        const val MAX_CHAPTER_BYTES = 2 * 1024 * 1024
    }

    /** 作者：落家小沫 / 作 者：xxx / Author: xxx */
    private val AUTHOR_REGEX = Regex(
        """(?:^|[\r\n])[\s\u3000]*(?:作者|作[\s\u3000]*者|著者|Author|author)[\s\u3000]*[:：][\s\u3000]*([^\r\n]+)"""
    )

    /** 作者行尾部常见的其它字段，用它切掉"类型：游戏动漫 状态：完结" */
    private val AUTHOR_TAIL_REGEX = Regex(
        """[\s\u3000]{2,}""" +
        """|[\s\u3000]+(?=(?:类型|類型|分类|分類|状态|狀態|版权|版權|简介|簡介|标签|標籤|字数|字數|出处|出處|来源|來源|连载|連載|更新|译者|譯者)[\s\u3000]*[:：])""" +
        """|[\t|｜]"""
    )

    private val BOOK_TITLE_REGEX = Regex("""《([^》\r\n]{1,40})》""")
    private val META_LINE = Regex(
        """(?:作者|作[\s\u3000]*者|类型|類型|状态|狀態|版权|版權|简介|簡介)[\s\u3000]*[:：]"""
    )
    private val JUNK_LINE = Regex(
        """(?:https?://|www\.|手机用户|请记住|最新章节|免费阅读|本书由|更多精彩|广告|求收藏|求推荐)""",
        RegexOption.IGNORE_CASE
    )

    override fun matches(file: File, ext: String): Boolean =
        ext.equals("txt", ignoreCase = true) || ext.equals("text", ignoreCase = true)
    
    private fun sniffHeader(file: File, charset: Charset): SniffedMeta {
        val head = readHead(file, charset, HEAD_SNIFF_BYTES)
            .removePrefix("\uFEFF")            // 去 UTF-8 BOM，否则正则 ^ 前的作者行匹配不到
        if (head.isBlank()) return SniffedMeta("", "")

        val author = cleanAuthor(AUTHOR_REGEX.find(head)?.groupValues?.get(1).orEmpty())

        val titleFromMark = BOOK_TITLE_REGEX.find(head)?.groupValues?.get(1)?.trim().orEmpty()
        val titleFromFirstLine = head.lineSequence()
            .map { it.trim().trim('\u3000', '\uFEFF') }
            .firstOrNull { line ->
                line.length in 1..40 &&
                    !JUNK_LINE.containsMatchIn(line) &&
                    !META_LINE.containsMatchIn(line) &&      // "作者：xxx" 这种行不当书名
                    patterns.none { it.matches(line) }        // 章节标题行不当书名
            }
            ?.trim('《', '》')
            .orEmpty()

        return SniffedMeta(
            title = titleFromMark.ifBlank { titleFromFirstLine },
            author = author
        )
    }

    private fun cleanAuthor(raw: String): String {
        if (raw.isBlank()) return ""
        val cut = AUTHOR_TAIL_REGEX.split(raw).firstOrNull().orEmpty()
        return cut.trim().trim('，', ',', '；', ';', '。', '、', '|', '｜', ' ')
    }

    private fun readHead(file: File, charset: Charset, maxBytes: Int): String = runCatching {
        FileInputStream(file).use { fis ->
            val cap = minOf(file.length(), maxBytes.toLong()).toInt().coerceAtLeast(1)
            val buf = ByteArray(cap)
            var read = 0
            while (read < cap) {
                val n = fis.read(buf, read, cap - read)
                if (n <= 0) break
                read += n
            }
            if (read <= 0) "" else String(buf, 0, read, charset)
        }
    }.getOrDefault("")

    override suspend fun parseMeta(file: File): Book? = runCatching {
        if (!file.exists() || file.length() <= 0L) return null
        val charset = EncodingDetector.detect(file)
        val chapters = splitChapters(file, charset)
        val sniffed = sniffHeader(file, charset)  
        val fileTitle = FileUtil.humanTitle(file.name)
        val title = fileTitle.ifBlank { sniffed.title }       // 文件名优先，正文标题兜底
        val author = sniffed.author.ifBlank { "未知作者" }
        val cover = runCatching {
            coverStore?.save(textCoverFactory.create(title, "TXT"), file.absolutePath)
        }.getOrNull()
        Book(
            title = title,
            author = author,
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
                val trimmed = text.trim().replace("\uFEFF", "").replace("\u200B", "")
                if (trimmed.length in 1..40 && patterns.any { it.matches(trimmed) }) {
                    titles.add(start to trimmed)
                }
            }
        }.onFailure { return fallbackChapters(file) }

        if (titles.isEmpty()) return fallbackChapters(file)

        val chapters = ArrayList<Chapter>()
        // 第一个标题之前的内容
        if (titles.first().first > 0) {
            chapters.add(
                Chapter(
                    index = 0,
                    title = "前言",
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
        // 分卷：识别「第X卷 …」并向下延续归属
        return VolumeSplitter.apply(chapters)
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
                index = index,
                title = "第${index + 1}卷",
                startOffset = offset,
                endOffset = if (end >= size) -1L else end
            ))
            index++
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
        /** 章节正文：保留段内换行、去掉重复的章节标题行，异常兜底不崩 */
        override suspend fun loadChapter(index: Int): List<BookBlock> = runCatching {
            val chapter = chapters.getOrNull(index) ?: return emptyList()
            val text = readRange(chapter)
            if (text.isBlank()) return listOf(BookBlock.Paragraph("（空章节）"))
            val displayTitle = VolumeSplitter.displayTitle(chapter)
            val titleCandidates = listOf(chapter.title, displayTitle)
                .map { it.trim().trim('\u3000', '\uFEFF', ' ', '\r', '\n') }
                .filter { it.isNotBlank() }
                .distinct()
            val blocks = ArrayList<BookBlock>()
            var first = true
            text.split(Regex("""\n\s*\n+"""))
                .asSequence()
                .map { it.trim() }
                .filter { it.isNotBlank() }
                .forEach { paragraph ->
                    // 段内换行保留（观感：换行显示），仅折叠行尾多余空格
                    val body = paragraph.replace(Regex("""[ \t　]+"""), " ")
                     if (first) {
                        first = false
                        // 1) 整段 == 标题 → 整段丢弃
                        if (titleCandidates.any { it == body }) {
                            return@forEach
                        }
                    }
                    if (body.isNotBlank()) blocks.add(BookBlock.Paragraph(body))
                }
            if (blocks.isEmpty()) blocks.add(BookBlock.Paragraph(text.trim()))
            // 顶部已单独显示章节名，正文里再来一遍的标题行去掉
            VolumeSplitter.stripTitles(blocks, listOf(chapter.title, displayTitle))
                .ifEmpty { listOf(BookBlock.Paragraph("（本章无正文内容）")) }
        }.getOrElse { 
            listOf(BookBlock.Paragraph("（该章节内容无法解析）"))
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

        override fun close() { /* TXT 没有持有流，留空即可 */ }
    }
}
