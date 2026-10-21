package com.demo.data.parser.epub

import com.demo.core.model.Chapter

/** EPUB 元数据编码：opf 路径 + 章节(href/title)，避免引入 JSON 库 */
object EpubMetaCodec {
    private const val FIELD = "\u0001"
    private const val ROW = "\u0002"

    fun encode(opfPath: String, chapters: List<Chapter>): String = buildString {
        append(opfPath)
        chapters.forEach { c ->
            append(ROW)
            append(c.href.replace(FIELD, " ").replace(ROW, " "))
            append(FIELD)
            append(c.title.replace(FIELD, " ").replace(ROW, " "))
        }
    }

    fun decode(meta: String?): Pair<String, List<Chapter>> {
        if (meta.isNullOrBlank()) return "" to emptyList()
        val rows = meta.split(ROW)
        val opfPath = rows.firstOrNull().orEmpty()
        val chapters = rows.drop(1).mapIndexedNotNull { index, row ->
            val parts = row.split(FIELD)
            val href = parts.getOrNull(0) ?: return@mapIndexedNotNull null
            val title = parts.getOrNull(1)?.takeIf { it.isNotBlank() } ?: "第 ${index + 1} 章"
            Chapter(index, title, href)
        }
        return opfPath to chapters
    }
}
