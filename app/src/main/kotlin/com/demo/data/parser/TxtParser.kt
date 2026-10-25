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

    private companion object {
        val CHAPTER_PATTERNS = listOf(
            Regex("""^\s*第\s*[0-9零一二三四五六七八九十百千万两]+\s*[章节節回卷篇部集].{0,40}$"""),
            Regex("""^\s*(Chapter|CHAPTER|chapter|CHAPTIR)\s*[0-9IVXLC]+.{0,40}$"""),
            Regex("""^\s*(序章|序言|前言|楔子|引子|尾声|后记|後記|番外|终章|終章|(?:內容)?[简簡]介).{0,30}$"""),
            Regex("""^\s*(卷[0-9零一二三四五六七八九十百千万]+).{0,40}$"""),
        )
        /** 空行分段 */
        val PARAGRAPH_SPLIT_REGEX = Regex("""\n\s*\n+""")
        /** 段内空白折叠 */
        val BLANK_FOLD_REGEX = Regex("""[ \t　]+""")
        /** 空白 / 全角空格归一化 */
        val WS_NORMALIZE_REGEX = Regex("""[\s　]+""")

        const val HEAD_SNIFF_BYTES = 8 * 1024
        /** 单章最大读取字节（8MB，超长章节截断保护；与 EPUB 单章上限对齐） */
        const val MAX_CHAPTER_BYTES = 8 * 1024 * 1024
        /** 单行字节上限（异常长行截断，避免缓冲区无限增长） */
        const val MAX_LINE_BYTES = 64 * 1024
        /** 前言内容探测的最大读取字节 */
        const val PROBE_MAX_BYTES = 64 * 1024
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
                    CHAPTER_PATTERNS.none { it.matches(line) }        // 章节标题行不当书名
            }
            ?.trim('《', '》')
            .orEmpty()

        return SniffedMeta(
            title = titleFromMark.ifBlank { titleFromFirstLine },
            author = author
        )
    }

    /** 无信息量的文件名：纯数字、单个词、常见默认名 */
    private fun isGenericName(name: String): Boolean {
        val t = name.trim()
        if (t.isBlank()) return true
        if (t.all { it.isDigit() || it == '.' || it == '_' || it == '-' }) return true
        if (t.length <= 1) return true
        val generic = setOf(
            "新建文本文档", "新建文本", "未命名", "无标题", "untitled", "new file",
            "text", "txt", "book", "小说", "正文", "文档"
        )
        return t.lowercase() in generic
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
        // 文件名优先，但"新建文本文档 / 纯数字 / 1"这类没有信息量的名字让位给正文嗅探到的书名
        val title = if (isGenericName(fileTitle)) {
            sniffed.title.ifBlank { fileTitle }
        } else {
            fileTitle
        }
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
        runCatching {
            scanLines(file, charset) { text, start, _ ->
                // 行内重复折叠：「终章 终焉的开始 终章 终焉的开始」→「终章 终焉的开始」
                val trimmed = foldInlineRepeat(
                    text.trim().replace("\uFEFF", "").replace("\u200B", "")
                )
                if (trimmed.length in 1..40 && CHAPTER_PATTERNS.any { it.matches(trimmed) }) {
                    titles.add(start to trimmed)
                }
            }
        }.onFailure { return fallbackChapters(file) }

        if (titles.isEmpty()) return fallbackChapters(file)

        // 连续重复标题合并：正文里常见「终章 终焉的开始」连着出现两遍，
        // 第二遍只是排版残留，切出来会得到一个空章节。
        val unique = dedupeConsecutive(titles)

        val chapters = ArrayList<Chapter>()
        // 第一个标题之前的内容：只有真的存在正文时才补「前言」章
        // （旧实现只看偏移量 > 0，开头几行是空行 / 分隔线 / BOM 时也会多出一个空章）
        val firstOffset = unique.first().first
        if (firstOffset > 0 && unique.first().second.isNotBlank() &&
            hasProse(readTextRange(file, charset, 0L, firstOffset))
        ) {
            chapters.add(
                Chapter(
                    index = 0,
                    title = "前言",
                    startOffset = 0L,
                    endOffset = firstOffset
                )
            )
        }
        unique.forEachIndexed { i, (start, title) ->
            val end = unique.getOrNull(i + 1)?.first ?: -1L
            chapters.add(
                Chapter(
                    index = chapters.size,
                    title = title,
                    startOffset = start,
                    endOffset = end
                )
            )
        }
        // 分卷：识别「第X卷 …」并向下延续归属
        return VolumeSplitter.apply(chapters)
    }

    /**
     * 相邻重复标题合并（含行内重复折叠后的等价标题）。
     *
     * 只合并**连续**出现的同名标题：跨卷的同名章节（如两卷都有「后记」）仍需保留。
     */
    private fun dedupeConsecutive(titles: List<Pair<Long, String>>): List<Pair<Long, String>> {
        if (titles.size <= 1) return titles
        val out = ArrayList<Pair<Long, String>>(titles.size)
        for (item in titles) {
            val prev = out.lastOrNull()
            if (prev != null && normalizeTitle(prev.second) == normalizeTitle(item.second)) continue
            out.add(item)
        }
        return out
    }

    /** 标题归一化：忽略空白、全半角与常见分隔符差异 */
    private fun normalizeTitle(raw: String): String = raw
        .replace(WS_NORMALIZE_REGEX, "")
        .trim('《', '》', '【', '】', '「', '」', '（', '）', '(', ')', '.', '。', '、', '：', ':')
        .lowercase()

    /**
     * 行内重复折叠：「终章 终焉的开始 终章 终焉的开始」这类把标题连打两遍的行，
     * 归一化后是两段完全相同的文本，取一半即可。
     */
    private fun foldInlineRepeat(raw: String): String {
        val core = raw.trim()
        if (core.length < 8) return core
        val normalized = core.replace(WS_NORMALIZE_REGEX, "")
        val half = normalized.length / 2
        if (normalized.length % 2 == 0 && half >= 4 &&
            normalized.substring(0, half) == normalized.substring(half)
        ) {
            return normalized.substring(0, half)
        }
        return core
    }

    /** 区间内是否有"真正文"：空行 / BOM / 纯符号分隔线不算 */
    private fun hasProse(raw: String): Boolean {
        if (raw.isBlank()) return false
        return raw.lineSequence().any { line ->
            val t = line.trim()
            // 至少一个字母/数字/汉字，才算有内容（过滤 "***" "———" 之类分隔行）
            t.length >= 2 && t.any { it.isLetterOrDigit() }
        }
    }

    /** 按字节区间读取（用于前言内容探测，只读前 64KB 足够判断） */
    private fun readTextRange(file: File, charset: Charset, from: Long, to: Long): String {
        val limit = (to - from).coerceIn(0L, PROBE_MAX_BYTES.toLong()).toInt()
        if (limit <= 0) return ""
        return runCatching {
            FileInputStream(file).use { fis ->
                if (from > 0) fis.skip(from)
                val buf = ByteArray(limit)
                var read = 0
                while (read < buf.size) {
                    val n = fis.read(buf, read, buf.size - read)
                    if (n <= 0) break
                    read += n
                }
                if (read <= 0) "" else String(buf, 0, read, charset)
            }
        }.getOrDefault("")
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

    /**
     * 逐行扫描（保留字节偏移），避免整本读入内存。
     *
     * 性能：旧实现每行都 new 一个 ByteArrayOutputStream，5MB 的 TXT 有十几万行，
     * 光是缓冲区对象就要分配十几万个；这里改成**复用的可增长字节缓冲**，
     * 行结束只 reset 游标，不再重新分配。
     */
    private fun scanLines(
        file: File,
        charset: Charset,
        onLine: (text: String, byteStart: Long, byteLength: Int) -> Unit
    ) {
        FileInputStream(file).use { fis ->
            BufferedInputStream(fis, 1 shl 16).use { input ->
                val buf = ByteArray(1 shl 16)
                var line = ByteArray(256)
                var lineLen = 0          // 实际保留在缓冲里的字节数
                var lineBytes = 0        // 该行在文件中的真实字节数（含被截断丢弃的部分）
                var pos = 0L

                /** 追加字节；超过单行上限的部分直接丢弃（异常长行保护）。返回实际写入字节数 */
                fun append(src: ByteArray, from: Int, len: Int): Int {
                    if (len <= 0) return 0
                    val take = len.coerceAtMost(MAX_LINE_BYTES - lineLen)
                    if (take <= 0) return 0
                    val need = lineLen + take
                    if (need > line.size) {
                        var cap = line.size
                        while (cap < need) cap = (cap * 2).coerceAtMost(MAX_LINE_BYTES)
                        line = line.copyOf(cap)
                    }
                    System.arraycopy(src, from, line, lineLen, take)
                    lineLen += take
                    return take
                }

                /**
                 * 结束一行：偏移量必须按"文件里的真实字节数"累加。
                 */
                fun emit(byteLen: Int) {
                    onLine(String(line, 0, lineLen, charset), pos, byteLen)
                    pos += byteLen
                    lineLen = 0
                    lineBytes = 0
                }

                while (true) {
                    val n = input.read(buf)
                    if (n <= 0) break
                    var start = 0
                    for (i in 0 until n) {
                        if (buf[i] == '\n'.code.toByte()) {
                            val written = append(buf, start, i - start)
                            val skipped = (i - start) - written   // 被上限丢弃的字节
                            emit(lineBytes + written + skipped + 1)
                            start = i + 1
                        }
                    }
                    val tail = append(buf, start, n - start)
                    lineBytes += tail + ((n - start) - tail)
                }
                if (lineLen > 0) onLine(String(line, 0, lineLen, charset), pos, lineBytes)
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
            text.split(PARAGRAPH_SPLIT_REGEX)
                .asSequence()
                .map { it.trim() }
                .filter { it.isNotBlank() }
                .forEach { paragraph ->
                    // 段内换行保留（观感：换行显示），仅折叠行尾多余空格
                    val body = paragraph.replace(BLANK_FOLD_REGEX, " ")
                    if (body.isNotBlank()) blocks.add(BookBlock.Paragraph(body))
                }
            if (blocks.isEmpty()) return emptyList()

            // 顶部已显示章节名：剥掉正文开头重复的标题
            val peeled = VolumeSplitter.peelLeadingTitles(blocks, titleCandidates)
            return VolumeSplitter.stripTitles(peeled, titleCandidates)
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
                // 这里按"章节跨度 ∩ 文件剩余字节 ∩ 上限"取最小值，并把上限放宽到 8MB（长篇网文常见大章）。
                val remaining = (file.length() - chapter.startOffset).coerceAtLeast(0)
                val span = if (chapter.endOffset > chapter.startOffset) {
                    chapter.endOffset - chapter.startOffset
                } else remaining
                val limit = minOf(span, remaining, MAX_CHAPTER_BYTES.toLong())
                    .toInt().coerceAtLeast(1)
                val buf = ByteArray(limit)
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
