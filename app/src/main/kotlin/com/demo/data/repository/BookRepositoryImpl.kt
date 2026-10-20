package com.demo.data.repository

import com.demo.core.database.dao.BookDao
import com.demo.core.model.Book
import com.demo.core.model.BookFilter
import com.demo.core.model.SortOrder
import com.demo.data.cover.CoverStore
import com.demo.data.mapper.toEntity
import com.demo.data.mapper.toModel
import com.demo.domain.repository.BookCounts
import com.demo.domain.repository.BookRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.io.File

class BookRepositoryImpl(
    private val bookDao: BookDao,
    private val coverStore: CoverStore,
    private val pageCache: com.demo.data.cache.PageCache? = null,
    private val bookCacheDir: java.io.File? = null
) : BookRepository {

    override suspend fun page(filter: BookFilter): List<Book> = withContext(Dispatchers.IO) {
        val type = filter.type?.value
        val fav = if (filter.favoriteOnly) 1 else 0
        val kw = filter.keyword.trim()
        val entities = when (filter.sort) {
            SortOrder.LAST_READ -> bookDao.pagedByLastRead(filter.groupId, type, fav, kw, filter.limit, filter.offset)
            SortOrder.RECENT_ADDED -> bookDao.pagedByRecentAdded(filter.groupId, type, fav, kw, filter.limit, filter.offset)
            SortOrder.TITLE -> bookDao.pagedByTitle(filter.groupId, type, fav, kw, filter.limit, filter.offset)
            SortOrder.PROGRESS -> bookDao.pagedByProgress(filter.groupId, type, fav, kw, filter.limit, filter.offset)
        }
        entities.map { it.toModel() }
    }

    override suspend fun recent(limit: Int): List<Book> = withContext(Dispatchers.IO) {
        bookDao.pagedByRecentAdded(null, null, 0, "", limit, 0).map { it.toModel() }
    }

    override suspend fun continueReading(limit: Int): List<Book> = withContext(Dispatchers.IO) {
        bookDao.continueReading(limit).map { it.toModel() }
    }

    override suspend fun favorites(limit: Int): List<Book> = withContext(Dispatchers.IO) {
        bookDao.favorites(limit).map { it.toModel() }
    }

    override suspend fun search(keyword: String, limit: Int): List<Book> = withContext(Dispatchers.IO) {
        bookDao.pagedByLastRead(null, null, 0, keyword.trim(), limit, 0).map { it.toModel() }
    }

    override suspend fun getById(id: Long): Book? = withContext(Dispatchers.IO) {
        bookDao.byId(id)?.toModel()
    }

    override fun observeShelf(groupId: Long?, type: String?, limit: Int): Flow<List<Book>> =
        bookDao.observeShelf(groupId, type, limit).map { list -> list.map { it.toModel() } }

    override suspend fun upsert(book: Book): Long = withContext(Dispatchers.IO) {
        bookDao.upsert(book.toEntity())
    }

    override suspend fun upsertAll(books: List<Book>) = withContext(Dispatchers.IO) {
        bookDao.insertAll(books.map { it.toEntity(0L) })
        Unit
    }

    /** 删除书籍：DB 记录 + 封面 + 章节缓存 + 页面缓存，缺一不可（否则缓存残留占用空间） */
    override suspend fun delete(ids: List<Long>) = withContext(Dispatchers.IO) {
        if (ids.isEmpty()) return@withContext
        val paths = ids.mapNotNull { bookDao.byId(it)?.file_path }
        bookDao.deleteByIds(ids)
        paths.forEach { coverStore.delete(it) }
        ids.forEach { id ->
            pageCache?.clear(id)
            bookCacheDir?.let { runCatching { java.io.File(it, id.toString()).deleteRecursively() } }
        }
    }

    override suspend fun setFavorite(ids: List<Long>, favorite: Boolean) = withContext(Dispatchers.IO) {
        bookDao.updateFavorite(ids, if (favorite) 1 else 0)
    }

    override suspend fun moveToGroup(ids: List<Long>, groupId: Long?) = withContext(Dispatchers.IO) {
        bookDao.updateGroup(ids, groupId)
    }

    override suspend fun updateProgress(id: Long, progress: Float) = withContext(Dispatchers.IO) {
        bookDao.updateProgress(id, progress.coerceIn(0f, 1f), System.currentTimeMillis())
    }

    override suspend fun exists(path: String): Boolean = withContext(Dispatchers.IO) {
        bookDao.byPath(path) != null
    }

    override suspend fun counts(): BookCounts = withContext(Dispatchers.IO) {
        BookCounts(
            total = bookDao.count(),
            novel = bookDao.countByType("NOVEL"),
            comic = bookDao.countByType("COMIC"),
            finished = bookDao.finishedCount(),
            reading = bookDao.readingCount()
        )
    }
}
