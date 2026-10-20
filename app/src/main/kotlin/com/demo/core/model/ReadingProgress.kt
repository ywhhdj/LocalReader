package com.demo.core.model

/** 阅读进度 */
data class ReadingProgress(
    val bookId: Long,
    val chapterIndex: Int = 0,
    val charOffset: Int = 0,
    val pageIndex: Int = 0,
    val progress: Float = 0f,
    val updatedAt: Long = System.currentTimeMillis()
)
