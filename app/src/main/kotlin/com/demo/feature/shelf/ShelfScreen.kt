package com.demo.feature.shelf

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.automirrored.filled.ViewList
import androidx.compose.material.icons.filled.ViewModule
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import coil.compose.AsyncImage
import coil.request.ImageRequest

import com.demo.core.model.Book
import com.demo.core.model.BookType
import com.demo.core.model.GridMode
import com.demo.core.model.SortOrder
import com.demo.core.model.ThemeMode
import com.demo.core.ui.components.AppBackdrop
import com.demo.core.ui.components.BookCoverCard
import com.demo.core.ui.components.EmptyState
import com.demo.core.ui.components.GlassSearchBar
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.glass.GlassTopBar
import com.demo.core.ui.theme.CoverPlaceholderA
import com.demo.core.ui.theme.CoverPlaceholderB
import com.demo.core.ui.theme.ReaderShapes
import com.demo.domain.repository.ScanProgress
import com.demo.feature.shelf.FilterIconButton
import com.demo.core.ui.components.AppBookListCard
import com.demo.core.ui.components.AppChipRow
import com.demo.core.ui.components.AppLoading
import com.demo.core.ui.glass.GlassIconButton

import kotlinx.coroutines.launch

@Composable
fun ShelfScreen(
    viewModel: ShelfViewModel,
    onBookClick: (Long) -> Unit,
    onSearch: () -> Unit,
    onSettings: () -> Unit,
    onPickDirectory: () -> Unit = {},
    onRequestPermission: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val darkNow = isDarkTheme(state.settings.themeMode)
    val gridState = rememberLazyGridState()
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var showImportDialog by remember { mutableStateOf(false) }
    var showCreateGroupDialog by remember { mutableStateOf(false) }
    var showFilterSheet by remember { mutableStateOf(false) }

    val scrolled by remember {
        derivedStateOf { gridState.firstVisibleItemIndex > 0 || gridState.firstVisibleItemScrollOffset > 8 }
    }

    val needLoadMore by remember {
        derivedStateOf {
            val last = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            last >= state.gridBooks.size - 8 && state.gridBooks.isNotEmpty()
        }
    }
    LaunchedEffect(needLoadMore, state.gridBooks.size, state.canLoadMore) {
        if (needLoadMore) viewModel.loadMore()
    }

    LaunchedEffect(state.message) {
        val msg = state.message ?: return@LaunchedEffect
        snackbarHostState.showSnackbar(msg)
        viewModel.consumeMessage()
    }

    Box(modifier = modifier.fillMaxSize()) {
        AppBackdrop {
            Column(Modifier.fillMaxSize()) {
                GlassTopBar(
                    scrolled = scrolled,
                    title = {
                        GlassSearchBar(
                            hint = "搜索书名 / 作者",
                            onClick = onSearch,
                            modifier = Modifier.fillMaxWidth()
                        )
                    },
                    actions = {
                        TopBarActions(
                            darkNow = darkNow,
                            onToggleTheme = {  viewModel.toggleTheme(darkNow) },
                            onSettings = onSettings
                        )
                    }
                )

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(end = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    GroupChips(
                        groups = state.groups,
                        selectedId = state.selectedGroupId,
                        onSelect = viewModel::selectGroup,
                        onCreate = { showCreateGroupDialog = true },
                        onFilter = { showFilterSheet = true },
                        filterActive = state.filterActive,
                        modifier = Modifier.weight(1f)
                    )
                    // 新增：网格模式切换按钮（位于筛选左侧）
                    GridModeButton(
                        mode = state.gridMode,
                        onSelect = viewModel::setGridMode
                    )
                    FilterIconButton(
                        active = state.filterActive,
                        onClick = { showFilterSheet = true }
                    )
                }

                if (state.selection.isNotEmpty()) {
                    SelectionBar(
                        count = state.selection.size,
                        onFavorite = { viewModel.favoriteSelection(true) },
                        onDelete = { viewModel.deleteSelection() },
                        onCancel = viewModel::clearSelection
                    )
                }

                LazyVerticalGrid(
                    // ★ 列数跟随 gridMode
                    columns = when (state.gridMode) {
                        GridMode.TWO -> GridCells.Fixed(2)
                        GridMode.THREE -> GridCells.Fixed(3)
                        GridMode.LIST -> GridCells.Fixed(1)
                    },
                    state = gridState,
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 96.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxSize()
                ) {
                    if (state.isLoading && state.gridBooks.isEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }) { AppLoading() }
                    }

                    if (state.gridBooks.isEmpty() && !state.isLoading) {
                        item(span = { GridItemSpan(maxLineSpan) }) {
                            EmptyState(
                                message = "这个分组还没有书，试试导入或切换分组",
                                actionText = "导入书籍",
                                onAction = { showImportDialog = true }
                            )
                        }
                    }

                    items(
                        state.gridBooks,
                        key = { it.id },
                        // 列表卡片与封面卡片结构不同，分开 contentType 才能正确复用
                        contentType = { if (state.gridMode == GridMode.LIST) "book_row" else "book_grid" }
                    ) { book ->
                        if (state.gridMode == GridMode.LIST) {
                            // 详细列表用横向行卡片
                            AppBookListCard(
                                book = book,
                                selected = book.id in state.selection,
                                onClick = { onBookClick(book.id) },
                                onLongClick = { viewModel.toggleSelection(book.id) }
                            )
                        } else {
                            BookCoverCard(
                                book = book,
                                selected = book.id in state.selection,
                                onClick = { onBookClick(book.id) },
                                onLongClick = { viewModel.toggleSelection(book.id) }
                            )
                        }
                    }
                }
            }
        }

        // 悬浮导入按钮
        GlassIconButton(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 5.dp, bottom = 65.dp)
                .navigationBarsPadding(),
            size = 56.dp,
            onClick = { showImportDialog = true }
        ) {
            Icon(
                imageVector = Icons.Default.Add,
                contentDescription = "导入",
                tint = MaterialTheme.colorScheme.primary
            )
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
        )

        state.scan?.let { progress ->
            ScanProgressCard(
                progress = progress,
                onCancel = viewModel::cancelImport,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(16.dp)
                    .navigationBarsPadding()
            )
        }
    }

    if (showImportDialog) {
        ImportDialog(
            savedDirs = state.settings.scanDirs,
            onDismiss = { showImportDialog = false },
            onImport = { paths ->
                showImportDialog = false
                viewModel.addScanDir(paths.firstOrNull().orEmpty())
                viewModel.import(paths)
            },
            onPickDirectory = {
                showImportDialog = false
                onPickDirectory()
            },
            onRequestPermission = onRequestPermission,
            onRemoveDir = viewModel::removeScanDir
        )
    }

    if (showFilterSheet) {
        FilterSheet(
            typeFilter = state.typeFilter,
            sortOrder = state.sortOrder,
            onTypeChange = viewModel::setTypeFilter,
            onSortChange = viewModel::setSortOrder,
            onDismiss = { showFilterSheet = false }
        )
    }

    if (showCreateGroupDialog) {
        CreateGroupDialog(
            onDismiss = { showCreateGroupDialog = false },
            onConfirm = { name ->
                showCreateGroupDialog = false
                viewModel.createGroupByName(name)
            }
        )
    }
}

