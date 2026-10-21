package com.demo.feature.reader.comic

import android.graphics.BitmapFactory
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

import com.demo.core.common.util.Logger
import com.demo.core.model.AppSettings
import com.demo.core.model.Book
import com.demo.core.model.BookType
import com.demo.core.model.ComicChapter
import com.demo.core.model.ComicPage
import com.demo.domain.repository.ComicContent
import com.demo.domain.repository.ProgressRepository
import com.demo.domain.repository.SettingsRepository
import com.demo.domain.repository.chapterOf
import com.demo.domain.repository.chaptersOrSingle
import com.demo.domain.usecase.GetBookUseCase
import com.demo.domain.usecase.OpenComicUseCase
import com.demo.domain.usecase.ReadingSessionUseCase

/** 请求 UI 滚动到指定页（每次切话/跳转生成新的 token） */
data class PageScrollRequest(val index: Int, val token: Long)

data class ComicReaderUiState(
    val book: Book? = null,
    /** 整本页列表（进度与页码按整本计） */
    val pages: List<ComicPage> = emptyList(),
    val pageIndex: Int = 0,
    /** 话列表（短篇/CBZ/PDF 为 1 话） */
    val chapters: List<ComicChapter> = emptyList(),
    val chapterIndex: Int = 0,
    val loading: Boolean = true,
    val settings: AppSettings = AppSettings(),
    val showOverlay: Boolean = true,
    val error: String? = null
) {
    /** 当前话的页区间（闭区间） */
    val chapterRange: IntRange
        get() {
            val chapter = chapters.getOrNull(chapterIndex) ?: return 0..pages.lastIndex.coerceAtLeast(0)
            return chapter.startIndex..chapter.endIndex.coerceAtMost(pages.lastIndex.coerceAtLeast(0))
        }
    val hasNextChapter: Boolean get() = chapterIndex < chapters.lastIndex
    val hasPrevChapter: Boolean get() = chapterIndex > 0
}

