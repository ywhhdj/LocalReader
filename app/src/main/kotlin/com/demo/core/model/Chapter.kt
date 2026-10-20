package com.demo.core.model

/** 小说章节 */
data class Chapter(
    val index: Int,
    val title: String,
    /** EPUB 内资源路径 / TXT 不使用 */
    val href: String = "",
    /** TXT 字节偏移起点 */
    val startOffset: Long = -1L,
    val endOffset: Long = -1L
)

/**
 * 正文块：解析器统一输出结构，UI 按类型渲染，避免直接处理 HTML
 */
sealed interface BookBlock {
    data class Heading(val text: String, val level: Int = 2) : BookBlock
    data class Paragraph(val text: String) : BookBlock
    /** src 为本地缓存文件路径 */
    data class Image(val src: String, val alt: String = "") : BookBlock
    data class Quote(val text: String) : BookBlock
    object Break : BookBlock
}
