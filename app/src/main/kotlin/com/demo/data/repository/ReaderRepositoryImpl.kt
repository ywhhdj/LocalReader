package com.demo.data.repository

import com.demo.core.model.Book
import com.demo.data.parser.ParserFactory
import com.demo.data.parser.ParserFactoryImpl
import com.demo.domain.repository.ComicContent
import com.demo.domain.repository.NovelContent
import com.demo.domain.repository.ReaderRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

class ReaderRepositoryImpl(
    private val parserFactory: ParserFactory
) : ReaderRepository {

    override suspend fun openNovel(book: Book): NovelContent = withContext(Dispatchers.IO) {
        val file = File(book.filePath)
        val ext = ParserFactoryImpl.extOf(file)
        val parser = parserFactory.novelParser(file, ext)
            ?: throw com.demo.core.common.AppError.UnsupportedFormat(ext.ifBlank { book.format.value })
        parser.openNovel(file, book)
    }

    override suspend fun openComic(book: Book): ComicContent = withContext(Dispatchers.IO) {
        val file = File(book.filePath)
        val ext = ParserFactoryImpl.extOf(file)
        val parser = parserFactory.comicParser(file, ext)
            ?: throw com.demo.core.common.AppError.UnsupportedFormat(ext.ifBlank { book.format.value })
        parser.openComic(file, book)
    }

    override suspend fun parseMeta(path: String): Book = withContext(Dispatchers.IO) {
        val file = File(path)
        val ext = ParserFactoryImpl.extOf(file)
        parserFactory.anyParser(file, ext)?.parseMeta(file)
            ?: throw com.demo.core.common.AppError.UnsupportedFormat(ext)
    }
}
