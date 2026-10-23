package com.demo.domain.repository

import com.demo.core.model.SyncResult
import com.demo.core.model.RemoteBackup
import com.demo.core.model.SyncConfig

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