/**
 * 漫画阅读（v1.1：竖向连续滚动 + 分话）
 *
 * - 话：图片文件夹按「第一话/第二话」子目录切分，短篇与 CBZ/PDF 视为 1 话；
 * - 加载：仅解析当前话内、以当前页为中心的窗口（±preload），窗口外从内存释放；
 * - 进度：滚动位置节流 400ms 合并写库，退出时强制写一次；
 * - 方向：固定竖向，不再支持横向 Pager 与双页。
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

    private var scrollToken = 0L
    private val _scrollRequest = MutableStateFlow<PageScrollRequest?>(null)
    val scrollRequest: StateFlow<PageScrollRequest?> = _scrollRequest.asStateFlow()

    /** index -> 本地缓存路径，仅保留窗口内 */
    private val resolved = HashMap<Int, String>()
    private val pagePaths = MutableStateFlow<Map<Int, String>>(emptyMap())
    val paths: StateFlow<Map<Int, String>> = pagePaths.asStateFlow()

    /** index -> 宽高比（未解码时按此比例占位，避免图片到位后跳动） */
    private val aspectMap = HashMap<Int, Float>()
    private val pageAspectsState = MutableStateFlow<Map<Int, Float>>(emptyMap())
    val pageAspects: StateFlow<Map<Int, Float>> = pageAspectsState.asStateFlow()

    private var content: ComicContent? = null
    private var sessionId: Long = 0L
    private var sessionStartAt: Long = 0L
    private var bookId: Long = 0L
    private var preload: Int = 2

    private var windowJob: Job? = null
    private var windowFrom = -1
    private var windowTo = -1

    /** 滚动位置 → 节流写库 */
    private val pendingProgress = MutableSharedFlow<Int>(extraBufferCapacity = 4)

    /**
     * 独立于 viewModelScope 的收尾作用域：
     * ViewModel 被清理时 viewModelScope 已取消，若仍用它写库，阅读会话与进度会丢失。
     */
    private val flushScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    init {
        viewModelScope.launch {
            settingsRepository.observe().collectLatest { settings ->
                preload = settings.comicPreload.coerceIn(4, 6)
                _uiState.update { it.copy(settings = settings) }
            }
        }
        viewModelScope.launch {
            pendingProgress.collectLatest { index ->
                delay(PROGRESS_THROTTLE_MS)
                commitProgress(index)
            }
        }
    }

    fun load(id: Long, startChapter: Int? = null) {
        if (id <= 0L) return
        // 同一本书未指定章节的重复调用忽略；指定了章节允许重新定位
        if (id == bookId && startChapter == null) return
        bookId = id
        viewModelScope.launch {
            _uiState.update { it.copy(loading = true, error = null) }
            runCatching {
                val book = getBook(id) ?: return@launch
                val opened = openComic(book)
                content?.close()
                content = opened
                val chapters = opened.chaptersOrSingle()
                val progress = progressRepository.get(id)

                val targetIndex = if (startChapter != null && startChapter in chapters.indices) {
                    chapters[startChapter].startIndex
                } else {
                    progress?.pageIndex ?: 0
                }
                val index = targetIndex.coerceIn(0, opened.pages.lastIndex.coerceAtLeast(0))
                val chapterIndex = opened.chapterOf(index)?.index ?: 0

                _uiState.update {
                    it.copy(
                        book = book,
                        pages = opened.pages,
                        chapters = chapters,
                        chapterIndex = chapterIndex,
                        pageIndex = index,
                        loading = false
                    )
                }
                sessionId = session.start(book.id, BookType.COMIC)
                sessionStartAt = System.currentTimeMillis()
                ensureWindow(index)
                _scrollRequest.value = PageScrollRequest(index, ++scrollToken)
            }.onFailure { e ->
                Logger.w("漫画打开失败：${e.message}", "ComicReaderViewModel")
                _uiState.update { it.copy(loading = false, error = e.message ?: "打开失败") }
            }
        }
    }

    /**
     * 滚动驱动：只更新页位置与进度。
     * 话归属不随滚动变化（避免切话瞬间用旧的滚动下标把话跳回去），
     * 切换话只通过 [selectChapter] / [nextChapter] / [jumpToPage]。
     */
    fun onPageChanged(index: Int) {
        val state = _uiState.value
        val last = state.pages.lastIndex.coerceAtLeast(0)
        val safe = index.coerceIn(0, last)
        if (safe == state.pageIndex) return
        _uiState.update { it.copy(pageIndex = safe) }
        ensureWindow(safe)
        pendingProgress.tryEmit(safe)
    }

    /** 选择话：跳到该话首页并滚动到顶部 */
    fun selectChapter(index: Int) {
        val state = _uiState.value
        val chapter = state.chapters.getOrNull(index) ?: return
        val target = chapter.startIndex.coerceIn(0, state.pages.lastIndex.coerceAtLeast(0))
        _uiState.update { it.copy(chapterIndex = index, pageIndex = target) }
        ensureWindow(target)
        _scrollRequest.value = PageScrollRequest(target, ++scrollToken)
        viewModelScope.launch { commitProgress(target) }
    }

    /** 进入下一话（最后一话时无动作，由 UI 判断显隐） */
    fun nextChapter() = selectChapter(_uiState.value.chapterIndex + 1)

    fun prevChapter() = selectChapter(_uiState.value.chapterIndex - 1)

    /** 跳转到指定页（进度条拖动） */
    fun jumpToPage(index: Int) {
        val state = _uiState.value
        val last = state.pages.lastIndex
        if (last < 0) return
        val safe = index.coerceIn(0, last)
        val chapterIndex = state.chapters.firstOrNull { 
            it.contains(safe) 
        }?.index ?: state.chapterIndex
        _uiState.update { it.copy(pageIndex = safe, chapterIndex = chapterIndex) }
        ensureWindow(safe)
        _scrollRequest.value = PageScrollRequest(safe, ++scrollToken)
        viewModelScope.launch { commitProgress(safe) }
    }

    /** 相对翻页（音量键等） */
    fun stepPage(delta: Int) = jumpToPage(_uiState.value.pageIndex + delta)

    private suspend fun commitProgress(index: Int) {
        val total = _uiState.value.pages.size
        if (total <= 0 || bookId <= 0L) return
        val progress = (((index + 1).toFloat() / total)+0.05f).coerceIn(0f, 1f)
        runCatching { progressRepository.saveComic(bookId, index, total, progress) }
    }

    /** 仅保留窗口内的解析结果，窗口外从内存移除（磁盘缓存保留） */
    private fun ensureWindow(center: Int) {
        val state = _uiState.value
        val chapter = state.chapters.getOrNull(state.chapterIndex)
        // 窗口限制在当前话内：切话时不会顺带解码上一话的尾部
        val min = chapter?.startIndex ?: 0
        val max = (chapter?.endIndex ?: state.pages.lastIndex).coerceAtMost(state.pages.lastIndex)
        val from = (center - preload).coerceAtLeast(min).coerceAtLeast(0)
        val to = (center + preload).coerceAtMost(max)
        if (from > to) return
        if (from == windowFrom && to == windowTo) return
        windowFrom = from
        windowTo = to

        resolved.keys.toList().filter { it !in from..to }.forEach { resolved.remove(it) }
        // 宽高比保留更宽的范围（±ASPECT_KEEP），回滚少量页时占位高度仍然准确
        val keepFrom = (center - ASPECT_KEEP).coerceAtLeast(0)
        val keepTo = center + ASPECT_KEEP
        aspectMap.keys.toList().filter { it !in keepFrom..keepTo }.forEach { aspectMap.remove(it) }
        pagePaths.value = resolved.toMap()
        pageAspectsState.value = aspectMap.toMap()

        windowJob?.cancel()
        windowJob = viewModelScope.launch {
            for (i in from..to) {
                if (resolved.containsKey(i)) continue
                val path = runCatching { content?.resolvePage(i) }.getOrNull()
                if (path != null) {
                    // 先量出宽高比再发布路径：占位与最终图片高度一致，滚动不跳动
                    val ratio = runCatching { readAspect(path) }.getOrDefault(0f)
                    if (ratio > 0f) {
                        aspectMap[i] = ratio
                        pageAspectsState.value = aspectMap.toMap()
                    }
                    resolved[i] = path
                    pagePaths.value = resolved.toMap()
                }
            }
        }
    }

    /** 读取图片宽高比（只解头部，不占内存） */
    private fun readAspect(path: String): Float {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, options)
        val w = options.outWidth
        val h = options.outHeight
        return if (w > 0 && h > 0) w.toFloat() / h.toFloat() else 0f
    }

    fun toggleOverlay() = _uiState.update { it.copy(showOverlay = !it.showOverlay) }

    fun updateSettings(transform: (AppSettings) -> AppSettings) {
        viewModelScope.launch { settingsRepository.update(transform) }
    }

    override fun onCleared() {
        super.onCleared()
        windowJob?.cancel()
        val lastIndex = _uiState.value.pageIndex
        flushScope.launch {
            runCatching { commitProgress(lastIndex) }
            runCatching { session.end(sessionId, sessionStartAt, BookType.COMIC) }
        }
        content?.close()
        content = null
        resolved.clear()
        pagePaths.value = emptyMap()
        aspectMap.clear()
        pageAspectsState.value = emptyMap()
    }

    private companion object {
        const val PROGRESS_THROTTLE_MS = 400L
        /** 宽高比保留范围（页数），超出即从内存移除 */
        const val ASPECT_KEEP = 40
    }
}
