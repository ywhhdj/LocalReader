package com.demo.core.model

/** 阅读统计聚合结果（个人页使用） */
data class ReadingStats(
    val totalBooks: Int = 0,
    val novelCount: Int = 0,
    val comicCount: Int = 0,
    val finishedCount: Int = 0,
    val readingCount: Int = 0,
    val todayMillis: Long = 0L,
    val weekMillis: Long = 0L,
    val totalMillis: Long = 0L,
    val streakDays: Int = 0,
    /** 近 7 天：day label -> 毫秒 */
    val last7Days: List<DayStat> = emptyList(),
    /** 分类阅读时长占比（毫秒） */
    val novelMillis: Long = 0L,
    val comicMillis: Long = 0L
)

data class DayStat(val label: String, val millis: Long, val isToday: Boolean = false)

/** 单次阅读会话（统计数据源） */
data class ReadingSession(
    val id: Long = 0L,
    val bookId: Long,
    val startAt: Long,
    val durationMs: Long,
    val type: BookType = BookType.NOVEL
)
