package com.demo.domain.repository

import com.demo.core.model.ReadingProgress

import kotlinx.coroutines.flow.Flow

interface ProgressRepository {
    suspend fun get(bookId: Long): ReadingProgress?
    fun observe(bookId: Long): Flow<ReadingProgress?>
    suspend fun saveNovel(bookId: Long, chapterIndex: Int, charOffset: Int, progress: Float)
    suspend fun saveComic(bookId: Long, pageIndex: Int, pageCount: Int, progress: Float)
    suspend fun clear(bookId: Long)
}
