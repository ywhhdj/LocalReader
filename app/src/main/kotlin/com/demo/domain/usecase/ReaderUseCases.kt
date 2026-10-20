package com.demo.domain.usecase

import com.demo.core.model.Book
import com.demo.core.model.BookBlock
import com.demo.core.model.Chapter
import com.demo.domain.repository.ReaderRepository

class OpenNovelUseCase(private val repo: ReaderRepository) {
    suspend operator fun invoke(book: Book) = repo.openNovel(book)
}

class OpenComicUseCase(private val repo: ReaderRepository) {
    suspend operator fun invoke(book: Book) = repo.openComic(book)
}

class LoadChaptersUseCase(private val repo: ReaderRepository) {
    /** 仅读取目录，不加载正文（详情页预览用） */
    suspend operator fun invoke(book: Book): List<Chapter> =
        repo.openNovel(book).use { it.chapters }
}

class LoadChapterContentUseCase(private val repo: ReaderRepository) {
    suspend operator fun invoke(book: Book, index: Int): List<BookBlock> =
        repo.openNovel(book).use { it.loadChapter(index) }
}
