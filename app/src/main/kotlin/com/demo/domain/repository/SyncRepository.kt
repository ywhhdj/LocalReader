package com.demo.domain.repository

import com.demo.core.model.Book
import com.demo.core.model.Chapter

/** 备份快照：WebDAV 同步的数据载体（JSON 序列化） */
data class BackupSnapshot(
    val version: Int = 1,
    val createdAt: Long = System.currentTimeMillis(),
    val device: String = "",
    val books: List<Book> = emptyList(),
    val progress: List<BackupProgress> = emptyList(),
    val sessions: List<BackupSession> = emptyList(),
    val groups: List<BackupGroup> = emptyList()
)

data class BackupGroup(
    val id: Long = 0L,
    val name: String = "",
    val sortOrder: Int = 0,
    val kind: String = "USER",
    val createdAt: Long = 0L
)

data class BackupProgress(
    val bookId: Long = 0L,
    val chapterIndex: Int = 0,
    val charOffset: Int = 0,
    val pageIndex: Int = 0,
    val progress: Float = 0f,
    val updatedAt: Long = 0L
)

data class BackupSession(
    val id: Long = 0L,
    val bookId: Long = 0L,
    val startAt: Long = 0L,
    val durationMs: Long = 0L,
    val type: String = "NOVEL"
)

/** 同步结果 */
data class SyncResult(
    val success: Boolean,
    val message: String,
    val remotePath: String? = null,
    val bytes: Long = 0L,
    val bookCount: Int = 0
)

/** 远端备份条目（供恢复时选择） */
data class RemoteBackup(
    val name: String,
    val path: String,
    val sizeBytes: Long,
    val modifiedAt: Long
)

/**
 * WebDAV 备份同步（默认关闭，用户配置后才启用）。
 */
interface SyncRepository {

    /** 测试连接（MKCOL + PROPFIND） */
    suspend fun testConnection(config: SyncConfig): SyncResult

    /** 上传当前数据快照 */
    suspend fun backup(config: SyncConfig, fileName: String? = null): SyncResult

    /** 列出远端备份 */
    suspend fun listBackups(config: SyncConfig): List<RemoteBackup>

    /** 下载并合并远端快照到本地（按 filePath 去重，仅补齐缺失/较新的记录） */
    suspend fun restore(config: SyncConfig, remotePath: String): SyncResult

    /** 生成本地快照文件（导出用） */
    suspend fun exportLocal(): String?

    /** 从本地快照文件恢复 */
    suspend fun importLocal(content: String): SyncResult
}

/** WebDAV 配置 */
data class SyncConfig(
    val url: String = "",
    val user: String = "",
    val password: String = "",
    val remoteDir: String = "LiquidReader",
    val autoBackup: Boolean = false
) {
    val enabled: Boolean get() = url.isNotBlank()
}
