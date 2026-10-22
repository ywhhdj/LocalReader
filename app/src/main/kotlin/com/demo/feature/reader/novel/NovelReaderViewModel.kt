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

    /**
     * 章节内容缓存：最多 10 章，且总字符数受 [MAX_CACHE_CHARS] 限制。
     * 只按章数限制时，几章超长章节就能吃掉几十 MB，这里双上限控制内存。
     */
    private val chapterCache = LinkedHashMap<Int, List<BookBlock>>(12, 0.75f, true)
    private var cachedChars = 0

    private fun putChapter(index: Int, blocks: List<BookBlock>) {
        val old = chapterCache.put(index, blocks)
        if (old != null) cachedChars -= charsOf(old)
        cachedChars += charsOf(blocks)
        // 访问序：迭代器头部即最久未使用的章节
        val iterator = chapterCache.entries.iterator()
        while (chapterCache.size > MAX_CACHE_CHAPTERS ||
            (cachedChars > MAX_CACHE_CHARS && chapterCache.size > 1)
        ) {
            if (!iterator.hasNext()) break
            val eldest = iterator.next()
            cachedChars -= charsOf(eldest.value)
            iterator.remove()
        }
    }

    private fun charsOf(blocks: List<BookBlock>): Int {
        var total = 0
        for (block in blocks) {
            total += when (block) {
                is BookBlock.Heading -> block.text.length
                is BookBlock.Paragraph -> block.text.length
                is BookBlock.Quote -> block.text.length
                is BookBlock.Image -> 0
                BookBlock.Break -> 0
            }
        }
        return total
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

    /**
     * 打开小说。
     * @param startChapter 指定起始章节（详情页目录跳转）；null 表示按阅读进度继续
     */
    fun load(id: Long, startChapter: Int? = null) {
        if (id <= 0L) return
        // 同一本书未指定章节的重复调用忽略；指定了章节允许重新定位
        if (id == bookId && startChapter == null) return
        bookId = id
        viewModelScope.launch {
            _uiState.update { it.copy(loading = true, error = null) }
            runCatching {
                val book = getBook(id) ?: return@launch
                val opened = openNovel(book)
                content?.close()
                content = opened
                val progress = progressRepository.get(id)
                val last = opened.chapters.lastIndex.coerceAtLeast(0)
                val index = when {
                    startChapter != null -> startChapter.coerceIn(0, last)
                    else -> (progress?.chapterIndex ?: 0).coerceIn(0, last)
                }
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
        // 同时收起目录抽屉与设置面板，避免两者叠在一起
        _uiState.update { it.copy(chapterIndex = index, showToc = false, showSettings = false) }
        viewModelScope.launch { loadChapterInternal(index) }
    }

    fun nextChapter() = jumpToChapter(_uiState.value.chapterIndex + 1)
    fun prevChapter() = jumpToChapter(_uiState.value.chapterIndex - 1)

    private fun chaptersOf(): List<Chapter> = _uiState.value.chapters

    private companion object {
        const val PROGRESS_THROTTLE_MS = 500L
        /** 章节缓存：章数上限与总字符上限（约 60 万字，约数十 MB 以内） */
        const val MAX_CACHE_CHAPTERS = 10
        const val MAX_CACHE_CHARS = 600_000
    }

    private suspend fun loadChapterInternal(index: Int) {
        val cached = chapterCache[index]
        if (cached != null) {
            _uiState.update { it.copy(blocks = cached, loading = false, canPrev = index > 0, canNext = index < it.chapters.lastIndex) }
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
        putChapter(index, blocks)
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

    /** 目录抽屉与设置面板互斥：同时展开会叠在一起，且点章跳转后应自动收起 */
    fun toggleToc(show: Boolean? = null) = _uiState.update {
        val next = show ?: !it.showToc
        it.copy(showToc = next, showSettings = if (next) false else it.showSettings)
    }

    fun toggleSettings(show: Boolean? = null) = _uiState.update {
        val next = show ?: !it.showSettings
        it.copy(showSettings = next, showToc = if (next) false else it.showToc)
    }

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
        cachedChars = 0
    }
}
