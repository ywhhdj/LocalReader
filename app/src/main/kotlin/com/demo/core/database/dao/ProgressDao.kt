package com.demo.core.database.dao

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert

import com.demo.core.database.entity.ReadingProgressEntity

import kotlinx.coroutines.flow.Flow

@Dao
interface ProgressDao {

    @Query("SELECT * FROM reading_progress WHERE book_id = :bookId")
    suspend fun get(bookId: Long): ReadingProgressEntity?

    /** 全量导出（备份） */
    @Query("SELECT * FROM reading_progress ORDER BY book_id ASC")
    suspend fun all(): List<ReadingProgressEntity>

    @Query("SELECT * FROM reading_progress WHERE book_id = :bookId")
    fun observe(bookId: Long): Flow<ReadingProgressEntity?>

    @Upsert
    suspend fun upsert(progress: ReadingProgressEntity)

    @Query("DELETE FROM reading_progress WHERE book_id = :bookId")
    suspend fun delete(bookId: Long)

    @Query("UPDATE reading_progress SET page_index = :pageIndex, progress = :progress, updated_at = :time WHERE book_id = :bookId")
    suspend fun updatePage(bookId: Long, pageIndex: Int, progress: Float, time: Long)

    @Query("UPDATE reading_progress SET chapter_index = :chapterIndex, char_offset = :charOffset, progress = :progress, updated_at = :time WHERE book_id = :bookId")
    suspend fun updateChapter(bookId: Long, chapterIndex: Int, charOffset: Int, progress: Float, time: Long)
}
