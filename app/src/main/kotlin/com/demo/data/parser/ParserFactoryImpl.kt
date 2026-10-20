package com.demo.data.parser

import com.demo.core.common.util.FileUtil
import com.demo.data.cache.CoverStore
import com.demo.data.cache.PageCache
import java.io.File

/** 解析器注册与分发（RAR 预留：未注册时返回 null，UI 提示转 CBZ） */
class ParserFactoryImpl(
    coverStore: CoverStore,
    pageCache: PageCache,
    bookCacheDir: File
) : ParserFactory {

    private val novelParsers: List<NovelParser> = listOf(
        EpubParser(coverStore, bookCacheDir),
        TxtParser()
    )

    private val comicParsers: List<ComicParser> = listOf(
        ZipComicParser(coverStore, pageCache),
        FolderComicParser(coverStore, pageCache),
        PdfComicParser(coverStore, pageCache)
    )

    private val all: List<BookParser> = novelParsers + comicParsers

    override fun novelParser(file: File, ext: String): NovelParser? =
        novelParsers.firstOrNull { it.matches(file, ext) }

    override fun comicParser(file: File, ext: String): ComicParser? =
        comicParsers.firstOrNull { it.matches(file, ext) }

    override fun anyParser(file: File, ext: String): BookParser? =
        all.firstOrNull { it.matches(file, ext) }

    companion object {
        fun extOf(file: File): String = if (file.isDirectory) "" else FileUtil.extension(file.name)
    }
}
