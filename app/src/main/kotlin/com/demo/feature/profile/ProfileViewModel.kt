package com.demo.feature.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

import com.demo.core.model.AppSettings
import com.demo.core.model.Book
import com.demo.core.model.ReadingStats
import com.demo.domain.repository.StatsRepository
import com.demo.domain.usecase.GetStatsUseCase
import com.demo.domain.usecase.ObserveSettingsUseCase
import com.demo.domain.usecase.UpdateSettingsUseCase

data class ProfileUiState(
    val isLoading: Boolean = true,
    val stats: ReadingStats = ReadingStats(),
    val recentFinished: List<Book> = emptyList(),
    val settings: AppSettings = AppSettings(),
    val message: String? = null
)

class ProfileViewModel(
    private val getStats: GetStatsUseCase,
    private val statsRepository: StatsRepository,
    private val observeSettings: ObserveSettingsUseCase,
    private val updateSettings: UpdateSettingsUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            observeSettings().collectLatest { settings ->
                _uiState.update { it.copy(settings = settings) }
            }
        }
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val stats = getStats()
            val finished = statsRepository.recentFinished(5)
            _uiState.update { it.copy(stats = stats, recentFinished = finished, isLoading = false) }
        }
    }

    fun rename(nickname: String) {
        viewModelScope.launch {
            updateSettings { it.copy(nickname = nickname.ifBlank { "阅读者" }) }
        }
    }

    fun clearHistory() {
        viewModelScope.launch {
            statsRepository.clearSessions()
            _uiState.update { it.copy(message = "已清空阅读记录") }
            refresh()
        }
    }

    fun consumeMessage() = _uiState.update { it.copy(message = null) }
}
