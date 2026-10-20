package com.demo.data.repository

import com.demo.core.database.dao.BookDao
import com.demo.core.database.dao.ProgressDao
import com.demo.core.database.entity.ReadingProgressEntity
import com.demo.core.model.ReadingProgress
import com.demo.data.mapper.toModel
import com.demo.domain.repository.ProgressRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext

class ProgressRepositoryImpl(
    private val progressDao: ProgressDao,
    private val bookDao: BookDao
) : ProgressRepository {

    override suspend fun get(bookId: Long): ReadingProgress? = withContext(Dispatchers.IO) {
        progressDao.get(bookId)?.toModel()
    }

    override fun observe(bookId: Long): Flow<ReadingProgress?> =
        progressDao.observe(bookId).map { it?.toModel() }

    override suspend fun saveNovel(
        bookId: Long, chapterIndex: Int, charOffset: Int, progress: Float
    ) = withContext(Dispatchers.IO) {
        val existing = progressDao.get(bookId)
        val entity = ReadingProgressEntity(
            book_id = bookId,
            chapter_index = chapterIndex,
            char_offset = charOffset,
            page_index = existing?.page_index ?: 0,
            progress = progress.coerceIn(0f, 1f),
            updated_at = System.currentTimeMillis()
        )
        progressDao.upsert(entity)
        bookDao.updateProgress(bookId, entity.progress, entity.updated_at)
        Unit
    }

    override suspend fun saveComic(
        bookId: Long, pageIndex: Int, pageCount: Int, progress: Float
    ) = withContext(Dispatchers.IO) {
        val computed = if (pageCount > 0) {
            ((pageIndex + 1).toFloat() / pageCount).coerceIn(0f, 1f)
        } else progress.coerceIn(0f, 1f)
        val existing = progressDao.get(bookId)
        val entity = ReadingProgressEntity(
            book_id = bookId,
            chapter_index = existing?.chapter_index ?: 0,
            char_offset = existing?.char_offset ?: 0,
            page_index = pageIndex,
            progress = computed,
            updated_at = System.currentTimeMillis()
        )
        progressDao.upsert(entity)
        bookDao.updateProgress(bookId, entity.progress, entity.updated_at)
        Unit
    }

    override suspend fun clear(bookId: Long) = withContext(Dispatchers.IO) {
        progressDao.delete(bookId)
    }
}