/**
 * 当前实际生效的深浅：跟随系统时按系统深色模式折算。
 * 顶栏图标与点击行为都以此为准，避免 SYSTEM → LIGHT 这一步"点了没反应"。
 */
@Composable
private fun isDarkTheme(mode: ThemeMode): Boolean = when (mode) {
    ThemeMode.LIGHT -> false
    ThemeMode.DARK -> true
    ThemeMode.SYSTEM -> isSystemInDarkTheme()
}

// 网格模式切换按钮 + 下拉菜单
@Composable
private fun GridModeButton(
    mode: GridMode,
    onSelect: (GridMode) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val icon = when (mode) {
        GridMode.TWO -> Icons.Default.ViewModule
        GridMode.THREE -> Icons.Default.GridView
        GridMode.LIST -> Icons.AutoMirrored.Filled.ViewList
    }
    Box {
        GlassIconButton(
            onClick = { expanded = true }, 
            size = 36.dp
        ){
            Icon(
                imageVector = icon,
                contentDescription = "切换视图",
                tint = MaterialTheme.colorScheme.onSurface
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            GridModeMenuItem("两列", GridMode.TWO, mode) { onSelect(it); expanded = false }
            GridModeMenuItem("三列", GridMode.THREE, mode) { onSelect(it); expanded = false }
            GridModeMenuItem("详细列表", GridMode.LIST, mode) { onSelect(it); expanded = false }
        }
    }
}

@Composable
private fun GridModeMenuItem(
    label: String,
    target: GridMode,
    current: GridMode,
    onClick: (GridMode) -> Unit
) {
    DropdownMenuItem(
        text = { Text(
            label,
            style = MaterialTheme.typography.bodySmall,
            color = if (target == current) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
        ) },
        onClick = { onClick(target) },
        leadingIcon = {
            if (target == current) {
                Icon(Icons.Default.Check, contentDescription = null)
            }
        }
    )
}


/** 筛选面板：类型 + 排序 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FilterSheet(
    typeFilter: BookType?,
    sortOrder: SortOrder,
    onTypeChange: (BookType?) -> Unit,
    onSortChange: (SortOrder) -> Unit,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp)
        ) {
            Text("筛选", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.size(12.dp))
            Text("类型", style = MaterialTheme.typography.labelLarge)
            AppChipRow(
                options = listOf<BookType?>(null, BookType.NOVEL, BookType.COMIC),
                selected = typeFilter,
                label = {
                    when (it) {
                        null -> "全部"
                        BookType.NOVEL -> "小说"
                        BookType.COMIC -> "漫画"
                    }
                },
                onSelect = onTypeChange
            )
            Spacer(Modifier.size(16.dp))
            Text("排序", style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SortChip("最近阅读", SortOrder.LAST_READ, sortOrder, onSortChange)
                SortChip("最近添加", SortOrder.RECENT_ADDED, sortOrder, onSortChange)
                SortChip("书名", SortOrder.TITLE, sortOrder, onSortChange)
                SortChip("进度", SortOrder.PROGRESS, sortOrder, onSortChange)
            }
            Spacer(Modifier.size(24.dp))
        }
    }
}

@Composable
private fun SortChip(
    label: String,
    order: SortOrder,
    current: SortOrder,
    onSelect: (SortOrder) -> Unit
) {
    FilterChip(
        selected = order == current,
        onClick = { onSelect(order) },
        label = { Text(label) }
    )
}

@Composable
private fun SelectionBar(
    count: Int,
    onFavorite: () -> Unit,
    onDelete: () -> Unit,
    onCancel: () -> Unit
) {
    GlassSurface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        shape = ReaderShapes.extraSmall,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("已选 $count 项", style = MaterialTheme.typography.labelLarge)
            Spacer(Modifier.weight(1f))
            IconButton(onClick = onFavorite) { Icon(Icons.Default.Favorite, contentDescription = "收藏") }
            IconButton(onClick = onDelete) { Icon(Icons.Default.Delete, contentDescription = "删除") }
            IconButton(onClick = onCancel) { Icon(Icons.Default.Close, contentDescription = "取消") }
        }
    }
}

@Composable
private fun ScanProgressCard(
    progress: ScanProgress,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier
) {
    GlassSurface(modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(
                text = if (progress.done) "导入完成" else "正在导入：${progress.current}",
                style = MaterialTheme.typography.labelLarge
            )
            Spacer(Modifier.size(6.dp))
            Text(
                text = "已扫描 ${progress.scanned} · 新增 ${progress.imported} · 跳过 ${progress.skipped} · 失败 ${progress.failed}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
            )
            if (!progress.done) {
                Spacer(Modifier.size(8.dp))
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            }
        }
    }
}