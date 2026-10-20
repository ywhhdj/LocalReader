package com.demo.data.parser

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.NaturalOrderComparator
import java.io.File

/**
 * 图片文件夹漫画的目录结构判定（短篇 / 分话）。
 *
 * 两种形态都归为"一本漫画"：
 * 1. 短篇：目录下直接就是全部图片（没有话目录）→ 整本算 **1 话**；
 * 2. 分话：目录下是「第一话」「第二话」…… 这类子目录，图片在各话目录里。
 *    此时**外层目录名即漫画名**，各话按自然序排列。
 *
 * 判定顺序：先查话目录（≥2 个话目录即分话），否则只要本层有图片就按短篇处理。
 */
object ComicFolder {

    /** 话/章目录名：第X话、第X章、第X回、纯数字、Chapter N */
    private val CHAPTER_NAME = Regex(
        """^\s*(第\s*[0-9零一二三四五六七八九十百千万两]+\s*[话話章节節回卷篇集幕]|""" +
            """第\s*[0-9]+\s*[话話章节節回卷篇集幕]|""" +
            """[0-9]{1,4}\s*[.、\-_ ]?\s*\S.*|""" +
            """chapter\s*[0-9ivxlc]+.*)$""",
        RegexOption.IGNORE_CASE
    )

    private val imageComparator = compareBy(NaturalOrderComparator) { f: File -> f.name }
    private val dirComparator = compareBy(NaturalOrderComparator) { f: File -> f.name }

    /** 目录中的一话：话名 + 该话页面文件（自然序） */
    data class FolderChapter(
        val title: String,
        val files: List<File>
    )

    fun isImage(file: File): Boolean =
        file.isFile && !file.name.startsWith(".") &&
            FileUtil.extension(file.name) in Constants.IMAGE_EXTENSIONS

    /** 目录下的直接图片（自然序，过滤过小文件；过滤后为空则回退） */
    fun imagesIn(dir: File): List<File> {
        val all = dir.listFiles()?.filter { isImage(it) } ?: emptyList()
        val filtered = all.filter { it.length() > Constants.MIN_IMAGE_SIZE }.sortedWith(imageComparator)
        val fallback = all.sortedWith(imageComparator)
        return filtered.ifEmpty { fallback }
    }

    /** 话目录：名字像话/章的子目录，且内部有图片 */
    fun chapterDirs(dir: File): List<File> {
        val subDirs = dir.listFiles()
            ?.filter { it.isDirectory && !it.name.startsWith(".") && !FileUtil.isHidden(it) }
            ?.filter { !FileUtil.hasNoMedia(it) }
            ?: emptyList()
        return subDirs
            .filter { CHAPTER_NAME.matches(it.name) && imagesIn(it).isNotEmpty() }
            .sortedWith(dirComparator)
    }

    /** 分话结构：≥2 个话目录，且本层没有与话目录数量相当的图片 */
    fun isChaptered(dir: File): Boolean {
        if (!dir.isDirectory) return false
        val chapters = chapterDirs(dir)
        if (chapters.size < 2) return false
        val total = chapters.sumOf { imagesIn(it).size }
        if (total < 2) return false
        // 本层若同时存在图片，说明是"短篇 + 额外目录"，以图片数量多的一方为准
        return imagesIn(dir).isEmpty() || total > imagesIn(dir).size
    }

    /**
     * 短篇：本层有图片，且不是"容器目录"。
     * 注意：不再内部调用 isChaptered（调用方已优先判定分话），避免重复列举子目录。
     */
    fun isFlat(dir: File): Boolean {
        if (!dir.isDirectory) return false
        val images = imagesIn(dir)
        if (images.isEmpty()) return false
        val subDirs = dir.listFiles()
            ?.count { it.isDirectory && !it.name.startsWith(".") && !FileUtil.isHidden(it) }
            ?: 0
        // 没有子目录 → 整本就是这一层；有子目录但图片占绝对多数 → 仍按短篇
        return subDirs == 0 || (images.size >= 2 && images.size >= subDirs * 2)
    }

    /** 是否可作为一本漫画导入（先判分话，避免重复遍历子目录） */
    fun isComicFolder(dir: File): Boolean {
        if (!dir.isDirectory) return false
        if (isChaptered(dir)) return true
        return isFlat(dir)
    }

    /**
     * 话结构：
     * - 分话 → 每个话目录一话，话名为目录名；
     * - 短篇 → 单话「第 1 话」，页面为本层全部图片。
     * 话名去掉结尾的标点（如「第一话,」「第二话.」），保证 UI 显示整洁。
     */
    fun chaptersOf(dir: File): List<FolderChapter> {
        if (isChaptered(dir)) {
            return chapterDirs(dir).map { FolderChapter(cleanChapterName(it.name), imagesIn(it)) }
        }
        val images = imagesIn(dir)
        if (images.isEmpty()) return emptyList()
        return listOf(FolderChapter(SINGLE_CHAPTER_TITLE, images))
    }

    /** 页面文件列表：按话顺序拼接（短篇即本层图片） */
    fun pagesOf(dir: File): List<File> = chaptersOf(dir).flatMap { it.files }

    /** 去掉话名首尾的标点与空白：第一话, → 第一话 */
    fun cleanChapterName(raw: String): String {
        val trimmed = raw.trim()
            .trim('，', ',', '。', '.', '、', '；', ';', '：', ':', '！', '!', '？', '?',
                '“', '”', '\'', '（', '）', '(', ')', '[', ']', '【', '】', '「', '」'
            )
            .trim()
        return trimmed.ifBlank { raw.trim() }
    }

    const val SINGLE_CHAPTER_TITLE = com.demo.core.model.ComicChapter.SINGLE_TITLE
}
