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
     * 去掉正文中重复出现的章节标题行（前若干个块），
     * 避免"顶部已显示标题、正文又来一遍"的观感问题。
     */
    fun stripTitles(blocks: List<BookBlock>, titles: Collection<String>): List<BookBlock> {
        val keys = titles.map { normalize(it) }
            .filter { it.length >= 3 }
            .toSet()
        if (keys.isEmpty()) return blocks
        var removed = 0
        return blocks.filter { block ->
            val text = when (block) {
                is BookBlock.Heading -> block.text
                is BookBlock.Paragraph -> block.text
                is BookBlock.Quote -> block.text
                else -> return@filter true
            }
            val n = normalize(text)
            if (n.isBlank()) return@filter false
            val hit = keys.any { key ->
                n == key || (n.startsWith(key) && n.length <= key.length + 4) ||
                    (key.startsWith(n) && n.length >= 6 && key.length <= n.length + 4)
            }
            if (hit && removed < MAX_STRIP) {
                removed++
                false
            } else true
        }
    }

    /** 归一化：去空白与标点，便于标题比对 */
    fun normalize(text: String): String = text
        .replace("\uFEFF", "")
        .replace(Regex("""[\s　]+"""), "")
        .replace(Regex("""[，。、！？：；“”‘’（）《》〈〉·—…\-,.!?:;"'()\[\]{}|/\\~`*#]"""), "")

    const val VOLUME_FIRST_TITLE = "卷首"
    private const val MAX_STRIP = 3

    /** 目录项：卷标题 或 章节 */
    sealed interface TocEntry {
        data class Volume(val title: String, val firstIndex: Int) : TocEntry
        data class Item(val chapter: Chapter) : TocEntry
    }
}
