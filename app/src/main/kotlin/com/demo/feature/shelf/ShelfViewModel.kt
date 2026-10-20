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
import com.demo.core.model.BookGroup
import com.demo.core.model.BookType
import com.demo.core.model.BuiltInGroup
import com.demo.core.model.SortOrder
import com.demo.core.model.ThemeMode

import com.demo.domain.repository.ScanProgress
import com.demo.domain.usecase.CreateGroupUseCase
import com.demo.domain.usecase.DeleteBooksUseCase
import com.demo.domain.usecase.ImportBooksUseCase
import com.demo.domain.usecase.LoadHomeSectionsUseCase
import com.demo.domain.usecase.LoadShelfPageUseCase
import com.demo.domain.usecase.MoveToGroupUseCase
import com.demo.domain.usecase.ObserveGroupsUseCase
import com.demo.domain.usecase.ObserveSettingsUseCase
import com.demo.domain.usecase.SearchBooksUseCase
import com.demo.domain.usecase.ToggleFavoriteUseCase
import com.demo.domain.usecase.UpdateSettingsUseCase

data class ShelfUiState(
    val isLoading: Boolean = true,
    val sections: com.demo.domain.usecase.HomeSections = com.demo.domain.usecase.HomeSections(),
    val groups: List<BookGroup> = emptyList(),
    val selectedGroupId: Long = BuiltInGroup.ALL,
    val typeFilter: BookType? = null,
    val sortOrder: SortOrder = SortOrder.LAST_READ,
    val gridBooks: List<Book> = emptyList(),
    val page: Int = 0,
    val canLoadMore: Boolean = true,
    val refreshing: Boolean = false,
    val keyword: String = "",
    val searchResults: List<Book> = emptyList(),
    val scan: ScanProgress? = null,
    val selection: Set<Long> = emptySet(),
    val settings: AppSettings = AppSettings(),
    val message: String? = null
) {
    /** 是否有非默认筛选（用于筛选图标高亮） */
    val filterActive: Boolean get() = typeFilter != null || sortOrder != SortOrder.LAST_READ
}

