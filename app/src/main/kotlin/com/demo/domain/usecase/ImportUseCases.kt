package com.demo.domain.usecase

import com.demo.domain.repository.ScanOptions
import com.demo.domain.repository.ScanProgress
import com.demo.domain.repository.ScanTarget
import com.demo.domain.repository.ScannerRepository
import kotlinx.coroutines.flow.Flow

class ImportBooksUseCase(private val scanner: ScannerRepository) {

    /** 按扫描目标导入（推荐：路径 / SAF 树 URI） */
    operator fun invoke(targets: List<ScanTarget>, options: ScanOptions = ScanOptions()): Flow<ScanProgress> =
        scanner.scan(targets, options)

    /** 便捷：直接传路径或 URI 字符串 */
    fun raw(raws: List<String>, options: ScanOptions = ScanOptions()): Flow<ScanProgress> =
        scanner.scanRaw(raws, options)
}
