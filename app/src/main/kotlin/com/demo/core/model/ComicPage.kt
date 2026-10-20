package com.demo.core.model

/** 漫画页描述（不含 Bitmap，避免内存占用） */
data class ComicPage(
    val index: Int,
    /** zip 内条目名（压缩包） */
    val entryName: String? = null,
    /** 本地文件路径（文件夹模式） */
    val filePath: String? = null,
    /** PDF 页码 */
    val pdfPage: Int = -1,
    /** 已知尺寸（可选，用于占位比例） */
    val width: Int = 0,
    val height: Int = 0
) {
    val aspect: Float get() = if (width > 0 && height > 0) width.toFloat() / height else 0.72f
}

/** 漫画阅读方向 */
enum class ComicDirection { LTR, RTL, VERTICAL }

/** 页面适配模式 */
enum class PageFitMode { WIDTH, HEIGHT, ORIGINAL }
