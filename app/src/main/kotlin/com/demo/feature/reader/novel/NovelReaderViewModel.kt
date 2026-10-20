package com.demo.feature.reader.novel

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
import com.demo.core.model.BookBlock
import com.demo.core.model.BookType
import com.demo.core.model.Chapter

import com.demo.domain.repository.NovelContent
import com.demo.domain.repository.ProgressRepository
import com.demo.domain.repository.ReaderRepository
import com.demo.domain.repository.SettingsRepository
import com.demo.domain.usecase.GetBookUseCase
import com.demo.domain.usecase.OpenNovelUseCase
import com.demo.domain.usecase.ReadingSessionUseCase

data class NovelReaderUiState(
    val book: Book? = null,
    val chapters: List<Chapter> = emptyList(),
    val chapterIndex: Int = 0,
    val blocks: List<BookBlock> = emptyList(),
    val loading: Boolean = true,
    val settings: AppSettings = AppSettings(),
    val showToc: Boolean = false,
    val showSettings: Boolean = false,
    val error: String? = null,
    val canPrev: Boolean = false,
    val canNext: Boolean = false
)

/**
 * 小说阅读：单章渲染 + 章节内容 LRU 缓存（上限 10 章），
 * 关闭页面时释放 zip/文件句柄并结束阅读会话。
 */
class NovelReaderViewModel(
    private val getBook: GetBookUseCase,
    private val openNovel: OpenNovelUseCase,
    private val readerRepository: ReaderRepository,
    private val progressRepository: ProgressRepository,
    private val settingsRepository: SettingsRepository,
    private val session: ReadingSessionUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(NovelReaderUiState())
    val uiState: StateFlow<NovelReaderUiState> = _uiState.asStateFlow()

    private var content: NovelContent? = null
    private var sessionId: Long = 0L
    private var sessionStartAt: Long = 0L
    private var bookId: Long = 0L

    private val chapterCache = object : LinkedHashMap<Int, List<BookBlock>>(12, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Int, List<BookBlock>>?): Boolean = size > 10
    }

    init {
        viewModelScope.launch {
            settingsRepository.observe().collectLatest { settings ->
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
                val opened = openNovel(book)
                content?.close()
                content = opened
                val progress = progressRepository.get(id)
                val index = progress?.chapterIndex?.coerceAtLeast(0) ?: 0
                _uiState.update {
                    it.copy(book = book, chapters = opened.chapters, chapterIndex = index, loading = false)
                }
                sessionId = session.start(book.id, BookType.NOVEL)
                sessionStartAt = System.currentTimeMillis()
                loadChapterInternal(index)
            }.onFailure { e ->
                _uiState.update { it.copy(loading = false, error = e.message ?: "打开失败") }
            }
        }
    }

    fun jumpToChapter(index: Int) {
        val chapters = _uiState.value.chapters
        if (index !in chapters.indices) return
        _uiState.update { it.copy(chapterIndex = index, showToc = false) }
        viewModelScope.launch { loadChapterInternal(index) }
    }

    fun nextChapter() = jumpToChapter(_uiState.value.chapterIndex + 1)
    fun prevChapter() = jumpToChapter(_uiState.value.chapterIndex - 1)

    private suspend fun loadChapterInternal(index: Int) {
        val cached = chapterCache[index]
        if (cached != null) {
            _uiState.update { it.copy(blocks = cached, loading = false) }
            return
        }
        _uiState.update { it.copy(loading = true) }
        val opened = content ?: run {
            val book = _uiState.value.book ?: return
            openNovel(book).also { content = it }
        }
        val blocks = runCatching { opened.loadChapter(index) }
            .getOrDefault(listOf(BookBlock.Paragraph("（章节加载失败）")))
        chapterCache[index] = blocks
        _uiState.update {
            it.copy(
                blocks = blocks,
                loading = false,
                canPrev = index > 0,
                canNext = index < it.chapters.lastIndex
            )
        }
        saveProgress(index, 0)
    }

    /** 滚动位置节流保存由 UI 调用，内部合并写库 */
    fun saveProgress(chapterIndex: Int, charOffset: Int) {
        val chapters = _uiState.value.chapters
        if (chapters.isEmpty()) return
        val progress = ((chapterIndex + 1).toFloat() / chapters.size).coerceAtMost(1f)
        viewModelScope.launch {
            progressRepository.saveNovel(bookId, chapterIndex, charOffset, progress)
        }
    }

    fun toggleToc(show: Boolean? = null) = _uiState.update { it.copy(showToc = show ?: !it.showToc) }
    fun toggleSettings(show: Boolean? = null) = _uiState.update { it.copy(showSettings = show ?: !it.showSettings) }

    fun updateSettings(transform: (AppSettings) -> AppSettings) {
        viewModelScope.launch { settingsRepository.update(transform) }
    }

    fun finishChapterReading() {
        val state = _uiState.value
        if (state.chapters.isNotEmpty()) {
            saveProgress(state.chapterIndex, 0)
        }
    }

    override fun onCleared() {
        super.onCleared()
        viewModelScope.launch {
            runCatching { session.end(sessionId, sessionStartAt, BookType.NOVEL) }
        }
        content?.close()
        content = null
        chapterCache.clear()
    }
}
