package com.demo.feature.shelf

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.DriveFileMove
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import kotlinx.coroutines.launch

import com.demo.core.model.Book
import com.demo.core.ui.components.AppBackdrop
import com.demo.core.ui.components.BookCoverCard
import com.demo.core.ui.components.EmptyState
import com.demo.core.ui.components.GlassSearchBar
import com.demo.core.ui.components.SectionHeader
import com.demo.core.ui.glass.GlassIconButton
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.glass.GlassTopBar
import com.demo.core.ui.theme.CardShape

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
    val gridState = rememberLazyGridState()
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var showImportDialog by remember { mutableStateOf(false) }
    var showCreateGroupDialog by remember { mutableStateOf(false) }

    val scrolled by remember {
        derivedStateOf { gridState.firstVisibleItemIndex > 0 || gridState.firstVisibleItemScrollOffset > 8 }
    }

    // 分页：距列表尾部 8 项时加载下一页
    val needLoadMore by remember {
        derivedStateOf {
            val last = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            last >= state.gridBooks.size - 8 && state.gridBooks.isNotEmpty()
        }
    }
    LaunchedEffect(needLoadMore) {
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
                            themeMode = state.settings.themeMode,
                            onToggleTheme = viewModel::toggleTheme,
                            onSettings = onSettings
                        )
                    }
                )

                GroupChips(
                    groups = state.groups,
                    selectedId = state.selectedGroupId,
                    onSelect = viewModel::selectGroup,
                    onCreate = { showCreateGroupDialog = true }
                )

                if (state.selection.isNotEmpty()) {
                    SelectionBar(
                        count = state.selection.size,
                        onFavorite = { viewModel.favoriteSelection(true) },
                        onDelete = { viewModel.deleteSelection() },
                        onCancel = viewModel::clearSelection
                    )
                }

                LazyVerticalGrid(
                    columns = GridCells.Adaptive(minSize = 108.dp),
                    state = gridState,
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 96.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxSize()
                ) {
                    if (state.sections.continueBooks.isNotEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }) {
                            BookRow(
                                title = "继续阅读",
                                books = state.sections.continueBooks,
                                onBookClick = { onBookClick(it.id) },
                                onBookLongClick = { viewModel.toggleSelection(it.id) }
                            )
                        }
                    }
                    if (state.sections.recentBooks.isNotEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }) {
                            BookRow(
                                title = "最近添加",
                                books = state.sections.recentBooks,
                                onBookClick = { onBookClick(it.id) },
                                onBookLongClick = { viewModel.toggleSelection(it.id) }
                            )
                        }
                    }
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        SectionHeader(title = "书架")
                    }
                    if (state.isLoading && state.gridBooks.isEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }) {
                            Box(
                                Modifier.fillMaxWidth().padding(32.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator()
                            }
                        }
                    }
                    items(
                        state.gridBooks,
                        key = { it.id },
                        contentType = { "book" }
                    ) { book ->
                        BookCoverCard(
                            book = book,
                            selected = book.id in state.selection,
                            onClick = { onBookClick(book.id) },
                            onLongClick = { viewModel.toggleSelection(book.id) }
                        )
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
                }
            }
        }

        // 悬浮导入按钮
        GlassSurface(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 20.dp, bottom = 24.dp)
                .size(56.dp)
                .navigationBarsPadding(),
            shape = CircleShape,
            tintAlpha = 0.22f,
            onClick = { showImportDialog = true }
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "导入",
                    tint = MaterialTheme.colorScheme.primary
                )
            }
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
        shape = CardShape
    ) {
        androidx.compose.foundation.layout.Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("已选 $count 项", style = MaterialTheme.typography.labelLarge)
            androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
            IconButton(onClick = onFavorite) {
                Icon(Icons.Default.Favorite, contentDescription = "收藏")
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Default.Delete, contentDescription = "删除")
            }
            IconButton(onClick = onCancel) {
                Icon(Icons.Default.Close, contentDescription = "取消")
            }
        }
    }
}

@Composable
private fun ScanProgressCard(
    progress: com.demo.domain.repository.ScanProgress,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier
) {
    GlassSurface(modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(
                text = if (progress.done) "导入完成" else "正在导入：${progress.current}",
                style = MaterialTheme.typography.labelLarge
            )
            androidx.compose.foundation.layout.Spacer(Modifier.size(6.dp))
            Text(
                text = "已扫描 ${progress.scanned} · 新增 ${progress.imported} · 跳过 ${progress.skipped} · 失败 ${progress.failed}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
            )
            if (!progress.done) {
                androidx.compose.foundation.layout.Spacer(Modifier.size(8.dp))
                androidx.compose.material3.LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            }
        }
    }
}
