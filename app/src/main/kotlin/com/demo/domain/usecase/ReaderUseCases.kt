package com.demo.domain.usecase

import com.demo.core.model.Book
import com.demo.domain.repository.ReaderRepository

class OpenNovelUseCase(private val repo: ReaderRepository) {
    suspend operator fun invoke(book: Book) = repo.openNovel(book)
}

class OpenComicUseCase(private val repo: ReaderRepository) {
    suspend operator fun invoke(book: Book) = repo.openComic(book)
}

