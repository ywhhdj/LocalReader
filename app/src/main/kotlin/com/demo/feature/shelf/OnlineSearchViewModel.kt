package com.demo.feature.shelf

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

import com.demo.core.model.AppSettings
import com.demo.domain.repository.BookSource
import com.demo.domain.repository.BookSourceRepository
import com.demo.domain.repository.OnlineBook
import com.demo.domain.repository.OnlineChapter
import com.demo.domain.usecase.ImportBooksUseCase
import com.demo.domain.usecase.ObserveSettingsUseCase
import com.demo.domain.usecase.OnlineChaptersUseCase
import com.demo.domain.usecase.OnlineSearchUseCase
import com.demo.domain.usecase.OnlineSourcesUseCase

data class OnlineSearchUiState(
    val enabled: Boolean = false,
    val sources: List<BookSource> = emptyList(),
    val selectedSourceId: String = "",
    val keyword: String = "",
    val results: List<OnlineBook> = emptyList(),
    val detail: OnlineBook? = null,
    val chapters: List<OnlineChapter> = emptyList(),
    val loading: Boolean = false,
    val saving: Boolean = false,
    val saveProgress: Pair<Int, Int>? = null,
    val settings: AppSettings = AppSettings(),
    val message: String? = null
)

/**
 * 在线书源搜索（设置里关闭时不可用，且不产生任何网络请求）。
 * 抓取结果只能"另存为 TXT 到本地书库"，随后按本地书流程阅读。
 */
class OnlineSearchViewModel(
    private val onlineSources: OnlineSourcesUseCase,
    private val onlineSearch: OnlineSearchUseCase,
    private val onlineChapters: OnlineChaptersUseCase,
    private val bookSourceRepository: BookSourceRepository,
    private val importBooks: ImportBooksUseCase,
    private val observeSettings: ObserveSettingsUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(OnlineSearchUiState())
    val uiState: StateFlow<OnlineSearchUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            observeSettings().collectLatest { settings ->
                val sources = onlineSources()
                _uiState.update {
                    it.copy(
                        settings = settings,
                        enabled = settings.onlineSourceEnabled,
                        sources = sources,
                        selectedSourceId = it.selectedSourceId.ifBlank { sources.firstOrNull()?.id.orEmpty() }
                    )
                }
            }
        }
    }

    fun onKeywordChange(value: String) = _uiState.update { it.copy(keyword = value) }

    fun selectSource(id: String) = _uiState.update { it.copy(selectedSourceId = id) }

    fun search() {
        val state = _uiState.value
        val keyword = state.keyword.trim()
        if (!state.enabled) {
            _uiState.update { it.copy(message = "在线书源未开启：请到设置 → 在线书源开启") }
            return
        }
        if (keyword.isBlank()) return
        if (state.sources.isEmpty()) {
            _uiState.update { it.copy(message = "还没有配置书源：请到设置 → 在线书源添加") }
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(loading = true, results = emptyList(), detail = null) }
            val results = runCatching { onlineSearch(state.selectedSourceId, keyword) }
                .onFailure { e -> _uiState.update { it.copy(message = "搜索失败：${e.message}") } }
                .getOrDefault(emptyList())
            _uiState.update {
                it.copy(
                    loading = false,
                    results = results,
                    message = if (results.isEmpty()) "没有结果：请检查书源规则" else null
                )
            }
        }
    }

    fun openDetail(book: OnlineBook) {
        viewModelScope.launch {
            _uiState.update { it.copy(detail = book, chapters = emptyList(), loading = true) }
            val chapters = runCatching { onlineChapters(book) }.getOrDefault(emptyList())
            _uiState.update {
                it.copy(
                    chapters = chapters,
                    loading = false,
                    message = if (chapters.isEmpty()) "目录为空：请检查书源规则" else null
                )
            }
        }
    }

    fun closeDetail() = _uiState.update { it.copy(detail = null, chapters = emptyList()) }

    /** 抓取并另存为 TXT，随后导入本地书库 */
    fun saveToLibrary() {
        val state = _uiState.value
        val book = state.detail ?: return
        if (state.chapters.isEmpty()) return
        viewModelScope.launch {
            _uiState.update { it.copy(saving = true, saveProgress = 0 to state.chapters.size) }
            val path = runCatching {
                bookSourceRepository.saveAsTxt(book, state.chapters) { done, total ->
                    _uiState.update { it.copy(saveProgress = done to total) }
                }
            }.getOrNull()
            if (path == null) {
                _uiState.update { it.copy(saving = false, saveProgress = null, message = "保存失败") }
                return@launch
            }
            importBooks.raw(listOf(path)).collect { progress ->
                if (progress.done) {
                    _uiState.update {
                        it.copy(
                            saving = false,
                            saveProgress = null,
                            message = "已保存到本地书库：${progress.imported} 本"
                        )
                    }
                }
            }
        }
    }

    fun consumeMessage() = _uiState.update { it.copy(message = null) }
}
