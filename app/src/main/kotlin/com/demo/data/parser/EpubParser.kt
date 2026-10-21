package com.demo.data.parser

import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.Book
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.data.cover.CoverStore
import com.demo.data.cover.TextCoverFactory
import com.demo.data.parser.common.ZipUtils
import com.demo.data.parser.epub.EpubContainer
import com.demo.data.parser.epub.EpubCover
import com.demo.data.parser.epub.EpubMetaCodec
import com.demo.data.parser.epub.EpubNovelContent
import com.demo.data.parser.epub.EpubOpf
import com.demo.data.parser.epub.EpubToc
import com.demo.domain.repository.NovelContent

import java.io.File
import java.util.zip.ZipFile

class EpubParser(
    private val coverStore: CoverStore,
    private val bookCacheDir: File,
    private val textCoverFactory: TextCoverFactory = TextCoverFactory()
) : NovelParser {

    override fun matches(file: File, ext: String): Boolean =
        ext.equals("epub", ignoreCase = true)

    override suspend fun parseMeta(file: File): Book? = runCatching {
        ZipFile(file).use { zip ->
            val opfPath = EpubContainer.resolveOpfPath(zip) ?: return null
            val opfBytes = ZipUtils.readEntryBytes(zip, opfPath) ?: return null
            val opf = EpubOpf.parse(opfBytes)
            val basePath = opfPath.substringBeforeLast('/', "")
            val chapters = EpubToc.resolve(zip, opf, basePath)
            val coverPath = EpubCover.resolve(zip, opf, basePath, file, chapters, coverStore, textCoverFactory)

            Book(
                title = opf.title.ifBlank { FileUtil.humanTitle(file.name) },
                author = opf.author.ifBlank { "未知" },
                type = BookType.NOVEL,
                format = BookFormat.EPUB,
                filePath = file.absolutePath,
                coverPath = coverPath,
                sizeBytes = file.length(),
                chapterCount = chapters.size,
                metaJson = EpubMetaCodec.encode(opfPath, chapters)
            )
        }
    }.getOrNull()

    override suspend fun openNovel(file: File, book: Book): NovelContent {
        val (opfPath, chapters) = EpubMetaCodec.decode(book.metaJson)
        val basePath = opfPath.substringBeforeLast('/', "")
        val grouped = VolumeSplitter.apply(chapters)
        return EpubNovelContent(
            file = file,
            bookId = book.id,
            chapters = grouped,
            basePath = basePath,
            cacheDir = File(bookCacheDir, book.id.toString())
        )
    }
}