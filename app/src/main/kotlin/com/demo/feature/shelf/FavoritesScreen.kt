package com.demo.feature.shelf

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import com.demo.core.model.BookType
import com.demo.core.ui.components.AppBackdrop
import com.demo.core.ui.components.BookCoverCard
import com.demo.core.ui.components.EmptyState
import com.demo.core.ui.components.SectionHeader
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.glass.GlassTopBar

/**
 * 收藏页：继续阅读 / 最近添加 / 收藏网格。
 * 首页书架只保留分组网格，动态区块统一收拢到这里。
 */
@Composable
fun FavoritesScreen(
    viewModel: FavoritesViewModel,
    onBack: () -> Unit,
    onBookClick: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val gridState = rememberLazyGridState()
    val snackbarHostState = remember { SnackbarHostState() }

    val needLoadMore by remember {
        derivedStateOf {
            val last = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            last >= state.favoriteBooks.size - 8 && state.favoriteBooks.isNotEmpty()
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
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                        }
                    },
                    title = {
                        Text("收藏", style = MaterialTheme.typography.titleMedium)
                    }
                )

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FilterChip(
                        selected = state.typeFilter == null,
                        onClick = { viewModel.setTypeFilter(null) },
                        label = { Text("全部") },
                        shape = CircleShape
                    )
                    FilterChip(
                        selected = state.typeFilter == BookType.NOVEL,
                        onClick = { viewModel.setTypeFilter(BookType.NOVEL) },
                        label = { Text("小说") },
                        shape = CircleShape
                    )
                    FilterChip(
                        selected = state.typeFilter == BookType.COMIC,
                        onClick = { viewModel.setTypeFilter(BookType.COMIC) },
                        label = { Text("漫画") },
                        shape = CircleShape
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
                                onBookClick = { onBookClick(it.id) }
                            )
                        }
                    }
                    if (state.sections.recentBooks.isNotEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }) {
                            BookRow(
                                title = "最近添加",
                                books = state.sections.recentBooks,
                                onBookClick = { onBookClick(it.id) }
                            )
                        }
                    }
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        SectionHeader(title = "我的收藏")
                    }
                    items(state.favoriteBooks, key = { it.id }, contentType = { "book" }) { book ->
                        BookCoverCard(
                            book = book,
                            onClick = { onBookClick(book.id) },
                            onLongClick = { viewModel.unfavorite(book.id) }
                        )
                    }
                    if (state.favoriteBooks.isEmpty() && !state.isLoading) {
                        item(span = { GridItemSpan(maxLineSpan) }) {
                            EmptyState(
                                message = "还没有收藏，长按书架封面即可收藏",
                                actionText = null,
                                onAction = null
                            )
                        }
                    }
                    if (state.isLoading && state.favoriteBooks.isEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }) {
                            Box(
                                Modifier.fillMaxWidth().padding(32.dp),
                                contentAlignment = Alignment.Center
                            ) { CircularProgressIndicator() }
                        }
                    }
                }
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
        )
    }
}
