package com.demo.data.parser

import com.demo.core.common.util.FileUtil
import com.demo.data.cache.PageCache
import com.demo.data.cover.CoverStore
import com.demo.data.cover.TextCoverFactory
import com.demo.data.parser.comic.FolderComicParser
import com.demo.data.parser.comic.PdfComicParser
import com.demo.data.parser.comic.RarComicParser
import com.demo.data.parser.comic.ZipComicParser

import java.io.File

/** 解析器注册与分发 */
class ParserFactoryImpl(
    coverStore: CoverStore,
    pageCache: PageCache,
    bookCacheDir: File,
    textCoverFactory: TextCoverFactory = TextCoverFactory(),
    context: android.content.Context? = null
) : ParserFactory {

    private val novelParsers: List<NovelParser> = listOf(
        EpubParser(coverStore, bookCacheDir, textCoverFactory),
        TxtParser(coverStore, textCoverFactory)
    )

    private val comicParsers: List<ComicParser> = listOf(
        ZipComicParser(coverStore, pageCache),
        RarComicParser(coverStore, pageCache),
        FolderComicParser(coverStore),
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