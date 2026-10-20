package com.demo.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

import com.demo.core.model.AppSettings
import com.demo.core.model.ThemeMode
import com.demo.domain.repository.StorageRepository
import com.demo.domain.usecase.ObserveSettingsUseCase
import com.demo.domain.usecase.UpdateSettingsUseCase

data class SettingsUiState(
    val settings: AppSettings = AppSettings(),
    val coverBytes: Long = 0L,
    val pageBytes: Long = 0L,
    val message: String? = null
)

class SettingsViewModel(
    private val observeSettings: ObserveSettingsUseCase,
    private val updateSettings: UpdateSettingsUseCase,
    private val storage: StorageRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            observeSettings().collectLatest { settings ->
                _uiState.update { it.copy(settings = settings) }
            }
        }
        refreshCache()
    }

    fun refreshCache() {
        viewModelScope.launch {
            _uiState.update {
                it.copy(
                    coverBytes = storage.coverCacheBytes(),
                    pageBytes = storage.pageCacheBytes()
                )
            }
        }
    }

    fun setTheme(mode: ThemeMode) = update { it.copy(themeMode = mode) }

    fun setDynamicColor(enabled: Boolean) = update { it.copy(dynamicColor = enabled) }

    fun setGlassLevel(level: String) = update { it.copy(glassLevel = level) }

    fun setNickname(name: String) = update { it.copy(nickname = name.ifBlank { "阅读者" }) }

    fun setComicPreload(count: Int) = update { it.copy(comicPreload = count.coerceIn(1, 3)) }

    fun setScanDepth(depth: Int) = update { it.copy(scanMaxDepth = depth.coerceIn(1, 8)) }

    fun setSkipHidden(skip: Boolean) = update { it.copy(skipHidden = skip) }

    fun clearCovers() {
        viewModelScope.launch {
            storage.clearCovers()
            _uiState.update { it.copy(message = "封面缓存已清理", coverBytes = 0L) }
        }
    }

    fun clearPages() {
        viewModelScope.launch {
            storage.clearPages()
            _uiState.update { it.copy(message = "页面缓存已清理", pageBytes = 0L) }
        }
    }

    fun consumeMessage() = _uiState.update { it.copy(message = null) }

    private fun update(transform: (AppSettings) -> AppSettings) {
        viewModelScope.launch { updateSettings(transform) }
    }
}
