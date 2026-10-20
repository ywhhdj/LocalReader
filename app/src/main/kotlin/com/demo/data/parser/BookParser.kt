package com.demo.data.parser

import com.demo.core.model.Book
import com.demo.domain.repository.ComicContent
import com.demo.domain.repository.NovelContent
import java.io.File

/** 解析器能力接口：元数据解析 */
interface BookParser {
    /** 文件扩展名或目录判断 */
    fun matches(file: File, ext: String): Boolean

    /** 解析元数据（标题/作者/章节数/页数），并生成封面 */
    suspend fun parseMeta(file: File): Book?

    /** ERROR 之外的附加信息通过 Book.metaJson 传递 */
}

interface NovelParser : BookParser {
    suspend fun openNovel(file: File, book: Book): NovelContent
}

interface ComicParser : BookParser {
    /** 仅列页，不解码 */
    suspend fun listPages(file: File, book: Book): List<com.demo.core.model.ComicPage>
    suspend fun openComic(file: File, book: Book): ComicContent
}

/** 统一入口：按扩展名选择解析器 */
interface ParserFactory {
    fun novelParser(file: File, ext: String): NovelParser?
    fun comicParser(file: File, ext: String): ComicParser?
    fun anyParser(file: File, ext: String): BookParser?
}
