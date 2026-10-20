package com.demo.data.parser

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor

import java.io.File
import java.io.FileInputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipFile

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.Logger
import com.demo.core.common.util.NaturalOrderComparator
import com.demo.core.model.Book
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.core.model.ComicPage
import com.demo.data.cover.CoverStore
import com.demo.data.cache.PageCache
import com.demo.data.cover.TextCoverFactory
import com.demo.domain.repository.ComicContent

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
        val pages = if (book.metaJson.isNullOrBlank()) listPages(file, book) else listPages(file, book)
        return ZipComicContent(file, book.id, pages, pageCache)
    }

    private fun imageEntries(zip: ZipFile): List<ZipEntry> {
        val all = zip.entries().toList()
            .filter { !it.isDirectory }
            .filter { it.name.substringAfterLast('.', "").lowercase() in Constants.IMAGE_EXTENSIONS }
            .filter { !it.name.contains("__MACOSX") && !it.name.endsWith(".DS_Store") }
            .filter { !it.name.substringAfterLast('/').startsWith(".") }
            .sortedWith(compareBy(NaturalOrderComparator) { it.name })
        // 先过滤过小图片（封面 logo），若过滤后为空则回退
        val filtered = all.filter { it.size > Constants.MIN_IMAGE_SIZE }
        return filtered.ifEmpty { all }
    }

    private class ZipComicContent(
        private val file: File,
        private val bookId: Long,
        override val pages: List<ComicPage>,
        private val pageCache: PageCache
    ) : ComicContent {

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

/** 图片文件夹漫画 */
class FolderComicParser(
    private val coverStore: CoverStore,
    private val pageCache: PageCache
) : ComicParser {

    override fun matches(file: File, ext: String): Boolean =
        file.isDirectory && imageFiles(file).isNotEmpty()

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
            .filter { File(it).exists() }
        if (paths.isNotEmpty()) return paths.mapIndexed { i, p -> ComicPage(i, filePath = p) }
        return imageFiles(file).mapIndexed { i, f -> ComicPage(i, filePath = f.absolutePath) }
    }

    override suspend fun openComic(file: File, book: Book): ComicContent =
        FolderComicContent(book.id, listPages(file, book), pageCache)

    private fun imageFiles(dir: File): List<File> {
        val all = dir.listFiles()
            ?.filter { it.isFile }
            ?.filter { it.extension.lowercase() in Constants.IMAGE_EXTENSIONS }
            ?.filter { !it.name.startsWith(".") }
            ?.sortedWith(compareBy(NaturalOrderComparator) { it.name })
            ?: emptyList()
        val filtered = all.filter { it.length() > Constants.MIN_IMAGE_SIZE }
        return filtered.ifEmpty { all }
    }

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

/**
 * PDF（按漫画方式逐页渲染）
 *
 * 修复要点：
 * 1. ParcelFileDescriptor 与 PdfRenderer 成对关闭（旧实现泄漏 fd，打开多本 PDF 后崩溃）；
 * 2. PdfRenderer 非线程安全，所有渲染串行化；
 * 3. 封面/页面按**长边**缩放（旧实现按宽度，竖版 PDF 封面被拉伸裁切）；
 * 4. 渲染前填充白底，避免透明区域显示黑块。
 */
class PdfComicParser(
    private val coverStore: CoverStore,
    private val pageCache: PageCache,
    private val textCoverFactory: TextCoverFactory = TextCoverFactory()
) : ComicParser {

    override fun matches(file: File, ext: String): Boolean =
        file.isFile && ext.equals("pdf", true)

    override suspend fun parseMeta(file: File): Book? = runCatching {
        val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        pfd.use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
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
    }.onFailure { e ->
        Logger.w("PDF 解析失败：${file.absolutePath} ${e.message}", "PdfComicParser")
    }.getOrNull()

    override suspend fun listPages(file: File, book: Book): List<ComicPage> =
        List(book.pageCount.coerceAtLeast(0)) { ComicPage(it, pdfPage = it) }

    override suspend fun openComic(file: File, book: Book): ComicContent =
        PdfComicContent(file, book.id, book.pageCount.coerceAtLeast(0), pageCache)

    private fun renderCover(renderer: PdfRenderer, file: File): String? = runCatching {
        synchronized(renderer) {
            renderer.openPage(0).use { page ->
                val scale = Constants.COVER_MAX_EDGE.toFloat() / maxOf(page.width, page.height).coerceAtLeast(1)
                val w = (page.width * scale).toInt().coerceAtLeast(1)
                val h = (page.height * scale).toInt().coerceAtLeast(1)
                val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                bitmap.eraseColor(Color.WHITE)
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                coverStore.save(bitmap, file.absolutePath)
            }
        }
    }.getOrNull()

    private class PdfComicContent(
        private val file: File,
        private val bookId: Long,
        pageCount: Int,
        private val pageCache: PageCache
    ) : ComicContent {

        override val pages: List<ComicPage> = List(pageCount) { ComicPage(it, pdfPage = it) }

        @Volatile
        private var renderer: PdfRenderer? = null
        @Volatile
        private var pfd: ParcelFileDescriptor? = null
        private val lock = Any()

        private fun renderer(): PdfRenderer = renderer ?: synchronized(lock) {
            renderer ?: run {
                val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                pfd = descriptor
                PdfRenderer(descriptor).also { renderer = it }
            }
        }

        override suspend fun resolvePage(index: Int): String? {
            pageCache.cached(bookId, index)?.let { return it }
            return runCatching {
                val r = renderer()
                synchronized(lock) {
                    r.openPage(index).use { page ->
                        val longEdge = maxOf(page.width, page.height).coerceAtLeast(1)
                        val scale = (Constants.PDF_PAGE_MAX_EDGE.toFloat() / longEdge).coerceAtMost(2f)
                        val w = (page.width * scale).toInt().coerceAtLeast(1)
                        val h = (page.height * scale).toInt().coerceAtLeast(1)
                        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        val path = pageCache.put(bookId, index, bitmap)
                        if (!bitmap.isRecycled) bitmap.recycle()
                        path
                    }
                }
            }.onFailure { e ->
                Logger.w("PDF 渲染失败：${file.name} #$index ${e.message}", "PdfComicParser")
            }.getOrNull()
        }

        override fun close() {
            synchronized(lock) {
                runCatching { renderer?.close() }
                runCatching { pfd?.close() }
                renderer = null
                pfd = null
            }
        }
    }
}
