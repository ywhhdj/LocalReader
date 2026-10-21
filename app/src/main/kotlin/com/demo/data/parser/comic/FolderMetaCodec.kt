package com.demo.data.parser.comic

import com.demo.core.model.ComicChapter

/**
 * 图片文件夹漫画元数据编码（话结构 + 页面路径）。
 *
 * 页面路径仅作快速恢复用；打开时若路径已失效，会按目录重新扫描重建话结构，
 * 因此这里不严格要求路径有效。
 */
object FolderMetaCodec {
    private const val FIELD = "\u0001"
    private const val ROW = "\u0002"
    private const val SECTION = "\u0003"
    private const val VERSION = "v2"

    fun encode(chapters: List<ComicChapter>, pagePaths: List<String>): String = buildString {
        append(VERSION)
        append(SECTION)
        chapters.forEach { c ->
            append(ROW)
            append(c.title.replace(FIELD, " ").replace(ROW, " "))
            append(FIELD)
            append(c.startIndex)
            append(FIELD)
            append(c.endIndex)
        }
        append(SECTION)
        pagePaths.forEach { p ->
            append(ROW)
            append(p.replace(FIELD, " ").replace(ROW, " "))
        }
    }

    /** 解析失败（旧格式 / 空）时返回空，调用方按单话处理 */
    fun decode(meta: String?): Pair<List<ComicChapter>, List<String>> {
        if (meta.isNullOrBlank()) return emptyList<ComicChapter>() to emptyList()
        val sections = meta.split(SECTION)
        if (sections.size < 2 || sections[0] != VERSION) {
            // 旧格式（纯路径列表）→ 单话
            val legacy = meta.split(ROW).filter { it.isNotBlank() }
            return emptyList<ComicChapter>() to legacy
        }
        val chapters = sections[1].split(ROW).mapIndexedNotNull { index, row ->
            if (row.isBlank()) return@mapIndexedNotNull null
            val p = row.split(FIELD)
            if (p.size < 3) return@mapIndexedNotNull null
            val start = p[1].toIntOrNull() ?: return@mapIndexedNotNull null
            val end = p[2].toIntOrNull() ?: return@mapIndexedNotNull null
            ComicChapter(
                index=index,
                title=p[0].ifBlank { "第 ${index + 1} 话" },
                startIndex=start, 
                endIndex=end
            )
        }
        val paths = sections[2].split(ROW).filter { it.isNotBlank() }
        return chapters to paths
    }
}
