package com.demo.data.parser.comic

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.NaturalOrderComparator
import com.demo.core.model.Book
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.core.model.ComicChapter
import com.demo.core.model.ComicPage
import com.demo.data.cache.PageCache
import com.demo.data.cover.CoverStore
import com.demo.data.parser.ComicParser
import com.demo.domain.repository.ComicContent
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipFile

/** CBZ / ZIP 漫画 */
class ZipComicParser(
    private val coverStore: CoverStore,
    private val pageCache: PageCache
) : ComicParser {

    override fun matches(file: File, ext: String): Boolean =
        file.isFile && (ext.equals("cbz", true) || ext.equals("zip", true))

    override suspend fun parseMeta(file: File): Book? = runCatching {
        ZipFile(file).use { zip ->
            val entries = imageEntries(zip)
            if (entries.isEmpty()) return null
            val cover = zip.getInputStream(entries.first())?.use { input ->
                coverStore.save(input, file.absolutePath)
            }
            Book(
                title = FileUtil.humanTitle(file.name),
                type = BookType.COMIC,
                format = if (file.extension.equals("cbz", true)) BookFormat.CBZ else BookFormat.ZIP,
                filePath = file.absolutePath,
                coverPath = cover,
                sizeBytes = file.length(),
                pageCount = entries.size,
                metaJson = entries.joinToString("\u0001") { it.name }
            )
        }
    }.getOrNull()

    override suspend fun listPages(file: File, book: Book): List<ComicPage> {
        val names = book.metaJson?.split("\u0001")?.filter { it.isNotBlank() }.orEmpty()
        if (names.isNotEmpty()) {
            return names.mapIndexed { i, n -> ComicPage(i, entryName = n) }
        }
        return runCatching {
            ZipFile(file).use { imageEntries(it).mapIndexed { i, e -> ComicPage(i, entryName = e.name) } }
        }.getOrDefault(emptyList())
    }

    override suspend fun openComic(file: File, book: Book): ComicContent {
        val pages = listPages(file, book)
        return ZipComicContent(file, book.id, pages, pageCache)
    }

    private fun imageEntries(zip: ZipFile): List<ZipEntry> {
        val all = zip.entries().toList()
            .filter { !it.isDirectory }
            .filter { it.name.substringAfterLast('.', "").lowercase() in Constants.IMAGE_EXTENSIONS }
            .filter { !it.name.contains("__MACOSX") && !it.name.endsWith(".DS_Store") }
            .filter { !it.name.substringAfterLast('/').startsWith(".") }
            .sortedWith(compareBy(NaturalOrderComparator) { it.name })
        val filtered = all.filter { it.size > Constants.MIN_IMAGE_SIZE }
        return filtered.ifEmpty { all }
    }

    private class ZipComicContent(
        private val file: File,
        private val bookId: Long,
        override val pages: List<ComicPage>,
        private val pageCache: PageCache
    ) : ComicContent {

        override val chapters: List<ComicChapter> =
            if (pages.isEmpty()) emptyList()
            else listOf(ComicChapter(
                index = 0,
                title = ComicChapter.SINGLE_TITLE,
                startIndex = 0,
                endIndex = pages.lastIndex
            ))

        @Volatile
        private var zip: ZipFile? = null
        private val lock = Any()

        private fun zip(): ZipFile = zip ?: synchronized(lock) { zip ?: ZipFile(file).also { zip = it } }

        override suspend fun resolvePage(index: Int): String? {
            val page = pages.getOrNull(index) ?: return null
            pageCache.cached(bookId, index)?.let { return it }
            val name = page.entryName ?: return null
            return runCatching {
                val entry = zip().getEntry(name) ?: return null
                val bytes = zip().getInputStream(entry).use { it.readBytes() }
                pageCache.putBytes(bookId, index, bytes)
            }.getOrNull()
        }

        override fun close() {
            synchronized(lock) {
                runCatching { zip?.close() }
                zip = null
            }
        }
    }
}