package com.demo.data.parser

import android.graphics.BitmapFactory
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.NaturalOrderComparator
import com.demo.core.model.Book
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.core.model.ComicPage
import com.demo.data.cache.CoverStore
import com.demo.data.cache.ImageTools
import com.demo.data.cache.PageCache
import com.demo.domain.repository.ComicContent
import java.io.File
import java.io.FileInputStream
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

    private fun imageEntries(zip: ZipFile): List<ZipEntry> = zip.entries().toList()
        .filter { !it.isDirectory }
        .filter { it.name.substringAfterLast('.', "").lowercase() in com.demo.core.common.util.Constants.IMAGE_EXTENSIONS }
        .filter { !it.name.contains("__MACOSX") && !it.name.endsWith(".DS_Store") }
        .filter { it.size > 8 * 1024 }
        .sortedWith(compareBy(NaturalOrderComparator) { it.name })

    private class ZipComicContent(
        private val file: File,
        private val bookId: Long,
        override val pages: List<ComicPage>,
        private val pageCache: PageCache
    ) : ComicContent {

        @Volatile
        private var zip: ZipFile? = null

        private fun zip(): ZipFile = zip ?: synchronized(this) { zip ?: ZipFile(file).also { zip = it } }

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
            synchronized(this) {
                runCatching { zip?.close() }
                zip = null
            }
        }
    }
}

/** 图片文件夹漫画 */
class FolderComicParser(
    private val coverStore: CoverStore,
    private val pageCache: PageCache
) : ComicParser {

    override fun matches(file: File, ext: String): Boolean = file.isDirectory

    override suspend fun parseMeta(file: File): Book? = runCatching {
        val images = imageFiles(file)
        if (images.isEmpty()) return null
        val cover = runCatching {
            coverStore.save(FileInputStream(images.first()).use { it.readBytes() }, file.absolutePath)
        }.getOrNull()
        Book(
            title = FileUtil.humanTitle(file.name),
            type = BookType.COMIC,
            format = BookFormat.FOLDER,
            filePath = file.absolutePath,
            coverPath = cover,
            sizeBytes = images.sumOf { it.length() },
            pageCount = images.size,
            metaJson = images.joinToString("\u0001") { it.absolutePath }
        )
    }.getOrNull()

    override suspend fun listPages(file: File, book: Book): List<ComicPage> {
        val paths = book.metaJson?.split("\u0001")?.filter { it.isNotBlank() }.orEmpty()
        if (paths.isNotEmpty()) return paths.mapIndexed { i, p -> ComicPage(i, filePath = p) }
        return imageFiles(file).mapIndexed { i, f -> ComicPage(i, filePath = f.absolutePath) }
    }

    override suspend fun openComic(file: File, book: Book): ComicContent {
        val pages = listPages(file, book)
        return FolderComicContent(book.id, pages, pageCache)
    }

    private fun imageFiles(dir: File): List<File> = dir.listFiles()
        ?.filter { it.isFile }
        ?.filter { it.extension.lowercase() in com.demo.core.common.util.Constants.IMAGE_EXTENSIONS }
        ?.filter { !it.name.startsWith(".") }
        ?.filter { it.length() > 8 * 1024 }
        ?.sortedWith(compareBy(NaturalOrderComparator) { it.name })
        ?: emptyList()

    private class FolderComicContent(
        private val bookId: Long,
        override val pages: List<ComicPage>,
        private val pageCache: PageCache
    ) : ComicContent {
        override suspend fun resolvePage(index: Int): String? {
            val path = pages.getOrNull(index)?.filePath ?: return null
            pageCache.cached(bookId, index)?.let { return it }
            return runCatching {
                val bytes = FileInputStream(path).use { it.readBytes() }
                pageCache.putBytes(bookId, index, bytes)
            }.getOrNull()
        }

        override fun close() = Unit
    }
}

/** PDF（按漫画方式逐页渲染） */
class PdfComicParser(
    private val coverStore: CoverStore,
    private val pageCache: PageCache
) : ComicParser {

    override fun matches(file: File, ext: String): Boolean =
        file.isFile && ext.equals("pdf", true)

    override suspend fun parseMeta(file: File): Book? = runCatching {
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { pfd ->
            PdfRenderer(pfd).use { renderer ->
                val count = renderer.pageCount
                if (count <= 0) return null
                val cover = renderCover(renderer, file)
                Book(
                    title = FileUtil.humanTitle(file.name),
                    type = BookType.COMIC,
                    format = BookFormat.PDF,
                    filePath = file.absolutePath,
                    coverPath = cover,
                    sizeBytes = file.length(),
                    pageCount = count
                )
            }
        }
    }.getOrNull()

    override suspend fun listPages(file: File, book: Book): List<ComicPage> =
        List(book.pageCount.coerceAtLeast(0)) { ComicPage(it, pdfPage = it) }

    override suspend fun openComic(file: File, book: Book): ComicContent =
        PdfComicContent(file, book.id, listPages(file, book), pageCache)

    private fun renderCover(renderer: PdfRenderer, file: File): String? = runCatching {
        renderer.openPage(0).use { page ->
            val scale = 450f / page.width.coerceAtLeast(1)
            val w = (page.width * scale).toInt().coerceAtLeast(1)
            val h = (page.height * scale).toInt().coerceAtLeast(1)
            val bitmap = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            coverStore.save(bitmap, file.absolutePath)
        }
    }.getOrNull()

    private class PdfComicContent(
        private val file: File,
        private val bookId: Long,
        override val pages: List<ComicPage>,
        private val pageCache: PageCache
    ) : ComicContent {

        @Volatile
        private var renderer: PdfRenderer? = null

        private fun renderer(): PdfRenderer = renderer ?: synchronized(this) {
            renderer ?: PdfRenderer(
                ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            ).also { renderer = it }
        }

        override suspend fun resolvePage(index: Int): String? {
            pageCache.cached(bookId, index)?.let { return it }
            return runCatching {
                renderer().openPage(index).use { page ->
                    val scale = 2048f / page.width.coerceAtLeast(1)
                    val w = (page.width * scale).toInt().coerceAtLeast(1)
                    val h = (page.height * scale).toInt().coerceAtLeast(1)
                    val bitmap = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    val path = pageCache.put(bookId, index, bitmap)
                    if (!bitmap.isRecycled) bitmap.recycle()
                    path
                }
            }.getOrNull()
        }

        override fun close() {
            synchronized(this) {
                runCatching { renderer?.close() }
                renderer = null
            }
        }
    }
}
