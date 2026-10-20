package com.demo.feature.reader.novel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.AppSettings
import com.demo.core.model.Book
import com.demo.core.model.BookBlock
import com.demo.core.model.BookType
import com.demo.core.model.Chapter

import com.demo.domain.repository.NovelContent
import com.demo.domain.repository.ProgressRepository
import com.demo.domain.repository.ReaderRepository
import com.demo.domain.repository.SettingsRepository
import com.demo.domain.repository.TtsEngine
import com.demo.domain.repository.TtsState
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
    val canNext: Boolean = false,
    /** 朗读状态 */
    val tts: TtsState = TtsState()
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
    private val session: ReadingSessionUseCase,
    private val ttsEngine: TtsEngine
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

    /** 滚动位置 → 节流合并写库（滚动时不再每个索引都落一次 DB） */
    private val pendingProgress = MutableSharedFlow<Pair<Int, Int>>(extraBufferCapacity = 8)

    /**
     * 独立于 viewModelScope 的收尾作用域：
     * viewModelScope 在 onCleared 之前就被取消，若仍用它写库，阅读会话会丢失（统计永远为 0）。
     */
    private val flushScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    init {
        viewModelScope.launch {
            settingsRepository.observe().collectLatest { settings ->
                _uiState.update { it.copy(settings = settings) }
                ttsEngine.setRate(settings.ttsRate)
                ttsEngine.setPitch(settings.ttsPitch)
            }
        }
        viewModelScope.launch {
            pendingProgress.collectLatest { (chapterIndex, charOffset) ->
                delay(PROGRESS_THROTTLE_MS)
                saveProgress(chapterIndex, charOffset)
            }
        }
        viewModelScope.launch {
            var wasSpeaking = false
            ttsEngine.state.collectLatest { tts ->
                val finished = wasSpeaking && !tts.speaking &&
                    tts.chunkCount > 0 && tts.chunkIndex >= tts.chunkCount
                wasSpeaking = tts.speaking
                _uiState.update { it.copy(tts = tts) }
                if (finished && _uiState.value.settings.ttsAutoNext && _uiState.value.canNext) {
                    nextChapter()
                    // 等待新章节内容渲染完成后再继续朗读
                    var waited = 0
                    while (_uiState.value.loading && waited < 5000) {
                        kotlinx.coroutines.delay(120)
                        waited += 120
                    }
                    startTts()
                }
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

    private fun chaptersOf(): List<Chapter> = _uiState.value.chapters

    private companion object {
        const val PROGRESS_THROTTLE_MS = 500L
    }

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
        val raw = runCatching { opened.loadChapter(index) }
            .getOrDefault(listOf(BookBlock.Paragraph("（章节加载失败）")))
        // 双保险：解析器已去掉重复标题行，这里再兜一层（含卷名写法）
        val chapter = chaptersOf().getOrNull(index)
        val blocks = if (chapter == null) raw else {
            VolumeSplitter.stripTitles(
                raw,
                listOf(chapter.title, VolumeSplitter.displayTitle(chapter))
            )
        }
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

    /** UI 滚动回调：只投递，不做 IO（由 pendingProgress 节流后统一写库） */
    fun onScrollPosition(chapterIndex: Int, charOffset: Int) {
        pendingProgress.tryEmit(chapterIndex to charOffset)
    }

    /** 立即写入（切章、退出阅读器时使用） */
    fun saveProgress(chapterIndex: Int, charOffset: Int) {
        val chapters = _uiState.value.chapters
        if (chapters.isEmpty()) return
        val progress = ((chapterIndex + 1).toFloat() / chapters.size).coerceAtMost(1f)
        viewModelScope.launch {
            progressRepository.saveNovel(bookId, chapterIndex, charOffset, progress)
        }
    }

    // ---------- 朗读（TTS） ----------

    /** 朗读当前章节；已在朗读则停止 */
    fun toggleTts() {
        if (_uiState.value.tts.speaking) {
            stopTts()
            return
        }
        startTts()
    }

    /** 朗读当前章节正文（图片跳过） */
    private fun startTts() {
        val blocks = _uiState.value.blocks
        if (blocks.isEmpty()) return
        val text = buildString {
            blocks.forEach { block ->
                when (block) {
                    is BookBlock.Paragraph -> append(block.text).append('\n')
                    is BookBlock.Heading -> append(block.text).append('\n')
                    is BookBlock.Quote -> append(block.text).append('\n')
                    is BookBlock.Image -> Unit
                    BookBlock.Break -> append('\n')
                }
            }
        }
        viewModelScope.launch {
            ttsEngine.setRate(_uiState.value.settings.ttsRate)
            ttsEngine.setPitch(_uiState.value.settings.ttsPitch)
            ttsEngine.speak(text)
        }
    }

    fun stopTts() = ttsEngine.stop()

    fun setTtsRate(rate: Float) {
        ttsEngine.setRate(rate)
        updateSettings { it.copy(ttsRate = rate) }
    }

    fun setTtsPitch(pitch: Float) {
        ttsEngine.setPitch(pitch)
        updateSettings { it.copy(ttsPitch = pitch) }
    }

    fun toggleToc(show: Boolean? = null) = _uiState.update { it.copy(showToc = show ?: !it.showToc) }
    fun toggleSettings(show: Boolean? = null) = _uiState.update { it.copy(showSettings = show ?: !it.showSettings) }

    fun updateSettings(transform: (AppSettings) -> AppSettings) {
        viewModelScope.launch { settingsRepository.update(transform) }
    }

    /** 退出前强制落盘最近一次滚动位置（走 flushScope，viewModelScope 此时已取消） */
    fun flushProgress() {
        val state = _uiState.value
        if (state.chapters.isEmpty() || bookId <= 0L) return
        val progress = ((state.chapterIndex + 1).toFloat() / state.chapters.size).coerceAtMost(1f)
        flushScope.launch {
            runCatching { progressRepository.saveNovel(bookId, state.chapterIndex, 0, progress) }
        }
    }

    fun finishChapterReading() {
        val state = _uiState.value
        if (state.chapters.isNotEmpty()) {
            saveProgress(state.chapterIndex, 0)
        }
    }

    override fun onCleared() {
        super.onCleared()
        runCatching { ttsEngine.stop() }
        flushProgress()
        flushScope.launch {
            runCatching { session.end(sessionId, sessionStartAt, BookType.NOVEL) }
        }
        content?.close()
        content = null
        chapterCache.clear()
    }
}
