package com.demo.domain.usecase

import com.demo.domain.repository.BookSource
import com.demo.domain.repository.BookSourceRepository
import com.demo.domain.repository.OnlineBook
import com.demo.domain.repository.OnlineChapter

class OnlineSearchUseCase(private val repo: BookSourceRepository) {
    suspend operator fun invoke(sourceId: String, keyword: String): List<OnlineBook> =
        if (!repo.enabled) emptyList() else repo.search(sourceId, keyword)
}

class OnlineChaptersUseCase(private val repo: BookSourceRepository) {
    suspend operator fun invoke(book: OnlineBook): List<OnlineChapter> =
        if (!repo.enabled) emptyList() else repo.chapters(book)
}

class OnlineContentUseCase(private val repo: BookSourceRepository) {
    suspend operator fun invoke(book: OnlineBook, chapter: OnlineChapter): List<String> =
        if (!repo.enabled) emptyList() else repo.content(book, chapter)
}

class OnlineSourcesUseCase(private val repo: BookSourceRepository) {
    operator fun invoke(): List<BookSource> = if (repo.enabled) repo.sources() else emptyList()

    fun update(sources: List<BookSource>) = repo.updateSources(sources)
}
