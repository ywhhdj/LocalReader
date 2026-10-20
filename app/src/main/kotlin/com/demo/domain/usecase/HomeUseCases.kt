package com.demo.domain.usecase

import com.demo.core.model.Book
import com.demo.core.model.BookFilter
import com.demo.domain.repository.BookRepository

/** 首页区块数据（条数已在 UseCase 内限制，避免首页加载过多） */
data class HomeSections(
    val continueBooks: List<Book> = emptyList(),
    val recentBooks: List<Book> = emptyList(),
    val favoriteBooks: List<Book> = emptyList()
)

class LoadHomeSectionsUseCase(private val repo: BookRepository) {
    suspend operator fun invoke(): HomeSections = HomeSections(
        continueBooks = repo.continueReading(BookFilter.CONTINUE_LIMIT),
        recentBooks = repo.recent(BookFilter.RECENT_LIMIT),
        favoriteBooks = repo.favorites(BookFilter.RECENT_LIMIT)
    )
}
