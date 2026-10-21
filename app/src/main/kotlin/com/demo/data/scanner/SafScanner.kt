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

class SafScanner(private val context: Context, cacheRoot: File) {

    private val materialRoot = File(cacheRoot, Constants.SAF_CACHE_DIR).apply { mkdirs() }

    data class Entry(
        val uri: String,
        val name: String,
        val size: Long,
        val isDirectory: Boolean,
        val mime: String?
    ) {
        val extension: String get() = FileUtil.extension(name)
    }

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

    fun isComicFolder(children: List<Entry>): Boolean {
        if (children.isEmpty()) return false
        if (children.any { it.isDirectory }) return false
        return children.count { it.extension in Constants.IMAGE_EXTENSIONS } >= 2
    }

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

    fun listChildren(entry: Entry): List<Entry> = runCatching {
        DocumentFile.fromTreeUri(context, Uri.parse(entry.uri))?.listFiles()?.map { it.toEntry() }
    }.getOrNull().orEmpty()

    fun comicImages(children: List<Entry>): List<Entry> = children
        .filter { !it.isDirectory && it.extension in Constants.IMAGE_EXTENSIONS }
        .filter { !it.name.startsWith(".") }
        .sortedWith(compareBy(NaturalOrderComparator) { it.name })

    /** 物化单个 SAF 文件：materialRoot/{md5(uri)}/{name} —— 仅此一处 */
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

    /** 物化短篇目录：materialRoot/{md5(uri)}/{folderName}/图片 */
    fun materializeFolder(folderUri: String, folderName: String, children: List<Entry>): File? {
        val images = comicImages(children)
        if (images.isEmpty()) return null
        val parent = File(materialRoot, FileUtil.md5(folderUri))
        val safeName = FileUtil.safeFileName(folderName.ifBlank { FileUtil.md5(folderUri) })
        val dir = File(parent, safeName)
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

    /** 物化分话目录：materialRoot/{md5(uri)}/{folderName}/{话名}/图片 */
    fun materializeChaptered(folderUri: String, folderName: String, children: List<Entry>): File? {
        val chapters = chapterEntries(children)
        if (chapters.isEmpty()) return null
        val parent = File(materialRoot, FileUtil.md5(folderUri))
        val safeName = FileUtil.safeFileName(folderName.ifBlank { FileUtil.md5(folderUri) })
        val root = File(parent, safeName)
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

    fun cleanOrphans(activeUris: Set<String>) {
        val keep = activeUris.map { FileUtil.md5(it) }.toSet()
        materialRoot.listFiles()?.forEach { dir ->
            if (dir.isDirectory && dir.name !in keep) {
                runCatching { dir.deleteRecursively() }
            }
        }
    }

    companion object {
        private val CHAPTER_NAME = Regex(
            """^\s*(第\s*[0-9零一二三四五六七八九十百千万两]+\s*[话話章节節回卷篇集幕]|第\s*[0-9]+\s*[话話章节節回卷篇集幕]|[0-9]{1,4}\s*[.、\-_ ]?\s*\S.*|chapter\s*[0-9ivxlc]+.*).*$""",
            RegexOption.IGNORE_CASE
        )

        fun hasPermission(context: Context, uri: String): Boolean {
            val granted = context.contentResolver.persistedUriPermissions
            val target = runCatching { Uri.parse(uri) }.getOrNull() ?: return false
            return granted.any { it.uri == target && it.isReadPermission }
        }

        fun documentId(uri: String): String? =
            runCatching { DocumentsContract.getTreeDocumentId(Uri.parse(uri)) }.getOrNull()
    }
}