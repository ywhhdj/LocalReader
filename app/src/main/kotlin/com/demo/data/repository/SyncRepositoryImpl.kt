package com.demo.data.repository

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

import com.demo.core.common.util.Constants
import com.demo.core.common.util.Logger
import com.demo.core.common.util.Json
import com.demo.core.common.util.MiniJson
import com.demo.core.common.util.SimpleHttp
import com.demo.core.database.dao.BookDao
import com.demo.core.database.dao.GroupDao
import com.demo.core.database.dao.ProgressDao
import com.demo.core.database.dao.SessionDao
import com.demo.core.model.Book
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType

import com.demo.data.mapper.toEntity
import com.demo.data.mapper.toModel
import com.demo.data.remote.WebDavClient

import com.demo.core.model.BackupGroup
import com.demo.core.model.BackupProgress
import com.demo.core.model.BackupSession
import com.demo.core.model.BackupSnapshot
import com.demo.core.model.RemoteBackup
import com.demo.core.model.SyncConfig
import com.demo.core.model.SyncResult

import com.demo.domain.repository.SyncRepository


/**
 * WebDAV 备份同步实现。
 *
 * 说明：备份的是"书库元数据 + 进度 + 分组 + 阅读会话"，不含书籍文件本身（体积过大）。
 * 恢复时按 file_path / (book_id, start_at) 去重，只补齐缺失或更新的记录，不覆盖本地已有进度。
 */
