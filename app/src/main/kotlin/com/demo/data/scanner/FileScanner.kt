package com.demo.data.scanner

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.Logger
import com.demo.core.database.dao.BookDao
import com.demo.core.model.Book
import com.demo.data.mapper.toEntity
import com.demo.data.parser.comic.ComicFolder
import com.demo.data.parser.ParserFactory
import com.demo.data.parser.ParserFactoryImpl
import com.demo.domain.repository.ScanOptions
import com.demo.domain.repository.ScanProgress
import com.demo.domain.repository.ScanTarget
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
 * 本地文件 / SAF 授权目录扫描与导入：
 * - 支持 [ScanTarget.Path]（需要存储权限）与 [ScanTarget.Tree]（SAF 授权，Android 11+ 主路径）
 * - BFS 遍历，深度/数量/大小上限；连续图片目录整体作为一本漫画导入（含根目录本身）
 * - 按 file_path 去重：已存在则跳过，mtime/size 变化时刷新元数据
 * - 每 200 条一个事务批量入库，按时间节流回传进度
 * - 取消 Flow 收集即中断
 */
class FileScanner(
  private val parserFactory: ParserFactory,
  private val bookDao: BookDao,
  private val safScanner: SafScanner
) : ScannerRepository {

  private class Counters {
    var scanned = 0
    var imported = 0
    var updated = 0
    var skipped = 0
    var failed = 0
    var unsupported = 0
  }

  override fun scan(targets: List<ScanTarget>, options: ScanOptions): Flow<ScanProgress> = flow {
    val c = Counters()
    val pending = ArrayList<Book>(200)
    // 已入库路径一次性载入内存：避免每个文件都查一次库（5000 文件的目录可省 5000 次查询）
    val knownPaths = HashSet(withContext(Dispatchers.IO) { bookDao.allPaths() })
    // 用 lambda 捕获 FlowCollector#emit，避免局部函数无法访问 receiver
    val post: suspend (ScanProgress) -> Unit = { emit(it) }
    var visited = 0
    var stopped = false
    var lastEmit = 0L

    suspend fun flush() {
      if (pending.isEmpty()) return
      withContext(Dispatchers.IO) {
          bookDao.insertAll(pending.map { it.toEntity(0L) })
      }
      pending.clear()
    }

    suspend fun tick(current: String, force: Boolean = false) {
      val now = System.currentTimeMillis()
      if (!force && now - lastEmit < 200L) return
      lastEmit = now
      post(
        ScanProgress(
          scanned = c.scanned,
          imported = c.imported + c.updated,
          skipped = c.skipped,
          failed = c.failed,
          current = current,
          done = false,
          message = if (c.unsupported > 0) RAR_HINT else null
        )
      )
    }

    suspend fun handle(file: File, ext: String, sourceUri: String?) {
        val parser = parserFactory.anyParser(file, ext)
        if (parser == null) {
          if (ext.isNotEmpty()) c.skipped++
          return
        }
        c.scanned++
        runCatching {
        val path = file.absolutePath
        if (knownPaths.contains(path)) {
          if (!options.refreshExisting) {
            c.skipped++
            return@runCatching
          }
          // 仅在需要刷新时才回查该条记录（大部分场景不会走到这里）
          val exists = withContext(Dispatchers.IO) { bookDao.byPath(path) }
          val changed = exists != null &&
              (exists.size_bytes != file.length() || exists.title.isBlank())
          if (!changed) {
            c.skipped++
            return@runCatching
          }
          val refreshed = parser.parseMeta(file)
          if (refreshed == null || exists == null) {
            c.failed++
            return@runCatching
          }
          withContext(Dispatchers.IO) {
            bookDao.upsert(
              refreshed.copy(sourceUri = sourceUri ?: exists.source_uri).toEntity(exists.id)
            )
          }
          c.updated++
          return@runCatching
        }
        val book = parser.parseMeta(file)
        if (book == null) {
          c.failed++
          return@runCatching
        }
        knownPaths.add(path)
        pending.add(if (sourceUri != null) book.copy(sourceUri = sourceUri) else book)
        c.imported++
        if (pending.size >= 200) flush()
      }.onFailure { e ->
        c.failed++
        Logger.w("扫描失败：${file.absolutePath} ${e.message}", "FileScanner")
      }
    }

    suspend fun consumeFile(file: File, sourceUri: String?) {
      val ext = FileUtil.extension(file.name)
      when {
        ext in RAR_EXTENSIONS -> {
          c.unsupported++
          c.skipped++
        }
        ext.isNotEmpty() && !isSupported(ext) -> c.skipped++
        file.length() > options.maxFileSize -> c.skipped++
        else -> {
          handle(file, ext, sourceUri)
          tick(file.name)
        }
      }
    }

    // ---------- 本地路径 ----------
    suspend fun walkPath(path: String) {
      val root = File(path)
      if (!root.exists()) {
        c.failed++
        return
      }
      if (root.isFile) {
        consumeFile(root, null)
        return
      }
      // 根目录本身可能就是一个漫画图片文件夹
      if (options.folderAsComic && isComicFolder(root)) {
          handle(root, "", null)
          tick(root.name)
          return
      }

      val queue = ArrayDeque<Pair<File, Int>>()
      queue.add(root to 0)
      val seen = HashSet<String>()
      while (queue.isNotEmpty() && coroutineContext.isActive && !stopped) {
        val (current, depth) = queue.removeFirst()
        if (!current.exists() || !seen.add(current.absolutePath)) continue
        visited++
        if (visited > options.maxFiles) {
          stopped = true
          break
        }
        if (options.skipHidden && FileUtil.isHidden(current)) continue

        if (current.isDirectory) {
          if (FileUtil.hasNoMedia(current) || isBlockedDir(current)) continue
          if (options.folderAsComic && isComicFolder(current)) {
            handle(current, "", null)
            tick(current.name)
            continue
          }
          if (depth >= options.maxDepth) continue
          val children = current.listFiles()
          if (children.isNullOrEmpty()) continue
          children.forEach { queue.add(it to depth + 1) }
          continue
        }
        consumeFile(current, null)
      }
    }

    // ---------- SAF 树 ----------
    suspend fun walkTree(uri: String) {
      safScanner.walk(
        treeUri = uri,
        maxDepth = options.maxDepth,
        skipHidden = options.skipHidden,
        onDirectory = { dir, children ->
          if (!coroutineContext.isActive || stopped) {
            true
          } else if (options.folderAsComic && safScanner.isChapterFolder(children)) {
            // 分话：外层目录名即漫画名，各话子目录整体保留
            val local = safScanner.materializeChaptered(dir.uri, dir.name, children)
            if (local != null) {
              handle(local, "", dir.uri)
              tick(dir.name)
              true
            } else {
              false
            }
          } else if (options.folderAsComic && safScanner.isComicFolder(children)) {
            // 短篇：本层图片即整本（1 话）
            val local = safScanner.materializeFolder(dir.uri, dir.name, children)
            if (local != null) {
                handle(local, "", dir.uri)
                tick(dir.name)
                true
            } else {
                false
            }
          } else {
            false
          }
        },
        onFile = { entry ->
            if (coroutineContext.isActive && !stopped) {
              if (visited++ > options.maxFiles) {
                stopped = true
              } else if (entry.extension.isEmpty() || !isSupported(entry.extension)) {
                if (entry.extension in RAR_EXTENSIONS) c.unsupported++
                c.skipped++
              } else if (entry.size > options.maxFileSize) {
                c.skipped++
              } else {
                val local = safScanner.materialize(entry)
                if (local == null) {
                  c.failed++
                } else {
                  handle(local, entry.extension, entry.uri)
                  tick(entry.name)
                }
              }
            }
        }
      )
    }

    for (target in targets) {
      if (stopped || !coroutineContext.isActive) break
      when (target) {
        is ScanTarget.Path -> walkPath(target.path)
        is ScanTarget.Tree -> walkTree(target.uri)
      }
    }

    flush()
    delay(10)
    post(
      ScanProgress(
        scanned = c.scanned,
        imported = c.imported + c.updated,
        skipped = c.skipped,
        failed = c.failed,
        current = "",
        done = true,
        message = buildMessage(c)
      )
    )
  }.flowOn(Dispatchers.IO)

  /**
    * 图片文件夹漫画判定：
    * - 短篇：目录下全是图片；
    * - 分话：目录下是「第一话 / 第二话」这类子目录，外层目录名即漫画名。
    */
  private fun isComicFolder(dir: File): Boolean = ComicFolder.isComicFolder(dir)

  /** 受限/系统目录黑名单：遍历必然失败或极慢 */
  private fun isBlockedDir(dir: File): Boolean {
    val p = dir.absolutePath
    return BLOCKED_PREFIXES.any { p == it || p.startsWith("$it/") }
  }

  private fun buildMessage(c: Counters): String {
    val parts = ArrayList<String>()
    parts.add("新增 ${c.imported}" + if (c.updated > 0) " · 更新 ${c.updated}" else "")
    if (c.skipped > 0) parts.add("跳过 ${c.skipped}")
    if (c.failed > 0) parts.add("失败 ${c.failed}")
    if (c.unsupported > 0) parts.add(RAR_HINT)
    return parts.joinToString(" · ")
  }

  companion object {
    const val RAR_HINT = "RAR/CBR 暂不支持，请转为 CBZ/ZIP"
    val RAR_EXTENSIONS = setOf("rar", "cbr")

    val SUPPORTED_EXTENSIONS = setOf(
      "epub", "txt", "text", "pdf", "cbz", "zip", "cbr", "rar"
    )

    private val BLOCKED_PREFIXES = listOf(
      "/proc", "/sys", "/dev",
      "/storage/emulated/0/Android/data",
      "/storage/emulated/0/Android/obb",
      "/storage/emulated/0/Android/sandbox"
    )

    fun isSupported(ext: String): Boolean = ext in SUPPORTED_EXTENSIONS

    fun extOf(file: File): String = ParserFactoryImpl.extOf(file)
  }
}
