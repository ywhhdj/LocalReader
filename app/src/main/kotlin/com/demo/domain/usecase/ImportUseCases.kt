package com.demo.domain.usecase

import com.demo.domain.repository.ScanOptions
import com.demo.domain.repository.ScanProgress
import com.demo.domain.repository.ScannerRepository
import kotlinx.coroutines.flow.Flow

class ImportBooksUseCase(private val scanner: ScannerRepository) {
    operator fun invoke(paths: List<String>, options: ScanOptions = ScanOptions()): Flow<ScanProgress> =
        scanner.scan(paths, options)
}
