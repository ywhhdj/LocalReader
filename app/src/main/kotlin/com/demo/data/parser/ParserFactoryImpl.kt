package com.demo.data.parser

import java.io.File

import com.demo.core.common.util.FileUtil
import com.demo.data.cover.CoverStore
import com.demo.data.cache.PageCache
import com.demo.data.cover.TextCoverFactory


/** 解析器注册与分发（RAR 预留：未注册，扫描时给出"请转为 CBZ/ZIP"提示） */
class ParserFactoryImpl(
    coverStore: CoverStore,
    pageCache: PageCache,
    bookCacheDir: File,
    textCoverFactory: TextCoverFactory = TextCoverFactory()
) : ParserFactory {

    private val novelParsers: List<NovelParser> = listOf(
        EpubParser(coverStore, bookCacheDir, textCoverFactory),
        TxtParser(coverStore, textCoverFactory)
    )

    private val comicParsers: List<ComicParser> = listOf(
        ZipComicParser(coverStore, pageCache),
        FolderComicParser(coverStore, pageCache),
        PdfComicParser(coverStore, pageCache, textCoverFactory)
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
