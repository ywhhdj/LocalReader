package com.demo.domain.repository

import kotlinx.coroutines.flow.Flow

data class ScanOptions(
    val maxDepth: Int = 4,
    val maxFiles: Int = 20_000,
    val maxFileSize: Long = 200L * 1024 * 1024,
    val skipHidden: Boolean = true
)

data class ScanProgress(
    val scanned: Int = 0,
    val imported: Int = 0,
    val skipped: Int = 0,
    val failed: Int = 0,
    val current: String = "",
    val done: Boolean = false
)

interface ScannerRepository {
    /** 扫描并入库，回传进度（可取消：取消 Flow 收集即中断） */
    fun scan(paths: List<String>, options: ScanOptions = ScanOptions()): Flow<ScanProgress>
}
