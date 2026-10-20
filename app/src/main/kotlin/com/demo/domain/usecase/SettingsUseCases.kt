package com.demo.domain.usecase

import com.demo.core.model.AppSettings
import com.demo.domain.repository.SettingsRepository
import kotlinx.coroutines.flow.Flow

class ObserveSettingsUseCase(private val repo: SettingsRepository) {
    operator fun invoke(): Flow<AppSettings> = repo.observe()
}

class UpdateSettingsUseCase(private val repo: SettingsRepository) {
    suspend operator fun invoke(transform: (AppSettings) -> AppSettings) = repo.update(transform)
}
