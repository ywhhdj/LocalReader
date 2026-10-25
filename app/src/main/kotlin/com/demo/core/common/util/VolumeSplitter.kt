package com.demo.core.common.util

import com.demo.core.model.BookBlock
import com.demo.core.model.Chapter

/**
 * 分卷识别与章节标题清洗（纯 Kotlin，无 Android 依赖）。
 *
 * 需求：目录里出现「第…卷」时，除了按章切分还要按卷分组；
 * 卷内章节显示名要去掉卷名前缀；正文中重复出现的章节标题不再显示。
 *
 * 例：
 *  - "第一卷 江湖 第三章 初遇" → volume = "第一卷 江湖"，显示名 = "第三章 初遇"
 *  - "第一卷 江湖"（整行只有卷）→ volume = "第一卷 江湖"，显示名 = "卷首"
 *  - "第三章 初遇"（无卷）→ 归属上一个卷（若有）
 */
object VolumeSplitter {

    /** 卷标记：第X卷 / 第X部 / 卷X */
    private val VOLUME_MARK = Regex(
        """第\s*[0-9零一二三四五六七八九十百千万两]+\s*(?:[卷篇集]|部(?!分))|卷\s*[0-9零一二三四五六七八九十百千万两]+\s*[卷]?"""
    )
    /** 章标记：第X章 / 第X节 / Chapter N */
    private val CHAPTER_MARK = Regex(
        """第\s*[0-9零一二三四五六七八九十百千万两]+\s*[章节節回]|(Chapter|CHAPTER|CHAPTIR)\s*[0-9IVXLC]+"""
    )
    /** 特殊章名：序章 / 楔子 / 后记 等（卷内无编号的章节） */
    private val SPECIAL_MARK = Regex(
        """序章|序言|楔子|引子|前言|尾声|后记|後記|番外|终章|終章|内容简介|內容簡介|简介"""
    )
    /** 空白 / 全角空格 */
    private val WS_REGEX = Regex("""[\s　]+""")
    /** 常见中英文标点 */
    private val PUNCT_REGEX = Regex(
        """[，。、！？：；“”‘’（）《》〈〉〔〕【】「」『』·—…\-_,.!?:;"'()\[\]{}|/\\~`*#]"""
    )

    /** 卷标记必须出现在标题靠前位置，避免正文式长标题被误判 */
    private const val VOLUME_HEAD_LIMIT = 8
    /** 卷名之后允许出现的字符数（超出说明不是"卷+章"结构） */
    private const val VOLUME_NAME_LIMIT = 30

    data class ParsedTitle(
        /** 卷名；空串表示未识别到卷 */
        val volume: String,
        /** 去掉卷名后的章节显示名 */
        val chapterTitle: String,
        /** 整行只有卷名（无章号） */
        val volumeOnly: Boolean
    )

    fun parseTitle(raw: String): ParsedTitle {
        val title = raw.trim()
        if (title.isBlank()) return ParsedTitle("", "", false)
        val volume = VOLUME_MARK.find(title)
        if (volume == null || volume.range.first > VOLUME_HEAD_LIMIT) {
            return ParsedTitle("", title, false)
        }
        val rest = title.substring(volume.range.last + 1)
        val special = SPECIAL_MARK.find(rest)
        if (special != null) {
            val volumeName = title.substring(0, volume.range.last + 1 + special.range.first).trim()
            val chapterTitle = rest.substring(special.range.first).trim().ifBlank { VOLUME_FIRST_TITLE }
            return ParsedTitle(volumeName, chapterTitle, false)
        }
        val chapter = CHAPTER_MARK.find(rest)
        if (chapter == null || chapter.range.first > VOLUME_NAME_LIMIT) {
            // 整行即卷标题（如「第一卷 江湖」）
            val volumeName = buildString {
                append(title.substring(0, volume.range.last + 1))
                if (rest.isNotBlank()) append(' ').append(rest.trim())
            }.trim().take(VOLUME_NAME_LIMIT + 12)
            return ParsedTitle(volumeName, VOLUME_FIRST_TITLE, true)
        }
        val volumeName = title.substring(0, volume.range.last + 1 + chapter.range.first).trim()
        val chapterTitle = rest.substring(chapter.range.first).trim()
            .ifBlank { VOLUME_FIRST_TITLE }
        return ParsedTitle(volumeName, chapterTitle, false)
    }

