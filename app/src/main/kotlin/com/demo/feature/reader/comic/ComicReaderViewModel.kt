package com.demo.feature.reader.comic

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
import com.demo.core.model.BookType
import com.demo.core.model.ComicPage
import com.demo.domain.repository.ComicContent
import com.demo.domain.repository.ProgressRepository
import com.demo.domain.repository.SettingsRepository
import com.demo.domain.usecase.GetBookUseCase
import com.demo.domain.usecase.OpenComicUseCase
import com.demo.domain.usecase.ReadingSessionUseCase

data class ComicReaderUiState(
    val book: Book? = null,
    val pages: List<ComicPage> = emptyList(),
    val pageIndex: Int = 0,
    val loading: Boolean = true,
    val settings: AppSettings = AppSettings(),
    val showOverlay: Boolean = true,
    val error: String? = null
)

/**
 * 漫画阅读：页窗口 ±preload，窗口外释放；页码变化节流保存进度。
 * 解析结果统一为本地缓存文件路径，交给图片加载器按尺寸采样。
 */
class ComicReaderViewModel(
    private val getBook: GetBookUseCase,
    private val openComic: OpenComicUseCase,
    private val progressRepository: ProgressRepository,
    private val settingsRepository: SettingsRepository,
    private val session: ReadingSessionUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(ComicReaderUiState())
    val uiState: StateFlow<ComicReaderUiState> = _uiState.asStateFlow()

    /** index -> 本地缓存路径，仅保留窗口内 */
    private val resolved = HashMap<Int, String>()
    private val pagePaths = MutableStateFlow<Map<Int, String>>(emptyMap())
    val paths: StateFlow<Map<Int, String>> = pagePaths.asStateFlow()

    private var content: ComicContent? = null
    private var sessionId: Long = 0L
    private var sessionStartAt: Long = 0L
    private var bookId: Long = 0L
    private var preload: Int = 2

    init {
        viewModelScope.launch {
            settingsRepository.observe().collectLatest { settings ->
                preload = settings.comicPreload.coerceIn(1, 3)
                _uiState.update { it.copy(settings = settings) }
            }
        }
    }

    fun load(id: Long) {
        if (id <= 0L || id == bookId) return
        bookId = id
        viewModelScope.launch {
            _uiState.update { it.copy(loading = true, error = null) }
            runCatching {
                val book = getBook(id) ?: return@launch
                val opened = openComic(book)
                content?.close()
                content = opened
                val progress = progressRepository.get(id)
                val index = progress?.pageIndex?.coerceAtLeast(0) ?: 0
                _uiState.update {
                    it.copy(
                        book = book,
                        pages = opened.pages,
                        pageIndex = index.coerceAtMost((opened.pages.lastIndex).coerceAtLeast(0)),
                        loading = false
                    )
                }
                sessionId = session.start(book.id, BookType.COMIC)
                sessionStartAt = System.currentTimeMillis()
                ensureWindow(index)
            }.onFailure { e ->
                _uiState.update { it.copy(loading = false, error = e.message ?: "打开失败") }
            }
        }
    }

    fun onPageChanged(index: Int) {
        if (index == _uiState.value.pageIndex) return
        _uiState.update { it.copy(pageIndex = index) }
        ensureWindow(index)
        val pageCount = _uiState.value.pages.size
        viewModelScope.launch {
            progressRepository.saveComic(bookId, index, pageCount, 0f)
        }
    }

    /** 仅保留窗口内的解析结果，窗口外从内存移除（磁盘缓存保留） */
    private fun ensureWindow(center: Int) {
        val from = (center - preload).coerceAtLeast(0)
        val to = (center + preload).coerceAtLast(_uiState.value.pages.lastIndex)
        resolved.keys.filter { it !in from..to }.forEach { resolved.remove(it) }
        pagePaths.value = resolved.toMap()
        viewModelScope.launch {
            for (i in from..to) {
                if (resolved.containsKey(i)) continue
                val path = runCatching { content?.resolvePage(i) }.getOrNull()
                if (path != null) {
                    resolved[i] = path
                    pagePaths.value = resolved.toMap()
                }
            }
        }
    }

    fun pathFor(index: Int): String? = resolved[index]

    fun toggleOverlay() = _uiState.update { it.copy(showOverlay = !it.showOverlay) }

    fun updateSettings(transform: (AppSettings) -> AppSettings) {
        viewModelScope.launch { settingsRepository.update(transform) }
    }

    override fun onCleared() {
        super.onCleared()
        viewModelScope.launch {
            runCatching { session.end(sessionId, sessionStartAt, BookType.COMIC) }
        }
        content?.close()
        content = null
        resolved.clear()
        pagePaths.value = emptyMap()
    }
}

private fun Int.coerceAtLast(last: Int): Int = if (last < 0) this else coerceAtMost(last)
