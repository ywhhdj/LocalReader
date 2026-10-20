package com.demo.data.scanner

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import androidx.documentfile.provider.DocumentFile
import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.Logger
import com.demo.core.common.util.NaturalOrderComparator
import java.io.File
import java.io.FileOutputStream

/**
 * SAF（Storage Access Framework）目录扫描支持。
 *
 * Android 11+ 在没有"所有文件访问权限"时，File API 无法遍历公共目录，
 * 只能通过 ACTION_OPEN_DOCUMENT_TREE 授权后用 DocumentFile 遍历。
 * 由于解析器（ZipFile / PdfRenderer / RandomAccessFile）需要真实文件，
 * 这里把 SAF 文档按需"物化"到内部缓存目录，再复用原有解析链路。
 */
class SafScanner(private val context: Context, cacheRoot: File) {

    private val materialRoot = File(cacheRoot, Constants.SAF_CACHE_DIR).apply { mkdirs() }

    /** 遍历结果 */
    data class Entry(
        val uri: String,
        val name: String,
        val size: Long,
        val isDirectory: Boolean,
        val mime: String?
    ) {
        val extension: String get() = FileUtil.extension(name)
    }

    /**
     * 广度优先遍历授权树。
     * @param onDirectory 返回 true 表示该目录已被整体消费（不再深入）
     */
    suspend fun walk(
        treeUri: String,
        maxDepth: Int,
        skipHidden: Boolean,
        onDirectory: suspend (Entry, List<Entry>) -> Boolean,
        onFile: suspend (Entry) -> Unit
    ) {
        val root = runCatching { DocumentFile.fromTreeUri(context, Uri.parse(treeUri)) }.getOrNull()
        if (root == null || !root.isDirectory) {
            Logger.w("SAF 树不可访问：$treeUri", "SafScanner")
            return
        }
        val queue = ArrayDeque<Pair<DocumentFile, Int>>()
        queue.add(root to 0)

        while (queue.isNotEmpty()) {
            val (dir, depth) = queue.removeFirst()
            if (skipHidden && dir.name?.startsWith(".") == true) continue
            val children = runCatching { dir.listFiles().toList() }.getOrNull().orEmpty()
            if (onDirectory(dir.toEntry(), children.map { it.toEntry() })) continue
            if (depth >= maxDepth) continue
            children.forEach { child ->
                when {
                    child.isDirectory -> queue.add(child to depth + 1)
                    child.isFile -> {
                        val entry = child.toEntry()
                        if (!skipHidden || !entry.name.startsWith(".")) onFile(entry)
                    }
                }
            }
        }
        Logger.d("SAF 遍历结束：$treeUri", "SafScanner")
    }

    private fun DocumentFile.toEntry(): Entry = Entry(
        uri = uri.toString(),
        name = name.orEmpty(),
        size = runCatching { length() }.getOrDefault(0L),
        isDirectory = isDirectory,
        mime = type
    )

    /** 目录是否为"图片文件夹漫画"（短篇：本层直接是图片） */
    fun isComicFolder(children: List<Entry>): Boolean {
        if (children.isEmpty()) return false
        if (children.any { it.isDirectory }) return false
        return children.count { it.extension in Constants.IMAGE_EXTENSIONS } >= 2
    }

    /** 分话结构：子目录名为「第一话 / 第二话」，外层目录即一本漫画 */
    fun isChapterFolder(children: List<Entry>): Boolean {
        if (children.isEmpty()) return false
        val dirs = chapterEntries(children)
        if (dirs.size < 2) return false
        val images = children.count { !it.isDirectory && it.extension in Constants.IMAGE_EXTENSIONS }
        return images == 0
    }

    private fun chapterEntries(children: List<Entry>): List<Entry> = children
        .filter { it.isDirectory && CHAPTER_NAME.matches(it.name) }
        .sortedWith(compareBy(NaturalOrderComparator) { e: Entry -> e.name })

    /** 列出子目录内容（分话结构物化时需要） */
    fun listChildren(entry: Entry): List<Entry> = runCatching {
        DocumentFile.fromTreeUri(context, Uri.parse(entry.uri))?.listFiles()?.map { it.toEntry() }
    }.getOrNull().orEmpty()

    /** 目录是否为漫画文件夹（排除隐藏文件与过小图片） */
    fun comicImages(children: List<Entry>): List<Entry> = children
        .filter { !it.isDirectory && it.extension in Constants.IMAGE_EXTENSIONS }
        .filter { !it.name.startsWith(".") }
        .sortedWith(compareBy(com.demo.core.common.util.NaturalOrderComparator) { it.name })