    /**
     * 为章节列表补齐卷归属：识别到卷的章节更新当前卷，
     * 之后的章节沿用该卷，直到下一个卷标题出现。
     */
    fun apply(chapters: List<Chapter>): List<Chapter> {
        var current = ""
        return chapters.map { chapter ->
            val parsed = parseTitle(chapter.title)
            if (parsed.volume.isNotBlank()) current = parsed.volume
            if (chapter.volume == current) chapter else chapter.copy(volume = current)
        }
    }

    /** 目录 / 正文顶部展示用的章节名（已去掉卷名前缀） */
    fun displayTitle(chapter: Chapter): String = parseTitle(chapter.title).let { parsed ->
        when {
            parsed.volume.isBlank() -> chapter.title.ifBlank { "第 ${chapter.index + 1} 章" }
            parsed.volumeOnly -> VOLUME_FIRST_TITLE
            else -> parsed.chapterTitle
        }
    }

    /** 按卷分组后的目录项，供 UI 直接渲染 */
    fun tocEntries(chapters: List<Chapter>): List<TocEntry> {
        if (chapters.isEmpty()) return emptyList()
        val result = ArrayList<TocEntry>(chapters.size + 8)
        var lastVolume: String? = null
        chapters.forEach { chapter ->
            if (chapter.volume.isNotBlank() && chapter.volume != lastVolume) {
                lastVolume = chapter.volume
                result.add(TocEntry.Volume(chapter.volume, chapter.index))
            }
            result.add(TocEntry.Item(chapter))
        }
        return result
    }

    /**
     * 剥掉正文**开头**内嵌的章节标题（顶部已单独显示标题，正文里再来一遍很碍眼）。
     *
     * 覆盖三种常见形态：
     * 1) 整块就是标题：`第一章 初遇`（TXT 里标题行独占一段）；
     * 2) 标题 + 换行 + 正文挤在同一块：`第一章 初遇\n今天天气很好……`
     *    （TXT 按空行分段时，标题行和正文之间没有空行就会合成一块）；
     * 3) 标题后面直接接正文：`第一章 初遇今天天气很好……`（部分 EPUB 的 h/p 混排）。
     *
     * 只对**开头若干个块**生效，且不改动块内部其余文本，避免误伤正文。
     */
    fun peelLeadingTitles(
        blocks: List<BookBlock>,
        titles: Collection<String>
    ): List<BookBlock> {
        if (blocks.isEmpty()) return blocks
        val keys = titleKeys(titles)
        if (keys.isEmpty()) return blocks

        val out = blocks.toMutableList()
        var guard = 0
        while (guard < MAX_PEEL && out.isNotEmpty()) {
            val first = out.first()
            val raw = textOf(first) ?: break
            if (raw.isBlank()) {
                out.removeAt(0)
                guard++
                continue
            }
            val n = normalize(raw)
            // 1) 整块即标题
            if (keys.any { it.normalized == n }) {
                out.removeAt(0)
                guard++
                continue
            }
            // 2) / 3) 标题在前、正文在后
            var peeled: String? = null
            for (key in keys) {
                val hit = key.candidates.firstNotNullOfOrNull { cand ->
                    peelPrefix(raw, cand, key.chapterLike)
                }
                if (hit != null) {
                    peeled = hit
                    break
                }
            }
            if (peeled == null) break
            if (peeled.isBlank()) out.removeAt(0) else replaceText(out, 0, peeled)
            guard++
        }
        return out
    }

    /**
     * 去掉正文中重复出现的章节标题行（整块完全等于标题的块）。
     *
     * 只做"整块相等"的精确判定：模糊的前缀/后缀匹配会把正文（例如以标题开头
     * 的长段落）整段吃掉，那类场景交给 [peelLeadingTitles] 在开头处理更安全。
     */
    fun stripTitles(blocks: List<BookBlock>, titles: Collection<String>): List<BookBlock> {
        val keys = titleKeys(titles).map { it.normalized }.toSet()
        if (keys.isEmpty()) return blocks
        var removed = 0
        return blocks.filter { block ->
            val text = textOf(block) ?: return@filter true
            val n = normalize(text)
            if (n.isBlank()) return@filter false
            if (n in keys && removed < MAX_STRIP) {
                removed++
                false
            } else true
        }
    }

    /** 标题候选：归一化名 + 可参与前缀比对的原始写法（含去装饰后的写法） */
    private data class TitleKey(
        val normalized: String,
        val candidates: List<String>,
        val chapterLike: Boolean
    )

