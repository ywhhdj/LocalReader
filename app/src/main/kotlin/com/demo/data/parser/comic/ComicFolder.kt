package com.demo.data.parser.comic

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.NaturalOrderComparator
import com.demo.core.model.ComicChapter

import java.io.File

/**
 * 图片文件夹漫画的目录结构判定（短篇 / 分话）。
 *
 * 两种形态都归为"一本漫画"：
 * 1. 短篇：目录下直接就是全部图片（没有话目录）→ 整本算 **1 话**；
 * 2. 分话：目录下是「第一话」「第二话」…… 这类子目录，图片在各话目录里。
 *    此时**外层目录名即漫画名**，各话按自然序排列。
 *
 * 判定要点
 * - 话目录里的图片允许再套一层（「第1话/images/001.jpg」很常见），这里向下多看一层；
 * - 单个话目录也算分话结构（只要图片主要都在话目录里），
 *   旧实现要求 ≥2 个话目录，导致「漫画名/第1话/…」这类目录整本被漏掉，只能导入成名为"第1话"的书；
 * - 混放目录（本层有图 + 有话目录）按图片数量多的一方判定归属。
 */
object ComicFolder {

    /** 话/章目录名：第X话、第X章、第X回、纯数字、Chapter N */
    private val CHAPTER_NAME = Regex(
        """^\s*([第]?\s*[0-9零一二三四五六七八九十百千万两]+\s*[话話章节節回卷篇集幕]|""" +
            """[第]?\s*[0-9]+\s*[话話章节節回卷篇集幕]|""" +
            """[0-9]{1,4}\s*[.、\-_ ]?\s*\S.*|""" +
            """chapter\s*[0-9ivxlc]+.*).*$""",
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

    /** 一次 listFiles 的结果快照：图片 + 可见子目录 */
    private class Snapshot(val images: List<File>, val dirs: List<File>)

    private fun snapshot(dir: File): Snapshot {
        val all = dir.listFiles()
        if (all.isNullOrEmpty()) return Snapshot(emptyList(), emptyList())
        val images = ArrayList<File>(all.size)
        val dirs = ArrayList<File>()
        for (f in all) {
            when {
                f.isDirectory -> {
                    if (!f.name.startsWith(".") && !FileUtil.isHidden(f) && !FileUtil.hasNoMedia(f)) {
                        dirs.add(f)
                    }
                }
                isImage(f) -> images.add(f)
            }
        }
        images.sortWith(imageComparator)
        dirs.sortWith(dirComparator)
        return Snapshot(filterTiny(images), dirs)
    }

    /** 过小的图片（封面 logo / 占位图）过滤掉；过滤后为空则回退，避免整本变 0 页 */
    private fun filterTiny(list: List<File>): List<File> {
        val filtered = ArrayList<File>(list.size)
        for (f in list) if (f.length() > Constants.MIN_IMAGE_SIZE) filtered.add(f)
        return filtered.ifEmpty { list }
    }

    /** 目录下的直接图片（自然序，过滤过小文件；过滤后为空则回退） */
    fun imagesIn(dir: File): List<File> = snapshot(dir).images

    /**
     * 话目录内图片：优先本层，本层没有图片时再看一层子目录。
     * （「第1话/images/001.jpg」这类结构很常见，旧实现会把它判成空话目录从而整本跳过）
     */
    fun imagesInDeep(dir: File, depth: Int = 1): List<File> {
        val direct = imagesIn(dir)
        if (direct.isNotEmpty() || depth <= 0) return direct
        val nested = dir.listFiles()
            ?.filter { it.isDirectory && !it.name.startsWith(".") && !FileUtil.isHidden(it) }
            ?: return emptyList()
        var best: List<File> = emptyList()
        for (child in nested) {
            val found = imagesInDeep(child, depth - 1)
            if (found.size > best.size) best = found
            if (best.size >= 2) break
        }
        return best
    }

    /** 话目录：名字像话/章的子目录，且内部（含一层嵌套）有图片 */
    fun chapterDirs(dir: File): List<File> {
        val snap = snapshot(dir)
        if (snap.dirs.isEmpty()) return emptyList()
        return snap.dirs
            .filter { CHAPTER_NAME.matches(it.name) && imagesInDeep(it).isNotEmpty() }
    }

    /**
     * 是否可作为一本漫画导入。
     *
     * 判定顺序：先看话目录（够数即停，不枚举全部话内容），再退回本层图片。
     */
    fun isComicFolder(dir: File): Boolean {
        if (!dir.isDirectory) return false
        val snap = snapshot(dir)
        if (snap.images.isEmpty() && snap.dirs.isEmpty()) return false

        val chapters = snap.dirs.filter { CHAPTER_NAME.matches(it.name) }
        if (chapters.isNotEmpty()) {
            // 够数即停：话内图片一旦超过本层图片数，就足以判定为分话结构
            var inChapters = 0
            for (chapter in chapters) {
                inChapters += imagesInDeep(chapter).size
                if (inChapters > snap.images.size && inChapters > 0) return true
            }
            if (inChapters > 0 && snap.images.isEmpty()) return true
        }
        // 短篇：本层有图片，且话目录不是主体（没有话目录，或图片数量占优）
        if (snap.images.isEmpty()) return false
        return chapters.isEmpty() || snap.images.size >= maxOf(2, chapters.size * 2)
    }

    /**
     * 话结构：
     * - 分话 → 每个话目录一话，话名为目录名；
     * - 短篇 → 单话「第 1 话」，页面为本层全部图片。
     * 话名去掉结尾的标点（如「第一话,」「第二话.」），保证 UI 显示整洁。
     */
    fun chaptersOf(dir: File): List<FolderChapter> {
        val snap = snapshot(dir)
        if (snap.images.isEmpty() && snap.dirs.isEmpty()) return emptyList()
        val chapters = snap.dirs.filter { CHAPTER_NAME.matches(it.name) }

        // 分话：话目录里确实有图，且图片主要不在本层
        if (chapters.isNotEmpty()) {
            val inChapters = chapters.map { imagesInDeep(it) }.filter { it.isNotEmpty() }
            val total = inChapters.sumOf { it.size }
            if (total > 0 && (snap.images.isEmpty() || total > snap.images.size)) {
                return inChapters.mapIndexed { index, files ->
                    val dirName = chapters[index].name
                    FolderChapter(cleanChapterName(dirName), files)
                }
            }
        }
        if (snap.images.isEmpty()) return emptyList()
        return listOf(FolderChapter(SINGLE_CHAPTER_TITLE, snap.images))
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

    const val SINGLE_CHAPTER_TITLE = ComicChapter.SINGLE_TITLE
}