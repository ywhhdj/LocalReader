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
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
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

    /** 按已入库书籍的 SAF URI 回收孤儿物化目录 */
    suspend fun reclaimSafCache() {
      val active = withContext(Dispatchers.IO) {
        runCatching { 
          bookDao.allSourceUris()
        }.getOrDefault(emptyList())
      }.filter { it.isNotBlank() }.toSet()
      safScanner.cleanOrphans(active)
    }

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

    /** 待解析条目（攒够一批后并发解析） */
    class Candidate(
      val file: File,
      val ext: String,
      val sourceUri: String?
    ) {
      /** 是否成功入库：决定"图片文件夹被判为漫画后是否继续下钻" */
      @Volatile
      var ok: Boolean = false
    }

    val batch = ArrayList<Candidate>(PARSE_BATCH)

      /**
     * 把解析结果落库（串行）。
     *
     * 返回值语义与旧 handle() 一致：用于调用方决定"是否继续下钻"——
     * 图片文件夹被判为漫画但解析失败（图片不可读 / 权限受限）时不再跳过整个目录。
     */
    suspend fun consumeParsed(cand: Candidate, book: Book?): Boolean {
        val file = cand.file
        val ext = cand.ext
        var ok = false
        runCatching {
            val path = file.absolutePath
            val isFolderBook = file.isDirectory
            if (knownPaths.contains(path)) {
                // 走到这里说明开启了 refreshExisting
                val exists = withContext(Dispatchers.IO) { bookDao.byPath(path) }
                if (exists == null) {
                    c.failed++
                    return@runCatching
                }
                // 作者缺失（老版本 EPUB 解析漏掉作者）也算"需要刷新"，
                // 否则这些书永远不会自动补上作者。
                val authorMissing = exists.author.isNullOrBlank() ||
                    exists.author == "未知" || exists.author == "未知作者"
                // 图片文件夹：File#length() 对目录没有意义，只在元数据缺失时刷新
                val changed = if (isFolderBook) {
                    exists.title.isBlank() || authorMissing
                } else {
                    exists.size_bytes != file.length() || exists.title.isBlank() || authorMissing
                }
                if (!changed) {
                    c.skipped++
                    return@runCatching
                }
                if (book == null) {
                    c.failed++
                    return@runCatching
                }
                withContext(Dispatchers.IO) {
                    bookDao.upsert(
                        book.copy(sourceUri = cand.sourceUri ?: exists.source_uri).toEntity(exists.id)
                    )
                }
                c.updated++
                ok = true
                return@runCatching
            }
            if (book == null) {
                // RAR5 / 加密包 junrar 解不出来：单独计数，结束时给出"请转 CBZ"的提示
                if (ext in RAR_EXTENSIONS) c.unsupported++
                c.failed++
                return@runCatching
            }
            knownPaths.add(path)
            pending.add(if (cand.sourceUri != null) book.copy(sourceUri = cand.sourceUri) else book)
            c.imported++
            ok = true
            if (pending.size >= 200) flush()
        }.onFailure { e ->
            c.failed++
            Logger.w("扫描失败：${file.absolutePath} ${e.message}", "FileScanner")
        }
        cand.ok = ok
        return ok
    }

    /**
     * 并发解析元数据。
     *
     * 旧实现全程串行：每个文件依次跑"编码探测 + 全量章节扫描 / zip 解析 + 封面解码 + 压缩"，
     * 500 本 TXT 的目录导入非常慢。这里只把**纯 IO/CPU 的解析阶段**并发（固定 [PARSE_PARALLELISM]），
     * 去重 / 入库 / 计数仍然串行 —— 因此 knownPaths、pending、计数器都不需要加锁。
     */
    suspend fun flushBatch() {
      if (batch.isEmpty()) return
      val items = ArrayList(batch)
      batch.clear()
      val books: List<Book?> = if (items.size == 1) {
        listOf(runCatching { 
          parserFactory.anyParser(items[0].file, items[0].ext)?.parseMeta(items[0].file) 
        }.getOrNull())
      } else {
        val dispatcher = Dispatchers.IO.limitedParallelism(PARSE_PARALLELISM)
        coroutineScope {
          items.map { cand ->
            async(dispatcher) {
              runCatching { parserFactory.anyParser(cand.file, cand.ext)?.parseMeta(cand.file) }
                .onFailure { Logger.w("解析失败：${cand.file.absolutePath} ${it.message}", "FileScanner") }
                .getOrNull()
            }
          }.awaitAll()
        }
      }
      items.forEachIndexed { i, cand -> consumeParsed(cand, books.getOrNull(i)) }
    }

    /**
     * 判定条目是否值得解析：只做"能否解析 + 是否已入库"这类廉价判断，
     * 真正的 parseMeta 在 [flushBatch] 里并发执行。
     */
    suspend fun classify(file: File, ext: String, sourceUri: String?): Candidate? {
        if (parserFactory.anyParser(file, ext) == null) {
            if (ext.isNotEmpty()) c.skipped++
            return null
        }
        c.scanned++
        // 已入库且本轮不刷新：连解析都省掉
        if (!options.refreshExisting && knownPaths.contains(file.absolutePath)) {
            c.skipped++
            return null
        }
        val cand = Candidate(file, ext, sourceUri)
        batch.add(cand)
        if (batch.size >= PARSE_BATCH) flushBatch()
        return cand
    }

    suspend fun consumeFile(file: File, sourceUri: String?) {
      val ext = FileUtil.extension(file.name)
      when {
        ext.isNotEmpty() && !isSupported(ext) -> c.skipped++
        file.length() > options.maxFileSize -> c.skipped++
        else -> {
          classify(file, ext, sourceUri)
          tick(file.name)
        }
      }
    }

    /** 图片文件夹：判定为漫画后立刻结算该条（需要结果才能决定是否继续下钻） */
    suspend fun consumeComicFolder(dir: File, sourceUri: String?): Boolean {
      val cand = classify(dir, "", sourceUri)
      flushBatch()
      return cand?.ok == true
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
        if (consumeComicFolder(root, null)) {
          tick(root.name)
          return
        }
        // 判定为漫画目录却解析失败（图片不可读 / 权限受限）→ 继续当普通目录遍历，
        // 至少能扫到里面的单文件，不再整本消失
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
            if (consumeComicFolder(current, null)) {
              tick(current.name)
              continue
            }
            // 同上：解析失败不吞掉整个目录，继续下钻
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
              classify(local, "", dir.uri)
              tick(dir.name)
              true
            } else {
              false
            }
          } else if (options.folderAsComic && safScanner.isComicFolder(children)) {
            // 短篇：本层图片即整本（1 话）
            val local = safScanner.materializeFolder(dir.uri, dir.name, children)
            if (local != null) {
                classify(local, "", dir.uri)
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
                c.skipped++
              } else if (entry.size > options.maxFileSize) {
                c.skipped++
              } else {
                val local = safScanner.materialize(entry)
                if (local == null) {
                  c.failed++
                } else {
                  classify(local, entry.extension, entry.uri)
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

    flushBatch()
    flush()
    // SAF 物化缓存回收：导入时 SAF 目录会被整份复制到内部存储（漫画可达数百 MB），
    // 而物化目录此前只增不减（cleanOrphans 从未被调用）。扫描结束后按已入库书籍的
    // sourceUri 保留有效目录，其余（失败重试残留 / 已删除书籍 / 改名目录）全部清掉。
    runCatching { reclaimSafCache() }
    // 释放目录快照缓存：本轮扫描结束，结构性判定结果不再复用（避免读到过期结构）
    ComicFolder.clearSnapshotCache()
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
    /** 解析阶段的并发度：IO/CPU 密集，高于 CPU 核数收益递减 */
    const val PARSE_PARALLELISM = 4
    /** 攒够多少条再并发解析（太小则并发开销占比高，太大则进度回传滞后） */
    const val PARSE_BATCH = 16

    /** 仅统计 RAR5 等 junrar 解不了的包（RAR4 及更早已可直接阅读） */
    const val RAR_HINT = "部分 RAR 为 RAR5 格式无法解析，请转为 CBZ/ZIP"
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
