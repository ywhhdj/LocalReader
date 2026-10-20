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
import com.demo.core.model.Book
import com.demo.core.model.BookFilter
import com.demo.core.model.BookType
import com.demo.core.model.SortOrder

import com.demo.domain.usecase.DeleteBooksUseCase
import com.demo.domain.usecase.LoadHomeSectionsUseCase
import com.demo.domain.usecase.LoadShelfPageUseCase
import com.demo.domain.usecase.ObserveSettingsUseCase
import com.demo.domain.usecase.ToggleFavoriteUseCase

data class FavoritesUiState(
    val isLoading: Boolean = true,
    val sections: com.demo.domain.usecase.HomeSections = com.demo.domain.usecase.HomeSections(),
    /** 收藏网格（分页） */
    val favoriteBooks: List<Book> = emptyList(),
    val page: Int = 0,
    val canLoadMore: Boolean = true,
    val typeFilter: BookType? = null,
    val settings: AppSettings = AppSettings(),
    val message: String? = null
)

/**
 * 收藏页：承载「继续阅读 / 最近添加 / 收藏」三类动态区块，
 * 书架页只保留纯网格，避免首页信息过载。
 */
class FavoritesViewModel(
    private val loadHomeSections: LoadHomeSectionsUseCase,
    private val loadShelfPage: LoadShelfPageUseCase,
    private val observeSettings: ObserveSettingsUseCase,
    private val toggleFavorite: ToggleFavoriteUseCase,
    private val deleteBooks: DeleteBooksUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(FavoritesUiState())
    val uiState: StateFlow<FavoritesUiState> = _uiState.asStateFlow()

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
            _uiState.update { it.copy(isLoading = true, page = 0, canLoadMore = true, favoriteBooks = emptyList()) }
            val sections = loadHomeSections()
            _uiState.update { it.copy(sections = sections, isLoading = false) }
            loadPage(0)
        }
    }

    private fun loadPage(page: Int) {
        viewModelScope.launch {
            val books = loadShelfPage(
                groupId = null,
                type = _uiState.value.typeFilter?.value,
                favoriteOnly = true,
                keyword = "",
                sort = SortOrder.LAST_READ,
                page = page,
                pageSize = BookFilter.DEFAULT_PAGE_SIZE
            )
            _uiState.update {
                it.copy(
                    favoriteBooks = if (page == 0) books else it.favoriteBooks + books,
                    page = page,
                    canLoadMore = books.size >= BookFilter.DEFAULT_PAGE_SIZE,
                    isLoading = false
                )
            }
        }
    }

    fun loadMore() {
        val state = _uiState.value
        if (state.isLoading || !state.canLoadMore) return
        loadPage(state.page + 1)
    }

    fun setTypeFilter(type: BookType?) {
        _uiState.update { it.copy(typeFilter = type, page = 0, favoriteBooks = emptyList(), canLoadMore = true) }
        loadPage(0)
    }

    fun unfavorite(bookId: Long) {
        viewModelScope.launch {
            toggleFavorite(listOf(bookId), false)
            _uiState.update { it.copy(message = "已取消收藏") }
            refresh()
        }
    }

    fun delete(bookId: Long) {
        viewModelScope.launch {
            deleteBooks(listOf(bookId))
            _uiState.update { it.copy(message = "已删除") }
            refresh()
        }
    }

    fun consumeMessage() = _uiState.update { it.copy(message = null) }
}
