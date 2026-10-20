package com.demo.domain.usecase

import com.demo.core.model.AppSettings
import com.demo.domain.repository.RemoteBackup
import com.demo.domain.repository.SyncConfig
import com.demo.domain.repository.SyncRepository
import com.demo.domain.repository.SyncResult

/** 从设置构造同步配置 */
fun AppSettings.syncConfig(): SyncConfig = SyncConfig(
    url = webdavUrl,
    user = webdavUser,
    password = webdavPassword,
    remoteDir = webdavDir,
    autoBackup = webdavAutoBackup
)

class TestSyncConnectionUseCase(private val sync: SyncRepository) {
    suspend operator fun invoke(config: SyncConfig): SyncResult = sync.testConnection(config)
}

class BackupNowUseCase(private val sync: SyncRepository) {
    suspend operator fun invoke(config: SyncConfig): SyncResult = sync.backup(config)
}

class ListBackupsUseCase(private val sync: SyncRepository) {
    suspend operator fun invoke(config: SyncConfig): List<RemoteBackup> = sync.listBackups(config)
}

class RestoreBackupUseCase(private val sync: SyncRepository) {
    suspend operator fun invoke(config: SyncConfig, remotePath: String): SyncResult =
        sync.restore(config, remotePath)
}

class ExportSnapshotUseCase(private val sync: SyncRepository) {
    /** 返回导出的本地文件路径 */
    suspend operator fun invoke(): String? = sync.exportLocal()
}

class ImportSnapshotUseCase(private val sync: SyncRepository) {
    suspend operator fun invoke(content: String): SyncResult = sync.importLocal(content)
}
