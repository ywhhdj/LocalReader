package com.demo.core.model

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

/** WebDAV 配置 */
data class SyncConfig(
  val url: String = "",
  val user: String = "",
  val password: String = "",
  val remoteDir: String = "LocalReader",
  val autoBackup: Boolean = false
) {
  val enabled: Boolean get() = url.isNotBlank()
}