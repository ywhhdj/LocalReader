package com.demo.domain.usecase

import com.demo.core.model.BookType
import com.demo.core.model.ReadingStats
import com.demo.domain.repository.StatsRepository

class GetStatsUseCase(private val repo: StatsRepository) {
    suspend operator fun invoke(): ReadingStats = repo.stats()
}

/** 阅读会话计时：进入阅读器开始，退出/暂停结束 */
class ReadingSessionUseCase(private val repo: StatsRepository) {

    suspend fun start(bookId: Long, type: BookType): Long =
        repo.startSession(bookId, type.value)

    suspend fun end(sessionId: Long, startAt: Long, type: BookType) {
        if (sessionId <= 0L) return
        repo.endSession(sessionId, startAt, type.value)
    }
}
