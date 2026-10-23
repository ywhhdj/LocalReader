package com.demo.feature.reader.novel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

import com.demo.core.common.util.MemoryPressure
import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.AppSettings
import com.demo.core.model.Book
import com.demo.core.model.BookBlock
import com.demo.core.model.BookType
import com.demo.core.model.Chapter
import com.demo.core.model.TtsState
import com.demo.core.model.TtsTimbre
import com.demo.core.model.TtsVoice

import com.demo.domain.repository.NovelContent
import com.demo.domain.repository.ProgressRepository
import com.demo.domain.repository.ReaderRepository
import com.demo.domain.repository.SettingsRepository
import com.demo.domain.repository.TtsRepository

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
    val tts: TtsState = TtsState(),
    /** 朗读会话是否激活：开始朗读后置 true，点击关闭后回到 false（暂停期间也保持 true，进度球不消失） */
    val ttsActive: Boolean = false,
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
    private val ttsRepository: TtsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(NovelReaderUiState())
    val uiState: StateFlow<NovelReaderUiState> = _uiState.asStateFlow()

    /** 朗读进度 0f..1f（关闭朗读时清零） */
    private val _ttsProgress = MutableStateFlow(0f)
    val ttsProgress: StateFlow<Float> = _ttsProgress.asStateFlow()

    /**
     * 系统语音列表。
     * 引擎初始化是异步的，组合期同步取列表一定取不到（表现为"点了选择没有列表"），
     * 改为 StateFlow：进页面就异步拉一次，就绪后自动刷新。
     */
    private val _ttsVoices = MutableStateFlow<List<TtsVoice>>(emptyList())
    val ttsVoices: StateFlow<List<TtsVoice>> = _ttsVoices.asStateFlow()

    private var content: NovelContent? = null
    private var sessionId: Long = 0L
    private var sessionStartAt: Long = 0L
    private var bookId: Long = 0L

    /** 内存紧张时释放章节缓存的订阅；onCleared 里取消注册 */
    private var unregisterMemoryPressure: (() -> Unit)? = null

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
        // 进入阅读器即预热引擎并拉取语音列表，避免打开听读设置时才初始化（列表为空）
        ttsRepository.prewarm()
        refreshTtsVoices()
        // 内存紧张时优先让出可再生的章节缓存（当前页 blocks 仍在 UI state 里，不影响阅读）
        unregisterMemoryPressure = MemoryPressure.register {
            chapterCache.clear()
            cachedChars = 0
        }
        viewModelScope.launch {
            settingsRepository.observe().collectLatest { settings ->
                _uiState.update { it.copy(settings = settings) }
                ttsRepository.setRate(settings.ttsRate)
                ttsRepository.setPitch(settings.ttsPitch)
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
            ttsRepository.state.collectLatest { tts ->
                val finished = wasSpeaking && !tts.speaking &&
                    tts.chunkCount > 0 && tts.chunkIndex >= tts.chunkCount
                wasSpeaking = tts.speaking
                _uiState.update { it.copy(tts = tts) }
                // 环形进度：按已读句数折算；句数未知时回落 0，避免显示成 100%
                _ttsProgress.value =
                    if (tts.chunkCount > 0) (tts.chunkIndex.toFloat() / tts.chunkCount).coerceIn(0f, 1f)
                    else 0f
                if (finished && _uiState.value.settings.ttsAutoNext && _uiState.value.canNext) {
                    nextChapter()
                    // 等待新章节内容渲染完成后再继续朗读
                    var waited = 0
                    while (_uiState.value.loading && waited < 5000) {
                        delay(120)
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
                // 预热 TTS 引擎：避免首次点击「朗读」时才初始化导致卡顿
                ttsRepository.prewarm()
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
        viewModelScope.launch {
            loadChapterInternal(index)
        }
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
            _uiState.update {
                it.copy(
                    blocks = cached,
                    loading = false,
                    canPrev = index > 0,
                    canNext = index < it.chapters.lastIndex
                )
            }
            return
        }
        _uiState.update { it.copy(loading = true) }
        val opened = content ?: run {
            val book = _uiState.value.book ?: return
            openNovel(book).also { content = it }
        }
        // 章节解析（读文件 / 解 zip）走 IO 线程
        // 大章节会阻塞排版造成切章掉帧甚至 ANR。
        val raw = withContext(Dispatchers.IO) {
            runCatching { opened.loadChapter(index) }
                .getOrDefault(listOf(BookBlock.Paragraph("（章节加载失败）")))
        }
        // 双保险：解析器已去掉重复标题行，这里再兜一层（含卷名写法）。
        // 顺序很重要：必须先按行拆块再剥标题 ——
        // TXT 里"标题行 + 正文"常合成一个段落，拆开后标题才是一整块，能被精确去掉。
        val chapter = chaptersOf().getOrNull(index)
        val blocks = splitParagraphLines(raw).let { split ->
            if (chapter == null) split
            else VolumeSplitter.peelLeadingTitles(
                split,
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
        viewModelScope.launch {
            val text = withContext(Dispatchers.Default) {
                buildString {
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
            }
            ttsRepository.setRate(_uiState.value.settings.ttsRate)
            ttsRepository.setPitch(_uiState.value.settings.ttsPitch)
            ttsRepository.speak(text)
        }
    }

    /** 悬浮球入口：开始朗读当前章节 */
    fun startTtsFromFab() {
        _uiState.update { it.copy(ttsActive = true) }
        startTts()
    }

    /** 暂停（系统 TTS 无 pause，内部以 stop + 记录句位实现） */
    fun pauseTts() = ttsRepository.pause()

    /** 从暂停处继续 */
    fun resumeTts() = ttsRepository.resume()

    /**
     * 结束朗读并清空进度：回到右下角「朗读」悬浮球。
     * 与 [stopTts] 的区别是会额外把播放位置清零（关闭按钮用这个）。
     */
    fun cancelTts() {
        ttsRepository.stop()
        _ttsProgress.value = 0f
        _uiState.update {
            it.copy(ttsActive = false, tts = TtsState(available = it.tts.available))
        }
    }

    fun stopTts() = ttsRepository.stop()

    fun setTtsRate(rate: Float) {
        ttsRepository.setRate(rate)
        updateSettings { it.copy(ttsRate = rate) }
    }

    fun setTtsPitch(pitch: Float) {
        ttsRepository.setPitch(pitch)
        updateSettings {
            it.copy(ttsPitch = pitch)
        }
    }

    /** 音色预设：落到音调 + 语速并持久化（不下载任何语音包） */
    fun setTtsTimbre(timbre: TtsTimbre) {
        ttsRepository.setPitch(timbre.pitch)
        ttsRepository.setRate(timbre.rate)
        updateSettings {
            it.copy(ttsTimbre = timbre, ttsPitch = timbre.pitch, ttsRate = timbre.rate)
        }
    }

    /** 打开系统「文字转语音」设置（用户在那里下载语音包） */
    fun openSystemTtsSettings() = ttsRepository.openSystemSettings()

    fun launchTtsSettings() = ttsRepository.launchTtsSettings()

    /** 系统语音列表：异步读取，引擎就绪后写入 [ttsVoices] */
    fun refreshTtsVoices() {
        viewModelScope.launch {
            _ttsVoices.value = runCatching {
                ttsRepository.availableVoices()
            }.getOrDefault(emptyList())
        }
    }

    /** 选择系统语音 */
    fun setTtsVoice(name: String) {
        ttsRepository.setVoice(name)
        updateSettings { it.copy(ttsVoiceName = name) }
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
        viewModelScope.launch {
            settingsRepository.update(transform)
        }
    }

    /** 退出前强制落盘最近一次滚动位置（走 flushScope，viewModelScope 此时已取消） */
    fun flushProgress() {
        val state = _uiState.value
        if (state.chapters.isEmpty() || bookId <= 0L) return
        val progress = ((state.chapterIndex + 1).toFloat() / state.chapters.size).coerceAtMost(1f)
        flushScope.launch {
            runCatching {
                progressRepository.saveNovel(bookId, state.chapterIndex, 0, progress)
            }
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
        unregisterMemoryPressure?.invoke()
        unregisterMemoryPressure = null
        runCatching { ttsRepository.stop() }
        flushProgress()
        flushScope.launch {
            runCatching {
                session.end(sessionId, sessionStartAt, BookType.NOVEL)
            }
        }
        content?.close()
        content = null
        chapterCache.clear()
        cachedChars = 0
    }
}