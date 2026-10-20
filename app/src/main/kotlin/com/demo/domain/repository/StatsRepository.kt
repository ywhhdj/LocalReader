package com.demo.domain.repository

import com.demo.core.model.Book
import com.demo.core.model.ReadingStats

interface StatsRepository {
    suspend fun stats(): ReadingStats
    suspend fun startSession(bookId: Long, type: String): Long
    suspend fun endSession(sessionId: Long, startAt: Long, type: String)
    suspend fun clearSessions()
    suspend fun recentFinished(limit: Int): List<Book>
}
