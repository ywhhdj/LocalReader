package com.demo.domain.repository

import com.demo.core.model.Book
import com.demo.core.model.BookBlock
import com.demo.core.model.Chapter
import com.demo.core.model.ComicPage

import java.io.Closeable

/** 已打开的小说：惰性读取章节，用完必须 close（释放 zip/文件句柄） */
interface NovelContent : Closeable {
    val chapters: List<Chapter>
    suspend fun loadChapter(index: Int): List<BookBlock>
}

/** 已打开的漫画：按需解析页，返回可直接解码的本地文件路径 */
interface ComicContent : Closeable {
    val pages: List<ComicPage>
    /** 返回缓存文件路径（PDF 渲染落地，zip 解压落地） */
    suspend fun resolvePage(index: Int): String?
}

interface ReaderRepository {
    suspend fun openNovel(book: Book): NovelContent
    suspend fun openComic(book: Book): ComicContent
    /** 解析元数据（导入/重新解析） */
    suspend fun parseMeta(path: String): Book
}