class ShelfViewModel(
    private val loadHomeSections: LoadHomeSectionsUseCase,
    private val loadShelfPage: LoadShelfPageUseCase,
    private val observeGroups: ObserveGroupsUseCase,
    private val observeSettings: ObserveSettingsUseCase,
    private val updateSettings: UpdateSettingsUseCase,
    private val searchBooks: SearchBooksUseCase,
    private val importBooks: ImportBooksUseCase,
    private val createGroup: CreateGroupUseCase,
    private val toggleFavorite: ToggleFavoriteUseCase,
    private val moveToGroup: MoveToGroupUseCase,
    private val deleteBooks: DeleteBooksUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(ShelfUiState())
    val uiState: StateFlow<ShelfUiState> = _uiState.asStateFlow()

    private var importJob: kotlinx.coroutines.Job? = null

    init {
        viewModelScope.launch {
            observeGroups().collectLatest { groups ->
                _uiState.update { it.copy(groups = BuiltInGroup.builtIns() + groups) }
            }
        }
        viewModelScope.launch {
            observeSettings().collectLatest { settings ->
                _uiState.update { it.copy(settings = settings) }
            }
        }
        refresh()
    }

    /**
     * 刷新：书架页只加载网格。
     * 「继续阅读 / 最近添加 / 收藏」已迁到收藏页，这里不再查询三张区块，省掉 3 次聚合查询。
     */
    fun refresh() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, page = 0, canLoadMore = true, gridBooks = emptyList()) }
            loadPage(0)
        }
    }

    private suspend fun filtersFor(state: ShelfUiState): Triple<Long?, BookType?, Boolean> = when (state.selectedGroupId) {
        BuiltInGroup.ALL -> Triple(null, state.typeFilter, false)
        BuiltInGroup.NOVEL -> Triple(null, BookType.NOVEL, false)
        BuiltInGroup.COMIC -> Triple(null, BookType.COMIC, false)
        BuiltInGroup.FAVORITE -> Triple(null, state.typeFilter, true)
        else -> Triple(state.selectedGroupId, state.typeFilter, false)
    }

    fun loadPage(page: Int) {
        viewModelScope.launch {
            val state = _uiState.value
            val (groupId, type, fav) = filtersFor(state)
            val books = loadShelfPage(
                groupId = groupId,
                type = type?.value,
                favoriteOnly = fav,
                keyword = "",
                sort = state.sortOrder,
                page = page,
                pageSize = BookFilter.DEFAULT_PAGE_SIZE
            )
            _uiState.update {
                it.copy(
                    gridBooks = if (page == 0) books else it.gridBooks + books,
                    page = page,
                    canLoadMore = books.size >= BookFilter.DEFAULT_PAGE_SIZE,
                    isLoading = false,
                    refreshing = false
                )
            }
        }
    }

    fun loadMore() {
        val state = _uiState.value
        if (state.isLoading || !state.canLoadMore) return
        loadPage(state.page + 1)
    }

    fun selectGroup(groupId: Long) {
        _uiState.update {
            it.copy(selectedGroupId = groupId, page = 0, gridBooks = emptyList(), canLoadMore = true)
        }
        loadPage(0)
    }

    fun setTypeFilter(type: BookType?) {
        _uiState.update {
            it.copy(typeFilter = type, page = 0, gridBooks = emptyList(), canLoadMore = true)
        }
        loadPage(0)
    }

    fun setSortOrder(order: SortOrder) {
        if (order == _uiState.value.sortOrder) return
        _uiState.update {
            it.copy(sortOrder = order, page = 0, gridBooks = emptyList(), canLoadMore = true)
        }
        loadPage(0)
    }

    fun search(keyword: String) {
        _uiState.update { it.copy(keyword = keyword) }
        viewModelScope.launch {
            if (keyword.isBlank()) {
                _uiState.update { it.copy(searchResults = emptyList()) }
                return@launch
            }
            kotlinx.coroutines.delay(300)
            val results = searchBooks(keyword, 100)
            _uiState.update { it.copy(searchResults = results) }
        }
    }

    fun import(paths: List<String>) {
        importJob?.cancel()
        importJob = viewModelScope.launch {
            importBooks.raw(paths).collect { progress ->
                _uiState.update { it.copy(scan = progress) }
                if (progress.done) {
                    refresh()
                    _uiState.update {
                        it.copy(
                            message = progress.message?.let { m -> "导入完成：$m" }
                                ?: "导入完成：新增 ${progress.imported}，跳过 ${progress.skipped}，失败 ${progress.failed}",
                            scan = null
                        )
                    }
                }
            }
        }
    }

    fun cancelImport() {
        importJob?.cancel()
        _uiState.update { it.copy(scan = null) }
    }

    fun toggleTheme() {
        viewModelScope.launch {
            val current = _uiState.value.settings.themeMode
            val next = when (current) {
                ThemeMode.SYSTEM -> ThemeMode.LIGHT
                ThemeMode.LIGHT -> ThemeMode.DARK
                ThemeMode.DARK -> ThemeMode.SYSTEM
            }
            updateSettings { it.copy(themeMode = next) }
        }
    }

    fun enterSelection(id: Long) = _uiState.update { it.copy(selection = it.selection + id) }

    fun toggleSelection(id: Long) = _uiState.update {
        val next = if (id in it.selection) it.selection - id else it.selection + id
        it.copy(selection = next)
    }

    fun clearSelection() = _uiState.update { it.copy(selection = emptySet()) }

    fun favoriteSelection(favorite: Boolean) {
        val ids = _uiState.value.selection.toList()
        if (ids.isEmpty()) return
        viewModelScope.launch {
            toggleFavorite(ids, favorite)
            clearSelection()
            refresh()
        }
    }

    fun moveSelectionToGroup(groupId: Long?) {
        val ids = _uiState.value.selection.toList()
        if (ids.isEmpty()) return
        viewModelScope.launch {
            moveToGroup(ids, groupId)
            clearSelection()
            refresh()
        }
    }

    fun deleteSelection() {
        val ids = _uiState.value.selection.toList()
        if (ids.isEmpty()) return
        viewModelScope.launch {
            deleteBooks(ids)
            clearSelection()
            refresh()
        }
    }

    fun createGroupByName(name: String) {
        if (name.isBlank()) return
        viewModelScope.launch {
            val id = createGroup(name)
            _uiState.update {
                it.copy(message = if (id > 0) "已创建分组：$name" else "分组已存在")
            }
        }
    }

    /** SAF 授权目录：持久化后扫描（Android 11+ 无所有文件权限时的主要入口） */
    fun importFromUri(uri: String) {
        viewModelScope.launch {
            addScanDir(uri)
            import(listOf(uri))
        }
    }

    fun addScanDir(raw: String) {
        if (raw.isBlank()) return
        viewModelScope.launch {
            updateSettings { s ->
                if (raw in s.scanDirs) s else s.copy(scanDirs = (listOf(raw) + s.scanDirs).distinct().take(20))
            }
        }
    }

    fun removeScanDir(raw: String) {
        viewModelScope.launch {
            updateSettings { s -> s.copy(scanDirs = s.scanDirs - raw) }
        }
    }

    fun rescanAll() {
        val dirs = _uiState.value.settings.scanDirs
        if (dirs.isEmpty()) {
            _uiState.update { it.copy(message = "还没有保存的扫描目录，请先添加") }
            return
        }
        import(dirs)
    }

    fun consumeMessage() = _uiState.update { it.copy(message = null) }
}
