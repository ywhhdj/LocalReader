package com.demo.data.parser.comic

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.Logger
import com.demo.core.model.Book
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.core.model.ComicChapter
import com.demo.core.model.ComicPage
import com.demo.data.cache.PageCache
import com.demo.data.cover.CoverStore
import com.demo.data.cover.TextCoverFactory
import com.demo.data.parser.ComicParser
import com.demo.domain.repository.ComicContent
import java.io.File

/**
 * PDF（按漫画方式逐页渲染）
 *
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

        override val chapters: List<ComicChapter> =
            if (pageCount <= 0) emptyList()
            else listOf(ComicChapter(
                index = 0,
                title = ComicChapter.SINGLE_TITLE,
                pageCount = pageCount,
                startIndex = 0,
                endIndex = pageCount - 1
            ))

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