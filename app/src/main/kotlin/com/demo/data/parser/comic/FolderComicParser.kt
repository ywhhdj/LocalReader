package com.demo.data.parser.comic

import com.demo.core.common.util.FileUtil
import com.demo.core.model.Book
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.core.model.ComicChapter
import com.demo.core.model.ComicPage
import com.demo.data.cover.CoverStore
import com.demo.data.parser.ComicParser
import com.demo.domain.repository.ComicContent
import java.io.File
import java.io.FileInputStream

/**
 * 图片文件夹漫画（短篇 1 话 / 分话多话）
 *
 * - 分话：外层目录名即漫画名，其下「第一话 / 第二话」子目录各为一话；
 * - 短篇：目录下直接是全部图片，整本算 1 话；
 * - 页与话结构在打开时按目录现场重建（目录移动/改名也能读到），metaJson 仅作兜底。
 */
class FolderComicParser(
    private val coverStore: CoverStore
) : ComicParser {

    override fun matches(file: File, ext: String): Boolean =
        file.isDirectory && ComicFolder.isComicFolder(file)

    override suspend fun parseMeta(file: File): Book? = runCatching {
        val chapters = ComicFolder.chaptersOf(file)
        val images = chapters.flatMap { it.files }
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
            metaJson = FolderMetaCodec.encode(
                buildChapters(chapters, images.size),
                images.map { it.absolutePath }
            )
        )
    }.getOrNull()

    /** 页列表：现场扫描优先（保证话区间一致），失败回退 metaJson 中的旧路径 */
    override suspend fun listPages(file: File, book: Book): List<ComicPage> {
        val structure = runCatching { ComicFolder.chaptersOf(file) }.getOrDefault(emptyList())
        if (structure.isNotEmpty()) {
            val paths = ArrayList<String>(structure.sumOf { it.files.size })
            structure.forEach { chapter -> chapter.files.forEach { paths.add(it.absolutePath) } }
            return paths.mapIndexed { i, p -> ComicPage(i, filePath = p) }
        }
        val (_, legacy) = FolderMetaCodec.decode(book.metaJson)
        return legacy.filter { File(it).exists() }.mapIndexed { i, p -> ComicPage(i, filePath = p) }
    }

    override suspend fun openComic(file: File, book: Book): ComicContent {
        val pages = listPages(file, book)
        val chapters = runCatching { buildChapters(ComicFolder.chaptersOf(file), pages.size) }
            .getOrDefault(emptyList())
            .ifEmpty { FolderMetaCodec.decode(book.metaJson).first }
            .ifEmpty { singleChapter(pages.size) }
        return FolderComicContent(book.id, pages, chapters)
    }

    private fun buildChapters(
        chapters: List<ComicFolder.FolderChapter>?,
        total: Int
    ): List<ComicChapter> {
        val list = chapters.orEmpty()
        if (list.isEmpty()) return emptyList()
        val result = ArrayList<ComicChapter>(list.size)
        var cursor = 0
        list.forEachIndexed { index, chapter ->
            val start = cursor
            val end = (cursor + chapter.files.size - 1).coerceAtMost(total - 1)
            if (end >= start) result.add(ComicChapter(
                index = index,
                title = chapter.title,
                startIndex = start,
                endIndex = end
            ))
            cursor = end + 1
        }
        return result
    }

    private fun singleChapter(total: Int): List<ComicChapter> =
        if (total <= 0) emptyList() else listOf(ComicChapter(
            index = 0,
            title = ComicChapter.SINGLE_TITLE,
            startIndex = 0,
            endIndex = total - 1
        ))

    private class FolderComicContent(
        private val bookId: Long,
        override val pages: List<ComicPage>,
        override val chapters: List<ComicChapter>
    ) : ComicContent {
        /**
         * 本地图片直接交图片加载器按屏采样：不再"读整份字节 → 解码 → 重编码 WebP"，
         * 省掉一次全尺寸解码与写盘（文件夹漫画的首屏与翻页开销大幅下降）。
         */
        override suspend fun resolvePage(index: Int): String? {
            val path = pages.getOrNull(index)?.filePath ?: return null
            return if (File(path).exists()) path else null
        }

        override fun close() = Unit
    }
}