package com.demo.domain.usecase

import com.demo.core.model.Book
import com.demo.core.model.BookFilter
import com.demo.core.model.SortOrder
import com.demo.domain.repository.BookRepository

/** 首页主网格分页加载（PAGE_SIZE 由 BookFilter 控制） */
class LoadShelfPageUseCase(private val repo: BookRepository) {
    suspend operator fun invoke(
        groupId: Long? = null,
        type: String? = null,
        favoriteOnly: Boolean = false,
        keyword: String = "",
        sort: SortOrder = SortOrder.LAST_READ,
        page: Int = 0,
        pageSize: Int = BookFilter.DEFAULT_PAGE_SIZE
    ): List<Book> = repo.page(
        BookFilter(
            groupId = groupId,
            type = type?.let { com.demo.core.model.BookType.from(it) },
            favoriteOnly = favoriteOnly,
            keyword = keyword,
            sort = sort,
            limit = pageSize,
            offset = page * pageSize
        )
    )
}

/**
 * 监听"当前筛选下的书籍总数"，作为书库变化的信号。
 *
 * 用途：书架此前只在手动 refresh() 时才重载，删书 / 改分组 / 导入后一旦遗漏调用，
 * UI 与库就会不一致。这里由 Room 的 invalidation 驱动自动刷新。
 */
class ObserveShelfCountUseCase(private val repo: BookRepository) {
    operator fun invoke(groupId: Long?, type: String?, favoriteOnly: Boolean): kotlinx.coroutines.flow.Flow<Int> =
        repo.observeCount(groupId, type, favoriteOnly)
}

class SearchBooksUseCase(private val repo: BookRepository) {
    suspend operator fun invoke(keyword: String, limit: Int = 100): List<Book> =
        if (keyword.isBlank()) emptyList() else repo.search(keyword.trim(), limit)
}

class GetBookUseCase(private val repo: BookRepository) {
    suspend operator fun invoke(id: Long): Book? = repo.getById(id)
}

class ToggleFavoriteUseCase(private val repo: BookRepository) {
    suspend operator fun invoke(ids: List<Long>, favorite: Boolean) = repo.setFavorite(ids, favorite)
}

class MoveToGroupUseCase(private val repo: BookRepository) {
    suspend operator fun invoke(ids: List<Long>, groupId: Long?) = repo.moveToGroup(ids, groupId)
}

class DeleteBooksUseCase(private val repo: BookRepository) {
    suspend operator fun invoke(ids: List<Long>) = repo.delete(ids)
}

class UpdateProgressUseCase(private val repo: com.demo.domain.repository.BookRepository) {
    suspend operator fun invoke(bookId: Long, progress: Float) = repo.updateProgress(bookId, progress)
}
