package com.demo.feature.detail

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.Book
import com.demo.core.model.BookGroup
import com.demo.core.model.BookType
import com.demo.core.model.Chapter

import com.demo.domain.repository.ReaderRepository
import com.demo.domain.repository.chaptersOrSingle
import com.demo.domain.usecase.GetBookUseCase
import com.demo.domain.usecase.MoveToGroupUseCase
import com.demo.domain.usecase.ObserveGroupsUseCase
import com.demo.domain.usecase.ToggleFavoriteUseCase
import com.demo.domain.usecase.DeleteBooksUseCase
import com.demo.domain.usecase.UpdateProgressUseCase

data class DetailUiState(
    val book: Book? = null,
    /** 小说：章节（已补卷）；漫画：话集 */
    val chapters: List<Chapter> = emptyList(),
    val groups: List<BookGroup> = emptyList(),
    val isLoading: Boolean = true,
    val chaptersLoading: Boolean = false,
    val message: String? = null,
    val deleted: Boolean = false
)

class DetailViewModel(
    private val getBook: GetBookUseCase,
    private val observeGroups: ObserveGroupsUseCase,
    private val toggleFavorite: ToggleFavoriteUseCase,
    private val moveToGroup: MoveToGroupUseCase,
    private val deleteBooks: DeleteBooksUseCase,
    private val updateProgress: UpdateProgressUseCase,
    private val readerRepository: ReaderRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(DetailUiState())
    val uiState: StateFlow<DetailUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            observeGroups().collectLatest { groups ->
                _uiState.update { it.copy(groups = groups) }
            }
        }
    }

    /** 目录已加载过的书籍 id，避免重复打开 epub/zip 解析整本目录 */
    private var chaptersLoadedFor: Long = -1L

    /** 由导航参数驱动加载，避免 ViewModel 构造依赖外部参数 */
    fun load(bookId: Long) {
        if (bookId <= 0L) return
        if (bookId == chaptersLoadedFor) return
        chaptersLoadedFor = bookId
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val book = getBook(bookId)
            _uiState.update { it.copy(book = book, isLoading = false) }
            if (book != null) loadChapters(book)
        }
    }

    /** 从阅读器返回后刷新进度 / 收藏等字段（不重复解析目录） */
    fun refresh() {
        val bookId = _uiState.value.book?.id ?: return
        viewModelScope.launch {
            val fresh = getBook(bookId) ?: return@launch
            _uiState.update { it.copy(book = fresh) }
        }
    }

    /**
     * 目录与话集：
     * - 小说：章节列表（补齐分卷，供目录按卷分组显示）；
     * - 漫画：话列表（短篇 / CBZ / PDF 为 1 话，文件夹按子目录分话）。
     */
    private suspend fun loadChapters(book: Book) {
        _uiState.update { it.copy(chaptersLoading = true, chapters = emptyList()) }
        val chapters = runCatching {
            when (book.type) {
                BookType.NOVEL -> readerRepository.openNovel(book).use { content ->
                    VolumeSplitter.apply(content.chapters)
                }
                BookType.COMIC -> readerRepository.openComic(book).use { content ->
                    content.chaptersOrSingle().map { chapter ->
                        Chapter(
                            index = chapter.index,
                            title = if (chapter.pageCount > 0) {
                                "${chapter.title}（${chapter.pageCount} 页）"
                            } else chapter.title
                        )
                    }
                }
            }
        }.getOrDefault(emptyList())
        _uiState.update { it.copy(chapters = chapters, chaptersLoading = false) }
    }

    fun toggleFavorite() {
        val book = _uiState.value.book ?: return
        viewModelScope.launch {
            toggleFavorite.invoke(listOf(book.id), !book.favorite)
            _uiState.update { it.copy(book = book.copy(favorite = !book.favorite)) }
        }
    }

    fun moveToGroup(groupId: Long?) {
        val book = _uiState.value.book ?: return
        viewModelScope.launch {
            moveToGroup.invoke(listOf(book.id), groupId)
            _uiState.update { it.copy(book = book.copy(groupId = groupId), message = "已移动分组") }
        }
    }

    fun markFinished() {
        val book = _uiState.value.book ?: return
        viewModelScope.launch {
            updateProgress(book.id, 1f)
            _uiState.update { it.copy(book = book.copy(progress = 1f), message = "已标记为读完") }
        }
    }

    fun resetProgress() {
        val book = _uiState.value.book ?: return
        viewModelScope.launch {
            updateProgress(book.id, 0f)
            _uiState.update { it.copy(book = book.copy(progress = 0f), message = "已重置进度") }
        }
    }

    fun delete() {
        val book = _uiState.value.book ?: return
        viewModelScope.launch {
            deleteBooks(listOf(book.id))
            _uiState.update { it.copy(deleted = true) }
        }
    }

    fun consumeMessage() = _uiState.update { it.copy(message = null) }
}