class SyncRepositoryImpl(
    private val bookDao: BookDao,
    private val progressDao: ProgressDao,
    private val sessionDao: SessionDao,
    private val groupDao: GroupDao,
    private val backupDir: File,
    private val deviceName: String = android.os.Build.MODEL
) : SyncRepository {

    private val dav = WebDavClient()

    init {
        backupDir.mkdirs()
    }

    override suspend fun testConnection(config: SyncConfig): SyncResult = withContext(Dispatchers.IO) {
        if (!config.enabled) return@withContext SyncResult(false, "未配置 WebDAV 地址")
        runCatching {
            val auth = authOf(config)
            val base = dav.baseUrl(config)
            val ok = dav.mkcol(base, auth)
            val items = dav.propfind(base, auth)
            SyncResult(
                success = ok || items.isNotEmpty(),
                message = if (ok || items.isNotEmpty()) "连接成功" else "连接失败：请检查地址/账号/目录",
                remotePath = base
            )
        }.getOrElse { e ->
            SyncResult(false, "连接失败：${e.message ?: "未知错误"}")
        }
    }

    override suspend fun backup(config: SyncConfig, fileName: String?): SyncResult = withContext(Dispatchers.IO) {
        if (!config.enabled) return@withContext SyncResult(false, "未配置 WebDAV 地址")
        runCatching {
            val snapshot = buildSnapshot()
            val json = MiniJson.stringify(serialize(snapshot), pretty = false)
            val bytes = json.toByteArray(Charsets.UTF_8)
            val name = fileName ?: defaultFileName()
            val auth = authOf(config)
            val base = dav.baseUrl(config)
            dav.mkcol(base, auth)
            val target = base + name
            val ok = dav.put(target, auth, bytes)
            if (!ok) return@runCatching SyncResult(false, "上传失败：请检查权限与空间")
            SyncResult(true, "备份成功：$name", target, bytes.size.toLong(), snapshot.books.size)
        }.getOrElse { e ->
            SyncResult(false, "备份失败：${e.message ?: "未知错误"}")
        }
    }

    override suspend fun listBackups(config: SyncConfig): List<RemoteBackup> = withContext(Dispatchers.IO) {
        if (!config.enabled) return@withContext emptyList()
        runCatching {
            val base = dav.baseUrl(config)
            dav.propfind(base, authOf(config))
                .filter { !it.isDirectory && it.name.endsWith(".json", true) }
                .map {
                    RemoteBackup(
                        name = it.name,
                        path = if (it.href.startsWith("http")) it.href else base + it.name,
                        sizeBytes = it.sizeBytes,
                        modifiedAt = it.modifiedAt
                    )
                }
                .sortedByDescending { it.modifiedAt }
        }.getOrDefault(emptyList())
    }

    override suspend fun restore(config: SyncConfig, remotePath: String): SyncResult = withContext(Dispatchers.IO) {
        runCatching {
            val bytes = dav.get(remotePath, authOf(config))
                ?: return@runCatching SyncResult(false, "下载失败：$remotePath")
            importLocal(String(bytes, Charsets.UTF_8))
        }.getOrElse { e ->
            SyncResult(false, "恢复失败：${e.message ?: "未知错误"}")
        }
    }

    override suspend fun exportLocal(): String? = withContext(Dispatchers.IO) {
        runCatching {
            val snapshot = buildSnapshot()
            val json = MiniJson.stringify(serialize(snapshot), pretty = true)
            val file = File(backupDir, defaultFileName())
            file.writeText(json, Charsets.UTF_8)
            file.absolutePath
        }.onFailure { Logger.w("导出快照失败：${it.message}", "SyncRepository") }.getOrNull()
    }

    override suspend fun importLocal(content: String): SyncResult = withContext(Dispatchers.IO) {
        runCatching {
            val snapshot = deserialize(MiniJson.parse(content))
            val existingPaths = bookDao.allPaths().toHashSet()
            var added = 0
            snapshot.books.filter { it.filePath !in existingPaths }.forEach { book ->
                bookDao.upsert(book.copy(id = 0L, coverPath = null).toEntity(0L))
                added++
            }
            // 进度：远端较新才覆盖
            snapshot.progress.forEach { p ->
                val local = progressDao.get(p.bookId)
                if (local == null || p.updatedAt > local.updated_at) {
                    progressDao.upsert(
                        com.demo.core.database.entity.ReadingProgressEntity(
                            book_id = p.bookId,
                            chapter_index = p.chapterIndex,
                            char_offset = p.charOffset,
                            page_index = p.pageIndex,
                            progress = p.progress,
                            updated_at = p.updatedAt
                        )
                    )
                }
            }
            // 会话：按 (bookId, startAt) 去重
            val existingSessions = sessionDao.all().map { it.book_id to it.start_at }.toHashSet()
            snapshot.sessions.filter { (it.bookId to it.startAt) !in existingSessions }.forEach { s ->
                sessionDao.insert(
                    com.demo.core.database.entity.ReadingSessionEntity(
                        book_id = s.bookId, start_at = s.startAt, duration_ms = s.durationMs, type = s.type
                    )
                )
            }
            // 分组：按名称去重
            val existingGroups = groupDao.all().map { it.name }.toHashSet()
            snapshot.groups.filter { it.name !in existingGroups && it.kind != "SYSTEM" }.forEach { g ->
                groupDao.insert(
                    com.demo.core.database.entity.BookGroupEntity(
                        id = 0L, name = g.name, sort_order = g.sortOrder, kind = g.kind, created_at = g.createdAt
                    )
                )
            }
            SyncResult(true, "恢复完成：新增书籍 $added 本", remotePath = null, bookCount = snapshot.books.size)
        }.getOrElse { e ->
            SyncResult(false, "恢复失败：${e.message ?: "未知错误"}")
        }
    }

    // ---------- 快照 ----------

    private suspend fun buildSnapshot(): BackupSnapshot = BackupSnapshot(
        version = SNAPSHOT_VERSION,
        createdAt = System.currentTimeMillis(),
        device = deviceName,
        books = bookDao.all().map { it.toModel() },
        progress = progressDao.all().map {
            BackupProgress(
                bookId = it.book_id, chapterIndex = it.chapter_index, charOffset = it.char_offset,
                pageIndex = it.page_index, progress = it.progress, updatedAt = it.updated_at
            )
        },
        sessions = sessionDao.all().map {
            BackupSession(
                id = it.id, bookId = it.book_id, startAt = it.start_at,
                durationMs = it.duration_ms, type = it.type
            )
        },
        groups = groupDao.all().map {
            BackupGroup(id = it.id, name = it.name, sortOrder = it.sort_order, kind = it.kind, createdAt = it.created_at)
        }
    )

    // ---------- 序列化 ----------

    private fun serialize(snapshot: BackupSnapshot): Json = MiniJson.objOf(
        "version" to MiniJson.of(snapshot.version),
        "createdAt" to MiniJson.of(snapshot.createdAt),
        "device" to MiniJson.of(snapshot.device),
        "books" to MiniJson.arrOf(snapshot.books.map { book ->
            MiniJson.objOf(
                "title" to MiniJson.of(book.title),
                "author" to MiniJson.of(book.author),
                "type" to MiniJson.of(book.type.value),
                "format" to MiniJson.of(book.format.value),
                "filePath" to MiniJson.of(book.filePath),
                "sourceUri" to MiniJson.of(book.sourceUri),
                "sizeBytes" to MiniJson.of(book.sizeBytes),
                "addedAt" to MiniJson.of(book.addedAt),
                "lastReadAt" to MiniJson.of(book.lastReadAt),
                "groupId" to MiniJson.of(book.groupId ?: -1L),
                "favorite" to MiniJson.of(book.favorite),
                "progress" to MiniJson.of(book.progress),
                "chapterCount" to MiniJson.of(book.chapterCount),
                "pageCount" to MiniJson.of(book.pageCount),
                "metaJson" to MiniJson.of(book.metaJson)
            )
        }),
        "progress" to MiniJson.arrOf(snapshot.progress.map { p ->
            MiniJson.objOf(
                "bookId" to MiniJson.of(p.bookId),
                "chapterIndex" to MiniJson.of(p.chapterIndex),
                "charOffset" to MiniJson.of(p.charOffset),
                "pageIndex" to MiniJson.of(p.pageIndex),
                "progress" to MiniJson.of(p.progress),
                "updatedAt" to MiniJson.of(p.updatedAt)
            )
        }),
        "sessions" to MiniJson.arrOf(snapshot.sessions.map { s ->
            MiniJson.objOf(
                "bookId" to MiniJson.of(s.bookId),
                "startAt" to MiniJson.of(s.startAt),
                "durationMs" to MiniJson.of(s.durationMs),
                "type" to MiniJson.of(s.type)
            )
        }),
        "groups" to MiniJson.arrOf(snapshot.groups.map { g ->
            MiniJson.objOf(
                "name" to MiniJson.of(g.name),
                "sortOrder" to MiniJson.of(g.sortOrder),
                "kind" to MiniJson.of(g.kind),
                "createdAt" to MiniJson.of(g.createdAt)
            )
        })
    )

    private fun deserialize(json: Json): BackupSnapshot {
        val books = (json.arr("books")?.items ?: emptyList()).mapNotNull { item ->
            val path = item.str("filePath") ?: return@mapNotNull null
            Book(
                id = 0L,
                title = item.str("title", "").ifBlank { path.substringAfterLast('/') },
                author = item.str("author", ""),
                type = BookType.from(item.str("type")),
                format = BookFormat.from(item.str("format")),
                filePath = path,
                sourceUri = item.str("sourceUri"),
                sizeBytes = (item.num("sizeBytes") ?: 0.0).toLong(),
                addedAt = (item.num("addedAt") ?: System.currentTimeMillis().toDouble()).toLong(),
                lastReadAt = (item.num("lastReadAt") ?: 0.0).toLong(),
                groupId = (item.num("groupId")?.toLong() ?: -1L).takeIf { it >= 0L },
                favorite = item.bool("favorite"),
                progress = (item.num("progress") ?: 0.0).toFloat(),
                chapterCount = (item.num("chapterCount") ?: 0.0).toInt(),
                pageCount = (item.num("pageCount") ?: 0.0).toInt(),
                metaJson = item.str("metaJson")
            )
        }
        val progress = (json.arr("progress")?.items ?: emptyList()).map { item ->
            BackupProgress(
                bookId = (item.num("bookId") ?: 0.0).toLong(),
                chapterIndex = (item.num("chapterIndex") ?: 0.0).toInt(),
                charOffset = (item.num("charOffset") ?: 0.0).toInt(),
                pageIndex = (item.num("pageIndex") ?: 0.0).toInt(),
                progress = (item.num("progress") ?: 0.0).toFloat(),
                updatedAt = (item.num("updatedAt") ?: 0.0).toLong()
            )
        }
        val sessions = (json.arr("sessions")?.items ?: emptyList()).map { item ->
            BackupSession(
                bookId = (item.num("bookId") ?: 0.0).toLong(),
                startAt = (item.num("startAt") ?: 0.0).toLong(),
                durationMs = (item.num("durationMs") ?: 0.0).toLong(),
                type = item.str("type", "NOVEL")
            )
        }
        val groups = (json.arr("groups")?.items ?: emptyList()).map { item ->
            BackupGroup(
                name = item.str("name", ""),
                sortOrder = (item.num("sortOrder") ?: 0.0).toInt(),
                kind = item.str("kind", "USER"),
                createdAt = (item.num("createdAt") ?: 0.0).toLong()
            )
        }
        return BackupSnapshot(
            version = (json.num("version") ?: 1.0).toInt(),
            createdAt = (json.num("createdAt") ?: 0.0).toLong(),
            device = json.str("device", ""),
            books = books,
            progress = progress,
            sessions = sessions,
            groups = groups
        )
    }

    private fun authOf(config: SyncConfig): String? =
        if (config.user.isBlank() && config.password.isBlank()) null
        else SimpleHttp.basicAuth(config.user, config.password)

    private fun defaultFileName(): String {
        val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
        return "liquid-reader-$stamp.json"
    }

    companion object {
        const val SNAPSHOT_VERSION = 1
        val DIR_NAME = Constants.BACKUP_DIR
    }
}
