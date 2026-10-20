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

    @Query(
        """SELECT start_at / 86400000 AS dayKey, COALESCE(SUM(duration_ms), 0) AS total
           FROM reading_sessions WHERE start_at >= :from
           GROUP BY dayKey ORDER BY dayKey ASC"""
    )
    suspend fun dailySince(from: Long): List<DayAggregate>

    @Query(
        """SELECT b.type AS typeName, COALESCE(SUM(s.duration_ms), 0) AS total
           FROM reading_sessions s INNER JOIN books b ON s.book_id = b.id
           GROUP BY b.type"""
    )
    suspend fun sumByType(): List<TypeAggregate>

    @Query("SELECT DISTINCT start_at / 86400000 FROM reading_sessions ORDER BY 1 DESC LIMIT :limit")
    suspend fun recentDayKeys(limit: Int): List<Long>

    @Query("DELETE FROM reading_sessions")
    suspend fun clear()

    @Query("SELECT COUNT(*) FROM reading_sessions")
    suspend fun count(): Int
}

data class DayAggregate(val dayKey: Long, val total: Long)

data class TypeAggregate(val typeName: String, val total: Long)
