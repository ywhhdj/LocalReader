package com.demo.feature.detail

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

import com.demo.core.model.Book
import com.demo.core.model.BookGroup
import com.demo.core.model.Chapter

import com.demo.domain.repository.ReaderRepository
import com.demo.domain.usecase.GetBookUseCase
import com.demo.domain.usecase.MoveToGroupUseCase
import com.demo.domain.usecase.ObserveGroupsUseCase
import com.demo.domain.usecase.ToggleFavoriteUseCase
import com.demo.domain.usecase.DeleteBooksUseCase
import com.demo.domain.usecase.UpdateProgressUseCase

data class DetailUiState(
    val book: Book? = null,
    val chapters: List<Chapter> = emptyList(),
    val groups: List<BookGroup> = emptyList(),
    val isLoading: Boolean = true,
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

    /** 由导航参数驱动加载，避免 ViewModel 构造依赖外部参数 */
    fun load(bookId: Long,chapter: Int?) {
        if (bookId <= 0L || _uiState.value.book?.id == bookId) return
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val book = getBook(bookId)
            _uiState.update { it.copy(book = book, isLoading = false) }
            if (book != null) loadChapters(book)
        }
    }

    private suspend fun loadChapters(book: Book) {
        if (book.type != com.demo.core.model.BookType.NOVEL) return
        runCatching {
            readerRepository.openNovel(book).use { content ->
                _uiState.update { it.copy(chapters = content.chapters) }
            }
        }
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