    /**
     * 物化单个 SAF 文档：复制到内部缓存后返回可读写的 File。
     * 已存在且大小一致时直接复用，避免重复拷贝。
     */
    fun materialize(entry: Entry): File? {
        val uri = Uri.parse(entry.uri)
        val dir = File(materialRoot, FileUtil.md5(entry.uri))
        val target = File(dir, FileUtil.safeFileName(entry.name.ifBlank { "unnamed" }))
        if (target.exists() && target.length() > 0 && entry.size > 0 && target.length() == entry.size) {
            return target
        }
        return runCatching {
            dir.mkdirs()
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { output -> input.copyTo(output) }
            } ?: return null
            target
        }.onFailure { e ->
            target.delete()
            Logger.w("物化失败：${entry.name} ${e.message}", "SafScanner")
        }.getOrNull()
    }

    /** 物化整个图片目录（漫画文件夹） */
    fun materializeFolder(folderUri: String, children: List<Entry>): File? {
        val images = comicImages(children)
        if (images.isEmpty()) return null
        val dir = File(materialRoot, FileUtil.md5(folderUri))
        if (!dir.exists() && !dir.mkdirs()) return null
        var ok = false
        images.forEach { entry ->
            val uri = Uri.parse(entry.uri)
            val target = File(dir, FileUtil.safeFileName(entry.name))
            if (target.exists() && target.length() > 0) {
                ok = true
                return@forEach
            }
            runCatching {
                context.contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(target).use { output -> input.copyTo(output) }
                }
                ok = true
            }.onFailure { target.delete() }
        }
        return if (ok) dir else null
    }

    /** 释放已失效的 SAF 缓存（目录为空则删除） */
    fun cleanOrphans(activeUris: Set<String>) {
        val keep = activeUris.map { FileUtil.md5(it) }.toSet()
        materialRoot.listFiles()?.forEach { dir ->
            if (dir.isDirectory && dir.name !in keep) {
                runCatching { dir.deleteRecursively() }
            }
        }
    }

    /**
     * 物化分话目录：外层目录名即漫画名，各话子目录保持结构，
     * 物化后由 FolderComicParser 按话自然序拼成一本。
     */
    fun materializeChaptered(folderUri: String, children: List<Entry>): File? {
        val chapters = chapterEntries(children)
        if (chapters.isEmpty()) return null
        val root = File(materialRoot, FileUtil.md5(folderUri))
        if (!root.exists() && !root.mkdirs()) return null
        var ok = false
        chapters.forEach { chapter ->
            val images = comicImages(listChildren(chapter).filter { !it.isDirectory })
            if (images.isEmpty()) return@forEach
            val dir = File(root, FileUtil.safeFileName(chapter.name))
            if (!dir.exists() && !dir.mkdirs()) return@forEach
            images.forEach { entry ->
                val target = File(dir, FileUtil.safeFileName(entry.name))
                if (target.exists() && target.length() > 0) {
                    ok = true
                    return@forEach
                }
                runCatching {
                    context.contentResolver.openInputStream(Uri.parse(entry.uri))?.use { input ->
                        FileOutputStream(target).use { output -> input.copyTo(output) }
                    }
                    ok = true
                }.onFailure { target.delete() }
            }
        }
        return if (ok) root else null
    }

    fun clearCache() = runCatching { materialRoot.deleteRecursively(); materialRoot.mkdirs() }

    fun cacheSize(): Long = FileUtil.dirSize(materialRoot)

    companion object {
        /** 话/章目录名 */
        private val CHAPTER_NAME = Regex(
            """^\s*(第\s*[0-9零一二三四五六七八九十百千万两]+\s*[话話章节節回卷篇集幕]|第\s*[0-9]+\s*[话話章节節回卷篇集幕]|[0-9]{1,4}\s*[.、\-_ ]?\s*\S.*|chapter\s*[0-9ivxlc]+.*)$""",
            RegexOption.IGNORE_CASE
        )

        /** 判断 URI 是否仍持有持久化读权限 */
        fun hasPermission(context: Context, uri: String): Boolean {
            val granted = context.contentResolver.persistedUriPermissions
            val target = runCatching { Uri.parse(uri) }.getOrNull() ?: return false
            return granted.any { it.uri == target && it.isReadPermission }
        }

        fun documentId(uri: String): String? =
            runCatching { DocumentsContract.getTreeDocumentId(Uri.parse(uri)) }.getOrNull()
    }
}
