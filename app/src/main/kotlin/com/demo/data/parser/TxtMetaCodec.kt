package com.demo.data.parser

import com.demo.core.model.Chapter

/** TXT 元数据：字符集 + 章节标题/字符偏移 */
object TxtMetaCodec {
    private const val FIELD = "\u0001"
    private const val ROW = "\u0002"

    fun encode(charset: String, chapters: List<Chapter>): String = buildString {
        append(charset)
        chapters.forEach { c ->
            append(ROW)
            append(c.startOffset)
            append(FIELD)
            append(c.endOffset)
            append(FIELD)
            append(c.title.replace(FIELD, " ").replace(ROW, " "))
        }
    }

    fun decode(meta: String?): Pair<String, List<Chapter>> {
        if (meta.isNullOrBlank()) return "UTF-8" to emptyList()
        val rows = meta.split(ROW)
        val charset = rows.firstOrNull().orEmpty().ifBlank { "UTF-8" }
        val chapters = rows.drop(1).mapIndexedNotNull { index, row ->
            val p = row.split(FIELD)
            if (p.size < 3) return@mapIndexedNotNull null
            Chapter(
                index = index,
                title = p[2].ifBlank { "第 ${index + 1} 章" },
                startOffset = p[0].toLongOrNull() ?: 0L,
                endOffset = p[1].toLongOrNull() ?: -1L
            )
        }
        return charset to chapters
    }
}
