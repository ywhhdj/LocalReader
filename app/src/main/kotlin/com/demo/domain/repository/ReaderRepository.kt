package com.demo.domain.repository

import com.demo.core.model.Book
import com.demo.core.model.BookBlock
import com.demo.core.model.Chapter
import com.demo.core.model.ComicChapter
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
    /** 话结构；整本单话时为空，由 [chaptersOrSingle] 兜底 */
    val chapters: List<ComicChapter> get() = emptyList()
    /** 返回缓存文件路径（PDF 渲染落地，zip 解压落地） */
    suspend fun resolvePage(index: Int): String?
}

/** 无话结构时整本视作 1 话 */
fun ComicContent.chaptersOrSingle(): List<ComicChapter> {
    if (chapters.isNotEmpty()) return chapters
    val last = pages.lastIndex
    if (last < 0) return emptyList()
    return listOf(ComicChapter(
        index=0,
        title=ComicChapter.SINGLE_TITLE,
        startIndex=0,
        endIndex=last
    ))
}

fun ComicContent.chapterOf(pageIndex: Int): ComicChapter? =
    chaptersOrSingle().firstOrNull { it.contains(pageIndex) } ?: chaptersOrSingle().firstOrNull()

interface ReaderRepository {
    suspend fun openNovel(book: Book): NovelContent
    suspend fun openComic(book: Book): ComicContent
    /** 解析元数据（导入/重新解析） */
    suspend fun parseMeta(path: String): Book
}