    private fun titleKeys(titles: Collection<String>): List<TitleKey> = titles
        .map { it.trim() }
        .filter { it.isNotBlank() }
        .distinct()
        .mapNotNull { raw ->
            val n = normalize(raw)
            // 短标题（「楔子」「序言」，归一化后仅 2 字）也要能命中：
            // 旧实现要求长度 >= 3，导致这类章节名永远去不掉。
            if (n.length < 2) return@mapNotNull null
            val bare = trimDecoration(raw)
            TitleKey(
                normalized = n,
                candidates = listOf(raw, bare).filter { it.isNotBlank() }.distinct(),
                chapterLike = isChapterLike(raw)
            )
        }

    /** 块内文本；图片 / 分隔块没有文本，返回 null 表示不参与标题比对 */
    private fun textOf(block: BookBlock): String? = when (block) {
        is BookBlock.Heading -> block.text
        is BookBlock.Paragraph -> block.text
        is BookBlock.Quote -> block.text
        else -> null
    }

    private fun replaceText(out: MutableList<BookBlock>, index: Int, text: String) {
        when (val block = out[index]) {
            is BookBlock.Heading -> out[index] = block.copy(text = text)
            is BookBlock.Paragraph -> out[index] = block.copy(text = text)
            is BookBlock.Quote -> out[index] = block.copy(text = text)
            else -> Unit
        }
    }

    /**
     * 从 [text] 开头剥掉标题 [title]，返回剩余正文；不匹配返回 null。
     *
     * @param chapterLike 标题是否像章节名（第X章 / Chapter N / 楔子…）。
     *   只有章节名才允许"标题后直接接正文"的强剥离（形态 3），
     *   否则「活着」这类书名式标题会把正文开头的同名文字一起切掉。
     */
    private fun peelPrefix(text: String, title: String, chapterLike: Boolean): String? {
        if (title.isBlank()) return null
        val src = trimDecoration(text)
        if (src.length <= title.length) return null
        if (!src.startsWith(title, ignoreCase = true)) return null
        val rest = src.substring(title.length)
        if (rest.isBlank()) return ""
        val head = rest.first()
        val peeled = when {
            // 形态 2：标题后是换行 —— 无论标题长相都安全地剥
            head == '\n' || head == '\r' -> rest.trimStart('\n', '\r', ' ', '\t', '\u3000')
            // 形态 2：标题后有空格 / 全角空格分隔
            head == ' ' || head == '\t' || head == '\u3000' || head == '\u00A0' ->
                rest.trimStart(' ', '\t', '\u3000', '\u00A0', '\n', '\r')
            // 形态 3：标题后直接接正文，仅章节名才剥
            chapterLike -> rest.trimStart(' ', '\t', '\u3000')
            else -> null
        }
        // 标题带装饰符号时（「【第一章 初遇】」），右半边的括号会留在正文开头
        return peeled
            ?.trimStart(*DECOR_CHARS)
            ?.trimStart('\n', '\r', ' ', '\t', '\u3000')
    }

    /** 标题两侧的装饰符号：【】「」『』《》（）等 */
    private val DECOR_CHARS = charArrayOf(
        '【', '】', '「', '」', '『', '』', '《', '》', '〈', '〉',
        '（', '）', '(', ')', '[', ']', '　', ' '
    )

    private fun trimDecoration(text: String): String = text
        .trim()
        .trim(*DECOR_CHARS)
        .trim()

    /** 是否像章节标题：第X章 / Chapter N / 序章 / 楔子 等 */
    private fun isChapterLike(title: String): Boolean =
        CHAPTER_MARK.containsMatchIn(title) ||
            SPECIAL_MARK.containsMatchIn(title) ||
            VOLUME_MARK.containsMatchIn(title)

    /**
     * 归一化：去空白与标点，便于标题比对。
     * 标题比对是高频调用（每章多次），正则必须复用编译结果。
     */
    fun normalize(text: String): String = text
        .replace("\uFEFF", "")
        .replace(WS_REGEX, "")
        .replace(PUNCT_REGEX, "")

    const val VOLUME_FIRST_TITLE = "卷首"
    /** 开头最多剥离几块（防止异常文本被剥空） */
    private const val MAX_PEEL = 3
    /** 全文范围内最多删除几个"整块等于标题"的块 */
    private const val MAX_STRIP = 2

    /** 目录项：卷标题 或 章节 */
    sealed interface TocEntry {
        data class Volume(val title: String, val firstIndex: Int) : TocEntry
        data class Item(val chapter: Chapter) : TocEntry
    }
}
