package com.demo.domain.repository

import com.demo.core.model.Book
import com.demo.core.model.BookFilter

import kotlinx.coroutines.flow.Flow

interface BookRepository {

    /** 书架分页查询（结果受 BookFilter.limit/offset 约束，避免全量加载） */
    suspend fun page(filter: BookFilter): List<Book>

    /** 最近添加（用于首页横向区块，内部限制条数） */
    suspend fun recent(limit: Int): List<Book>

    /** 继续阅读（进度 0~1） */
    suspend fun continueReading(limit: Int): List<Book>

    /** 收藏 */
    suspend fun favorites(limit: Int): List<Book>

    suspend fun search(keyword: String, limit: Int = 100): List<Book>

    suspend fun getById(id: Long): Book?

    fun observeShelf(groupId: Long?, type: String?, limit: Int): Flow<List<Book>>

    suspend fun upsert(book: Book): Long

    suspend fun upsertAll(books: List<Book>)

    suspend fun delete(ids: List<Long>)

    suspend fun setFavorite(ids: List<Long>, favorite: Boolean)

    suspend fun moveToGroup(ids: List<Long>, groupId: Long?)

    suspend fun updateProgress(id: Long, progress: Float)

    suspend fun exists(path: String): Boolean

    suspend fun counts(): BookCounts
}

data class BookCounts(
    val total: Int = 0,
    val novel: Int = 0,
    val comic: Int = 0,
    val finished: Int = 0,
    val reading: Int = 0
)
