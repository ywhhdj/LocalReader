/*
 * RarComicParser.kt
 *
 * 本文件通过 com.github.junrar:junrar 实现 RAR 归档的解压读取。
 *
 * UnRAR License Notice:
 * UnRAR source code may be used in any software to handle RAR archives
 * without limitations free of charge, but cannot be used to develop RAR
 * (WinRAR) compatible archiver and to re-create RAR compression algorithm,
 * which is proprietary. Distribution of modified UnRAR source code in
 * separate form or as a part of other software is permitted, provided that
 * full text of this paragraph, starting from "UnRAR source code" words, is
 * included in license, or in documentation if license is not available, and
 * in source code comments of resulting package.
 *
 * 本项目对 junrar 的使用严格限于解压功能，不涉及任何 RAR 压缩器开发。
 */
package com.demo.data.parser.comic

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.Logger
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

import com.github.junrar.Archive
import com.github.junrar.rarfile.FileHeader

import java.io.File

/**
 * CBR / RAR 漫画解析
 *
 *
 * 使用约束（都已在代码里处理）：
 * 1. **只支持 RAR4 及更早格式**；RAR5 是另一套格式，junrar 解不出来 ——
 *    此时条目列表为空，解析返回 null，扫描结束会提示"RAR5 请转 CBZ"；
 * 2. `Archive` **非线程安全**：所有访问串行化到同一把锁；
 * 3. `Archive#getInputStream` 每次调用都会**新建线程 + 管道流**，
 *    因此必须读到底并关闭，否则线程会一直挂着不退出；
 * 4. 包内图片按**自然序**排列（img2 < img10），避免页序错乱；
 * 5. 解压后的字节写入 [PageCache]，与 CBZ/ZIP 共用同一套缓存与内存策略。
 */
class RarComicParser(
    private val coverStore: CoverStore,
    private val pageCache: PageCache
) : ComicParser {

    override fun matches(file: File, ext: String): Boolean =
        file.isFile && (ext.equals("cbr", true) || ext.equals("rar", true))

    override suspend fun parseMeta(file: File): Book? {
        val archive = openArchive(file) ?: return null
        return try {
            val entries = imageEntries(archive)
            if (entries.isEmpty()) {
                Logger.w("RAR 内无可用图片（可能是 RAR5 或加密包）：${file.name}", TAG)
                return null
            }
            val cover = readFully(archive, entries.first())?.let { bytes ->
                coverStore.save(bytes, file.absolutePath)
            }
            Book(
                title = FileUtil.humanTitle(file.name),
                type = BookType.COMIC,
                format = if (file.extension.equals("cbr", true)) BookFormat.CBR else BookFormat.RAR,
                filePath = file.absolutePath,
                coverPath = cover,
                sizeBytes = file.length(),
                pageCount = entries.size,
                metaJson = entries.joinToString("\u0001") { it.entryName() }
            )
        } finally {
            closeQuietly(archive)
        }
    }

    override suspend fun listPages(file: File, book: Book): List<ComicPage> {
        val names = book.metaJson?.split("\u0001")?.filter { it.isNotBlank() }.orEmpty()
        if (names.isNotEmpty()) {
            return names.mapIndexed { i, n -> ComicPage(i, entryName = n) }
        }
        val archive = openArchive(file) ?: return emptyList()
        return try {
            imageEntries(archive).mapIndexed { i, h -> ComicPage(i, entryName = h.entryName()) }
        } finally {
            closeQuietly(archive)
        }
    }

    override suspend fun openComic(file: File, book: Book): ComicContent {
        val pages = listPages(file, book)
        return RarComicContent(file, book.id, pages, pageCache)
    }

    // ---------- 共用工具 ----------

    /** 打开 RAR；RAR5 / 损坏 / 加密包返回 null，不抛异常 */
    private fun openArchive(file: File): Archive? = runCatching { Archive(file) }
        .onFailure { Logger.w("RAR 打开失败（多为 RAR5 / 加密 / 损坏）：${file.name} ${it.message}", TAG) }
        .getOrNull()

    /** 包内图片条目（自然序）；RAR 内部路径分隔符是 `\`，统一换成 `/` */
    private fun imageEntries(archive: Archive): List<FileHeader> = runCatching {
        val all = archive.fileHeaders
            .asSequence()
            .filter { !it.isDirectory }
            .filter { FileUtil.extension(it.entryName()).lowercase() in Constants.IMAGE_EXTENSIONS }
            .filter { !it.entryName().contains("__MACOSX") && !it.entryName().endsWith(".DS_Store") }
            .filter { !it.entryName().substringAfterLast('/').startsWith(".") }
            .sortedWith(compareBy(NaturalOrderComparator) { it.entryName() })
            .toList()
        // 过小的图片（封面 logo / 占位图）过滤掉；过滤后为空则回退，避免整本变 0 页
        val filtered = all.filter { it.fullUnpackSize > Constants.MIN_IMAGE_SIZE }
        filtered.ifEmpty { all }
    }.getOrDefault(emptyList())

    /** 完整读出一条目并关闭底层流（getInputStream 会起线程 + 管道） */
    private fun readFully(archive: Archive, header: FileHeader): ByteArray? = runCatching {
        archive.getInputStream(header).use { it.readBytes() }
    }.onFailure { Logger.w("RAR 条目读取失败：${header.entryName()} ${it.message}", TAG) }
        .getOrNull()

    private fun closeQuietly(archive: Archive) = runCatching { archive.close() }

    private class RarComicContent(
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
                pageCount = pages.size,
                startIndex = 0,
                endIndex = pages.lastIndex
            ))

        @Volatile
        private var archive: Archive? = null
        private val lock = Any()

        /** Archive 非线程安全：打开与读取都串行化 */
        private fun archive(): Archive = archive ?: synchronized(lock) {
            archive ?: Archive(file).also { archive = it }
        }

        override suspend fun resolvePage(index: Int): String? {
            val page = pages.getOrNull(index) ?: return null
            pageCache.cached(bookId, index)?.let { return it }
            val name = page.entryName ?: return null
            return runCatching {
                val bytes = synchronized(lock) {
                    val target = archive().fileHeaders
                        .firstOrNull { !it.isDirectory && it.entryName() == name }
                    if (target == null) null
                    else archive().getInputStream(target).use { it.readBytes() }
                } ?: return null
                pageCache.putBytes(bookId, index, bytes)
            }.getOrNull()
        }

        override fun close() {
            synchronized(lock) {
                runCatching { archive?.close() }
                archive = null
            }
        }
    }

    private companion object {
        const val TAG = "RarComicParser"
    }
}

/** 条目名：统一路径分隔符（RAR 用 '\'） */
private fun FileHeader.entryName(): String = runCatching { fileName }
    .getOrNull()
    ?.replace('\\', '/')
    ?: ""
