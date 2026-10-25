package com.demo.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

import com.demo.core.database.entity.ReadingSessionEntity

@Dao
interface SessionDao {

    @Insert
    suspend fun insert(session: ReadingSessionEntity): Long

    @Query("SELECT COALESCE(SUM(duration_ms), 0) FROM reading_sessions WHERE start_at >= :from")
    suspend fun sumSince(from: Long): Long

    @Query("UPDATE reading_sessions SET duration_ms = :duration WHERE id = :id")
    suspend fun updateDuration(id: Long, duration: Long)

    @Query("SELECT COALESCE(SUM(duration_ms), 0) FROM reading_sessions")
    suspend fun sumAll(): Long

    // 日界按"本地时区 0 点"切分：start_at 是 UTC 毫秒，需先加本地偏移再整除。
    // :offset 由调用方传入 FormatUtil.zoneOffsetMillis()，保证与 Kotlin 侧口径一致。
    @Query(
        """SELECT (start_at + :offset) / 86400000 AS dayKey, COALESCE(SUM(duration_ms), 0) AS total
           FROM reading_sessions WHERE start_at >= :from
           GROUP BY dayKey ORDER BY dayKey ASC"""
    )
    suspend fun dailySince(from: Long, offset: Long): List<DayAggregate>

    @Query(
        """SELECT b.type AS typeName, COALESCE(SUM(s.duration_ms), 0) AS total
           FROM reading_sessions s INNER JOIN books b ON s.book_id = b.id
           GROUP BY b.type"""
    )
    suspend fun sumByType(): List<TypeAggregate>

    @Query(
        """SELECT DISTINCT (start_at + :offset) / 86400000 FROM reading_sessions
           ORDER BY 1 DESC LIMIT :limit"""
    )
    suspend fun recentDayKeys(limit: Int, offset: Long): List<Long>

    @Query("DELETE FROM reading_sessions")
    suspend fun clear()

    @Query("SELECT COUNT(*) FROM reading_sessions")
    suspend fun count(): Int

    /** 全量导出（备份） */
    @Query("SELECT * FROM reading_sessions ORDER BY start_at ASC")
    suspend fun all(): List<ReadingSessionEntity>
}

data class DayAggregate(val dayKey: Long, val total: Long)

data class TypeAggregate(val typeName: String, val total: Long)
