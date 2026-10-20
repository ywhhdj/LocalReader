package com.demo.data.scanner

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.Logger
import com.demo.data.mapper.toEntity
import com.demo.data.parser.ParserFactory
import com.demo.data.parser.ParserFactoryImpl
import com.demo.domain.repository.ScanOptions
import com.demo.domain.repository.ScanProgress
import com.demo.domain.repository.ScannerRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.coroutines.coroutineContext

/**
 * 本地文件扫描与导入：
 * - BFS 遍历，深度/数量/大小上限
 * - 按 file_path 去重（已存在则跳过）
 * - 每 200 条一个事务批量入库，避免长时间占用 DB
 * - 以 Flow 回传进度，收集取消即中断
 */
class FileScanner(
    private val parserFactory: ParserFactory,
    private val bookDao: com.demo.core.database.dao.BookDao
) : ScannerRepository {

    override fun scan(paths: List<String>, options: ScanOptions): Flow<ScanProgress> = flow {
        var scanned = 0
        var imported = 0
        var skipped = 0
        var failed = 0
        val pending = ArrayList<com.demo.core.model.Book>(200)

        suspend fun flush() {
            if (pending.isEmpty()) return
            withContext(Dispatchers.IO) {
                bookDao.insertAll(pending.map { it.toEntity(0L) })
            }
            pending.clear()
            delay(10) // 让出线程，避免扫描时 UI 卡顿
        }

        for (path in paths) {
            val root = File(path)
            if (!root.exists()) {
                failed++
                continue
            }
            val queue = ArrayDeque<Pair<File, Int>>()
            queue.add(root to 0)
            val visited = HashSet<String>()

            while (queue.isNotEmpty() && coroutineContext.isActive) {
                val (current, depth) = queue.removeFirst()
                if (!current.exists() || !visited.add(current.absolutePath)) continue
                if (options.skipHidden && FileUtil.isHidden(current)) continue

                if (current.isDirectory) {
                    if (FileUtil.hasNoMedia(current)) continue
                    val children = current.listFiles()
                    // 图片文件夹整体作为一本漫画导入
                    if (depth > 0 && isComicFolder(children)) {
                        scanned++
                        handleCandidate(current, "", pending,
                            onImported = { imported++ },
                            onSkipped = { skipped++ },
                            onFailed = { failed++ },
                            flush = { flush() })
                        continue
                    }
                    if (depth >= options.maxDepth) continue
                    children?.forEach { queue.add(it to depth + 1) }
                    continue
                }

                scanned++
                if (scanned > options.maxFiles) break
                if (current.length() > options.maxFileSize) {
                    skipped++
                    continue
                }

                val ext = ParserFactoryImpl.extOf(current)
                if (ext.isNotEmpty() && !isSupported(ext)) {
                    skipped++
                    continue
                }
                handleCandidate(current, ext, pending,
                    onImported = { imported++ },
                    onSkipped = { skipped++ },
                    onFailed = { failed++ },
                    flush = { flush() })

                if (scanned % 20 == 0) {
                    emit(
                        ScanProgress(
                            scanned = scanned, imported = imported, skipped = skipped,
                            failed = failed, current = current.name, done = false
                        )
                    )
                }
            }
            if (!coroutineContext.isActive) break
        }
        flush()
        emit(
            ScanProgress(
                scanned = scanned, imported = imported, skipped = skipped,
                failed = failed, current = "", done = true
            )
        )
    }.flowOn(Dispatchers.IO)

    private fun isComicFolder(children: Array<File>?): Boolean {
        if (children.isNullOrEmpty()) return false
        if (children.any { it.isDirectory }) return false
        val images = children.count {
            it.isFile && (FileUtil.extension(it.name) in Constants.IMAGE_EXTENSIONS)
        }
        return images >= 2
    }

    private suspend fun handleCandidate(
        file: File,
        ext: String,
        pending: MutableList<com.demo.core.model.Book>,
        onImported: () -> Unit,
        onSkipped: () -> Unit,
        onFailed: () -> Unit,
        flush: suspend () -> Unit
    ) {
        val parser = parserFactory.anyParser(file, ext)
        if (parser == null) {
            if (ext.isNotEmpty()) onSkipped()
            return
        }
        runCatching {
            val exists = withContext(Dispatchers.IO) { bookDao.byPath(file.absolutePath) }
            if (exists != null) {
                onSkipped()
                return@runCatching
            }
            val book = parser.parseMeta(file)
            if (book == null) {
                onFailed()
                return@runCatching
            }
            pending.add(book)
            onImported()
            if (pending.size >= 200) flush()
        }.onFailure { e ->
            onFailed()
            Logger.w("扫描失败：${file.absolutePath} ${e.message}", "FileScanner")
        }
    }

    private fun isSupported(ext: String): Boolean =
        ext.equals("epub", true) || ext.equals("txt", true) || ext.equals("text", true) ||
            ext.equals("pdf", true) || ext.equals("cbz", true) || ext.equals("zip", true) ||
            ext.equals("cbr", true) || ext.equals("rar", true)

    companion object {
        val SUPPORTED_EXTENSIONS = setOf("epub", "txt", "text", "pdf", "cbz", "zip", "cbr", "rar")
        const val MAX_FILE_SIZE = Constants.MAX_FILE_SIZE
    }
}
