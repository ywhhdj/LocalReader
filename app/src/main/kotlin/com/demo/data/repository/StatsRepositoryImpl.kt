package com.demo.data.repository

import com.demo.core.common.util.FormatUtil
import com.demo.core.database.dao.BookDao
import com.demo.core.database.dao.SessionDao
import com.demo.core.model.Book
import com.demo.core.model.BookType
import com.demo.core.model.DayStat
import com.demo.core.model.ReadingStats
import com.demo.data.mapper.toModel
import com.demo.domain.repository.StatsRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class StatsRepositoryImpl(
    private val sessionDao: SessionDao,
    private val bookDao: BookDao
) : StatsRepository {

    override suspend fun stats(): ReadingStats = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis()
        // 日界统一按本地时区：SQL 分组与 Kotlin 侧使用同一个偏移
        val offset = FormatUtil.zoneOffsetMillis(now)
        val startOfToday = FormatUtil.startOfToday(now)
        val weekStart = startOfToday - 6L * 86_400_000L

        val today = sessionDao.sumSince(startOfToday)
        val week = sessionDao.sumSince(weekStart)
        val total = sessionDao.sumAll()

        val daily = sessionDao.dailySince(weekStart, offset).associate { it.dayKey to it.total }
        val last7 = (0..6).map { offset ->
            val millis = weekStart + offset * 86_400_000L
            val key = FormatUtil.dayKey(millis)
            DayStat(
                label = if (offset == 6) "今天" else FormatUtil.weekdayLabel(millis),
                millis = daily[key] ?: 0L,
                isToday = offset == 6
            )
        }

        val byType = sessionDao.sumByType()
        val novelMillis = byType.firstOrNull { BookType.from(it.typeName) == BookType.NOVEL }?.total ?: 0L
        val comicMillis = byType.firstOrNull { BookType.from(it.typeName) == BookType.COMIC }?.total ?: 0L

        ReadingStats(
            totalBooks = bookDao.count(),
            novelCount = bookDao.countByType(BookType.NOVEL.value),
            comicCount = bookDao.countByType(BookType.COMIC.value),
            finishedCount = bookDao.finishedCount(),
            readingCount = bookDao.readingCount(),
            todayMillis = today,
            weekMillis = week,
            totalMillis = total,
            streakDays = streakDays(),
            last7Days = last7,
            novelMillis = novelMillis,
            comicMillis = comicMillis
        )
    }

    /** 连续阅读天数：从今天（或昨天）向前累加 */
    private suspend fun streakDays(): Int {
        val keys = sessionDao.recentDayKeys(400, FormatUtil.zoneOffsetMillis()).toSet()
        if (keys.isEmpty()) return 0
        val today = FormatUtil.dayKey(System.currentTimeMillis())
        var cursor = if (keys.contains(today)) today else today - 1
        if (!keys.contains(cursor)) return 0
        var streak = 0
        while (keys.contains(cursor)) {
            streak++
            cursor--
        }
        return streak
    }

    override suspend fun startSession(bookId: Long, type: String): Long = withContext(Dispatchers.IO) {
        sessionDao.insert(
            com.demo.core.database.entity.ReadingSessionEntity(
                book_id = bookId,
                start_at = System.currentTimeMillis(),
                duration_ms = 0L,
                type = type
            )
        )
    }

    override suspend fun endSession(sessionId: Long, startAt: Long, type: String) = withContext(Dispatchers.IO) {
        val duration = (System.currentTimeMillis() - startAt).coerceAtLeast(0)
        if (duration < 1_000L) return@withContext Unit // 小于 1 秒不计入
        sessionDao.updateDuration(sessionId, duration)
        Unit
    }

    override suspend fun clearSessions() = withContext(Dispatchers.IO) {
        sessionDao.clear()
        Unit
    }

    override suspend fun recentFinished(limit: Int): List<Book> = withContext(Dispatchers.IO) {
        bookDao.recentFinished(limit).map { it.toModel() }
    }
}
