package com.demo.feature.shelf

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import com.demo.core.ui.components.AppBackdrop
import com.demo.core.ui.components.BookCoverCard
import com.demo.core.ui.components.EmptyState
import com.demo.core.ui.glass.GlassTopBar

@Composable
fun SearchScreen(
    viewModel: ShelfViewModel,
    onBack: () -> Unit,
    onBookClick: (Long) -> Unit,
    onOnlineSearch: () -> Unit = {}
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focusRequester.requestFocus() } }

    AppBackdrop {
        Column(Modifier.fillMaxSize()) {
            GlassTopBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
                actions = {
                    if (state.settings.onlineSourceEnabled) {
                        IconButton(onClick = onOnlineSearch) {
                            Icon(Icons.Default.Public, contentDescription = "在线书源")
                        }
                    }
                },
                title = {
                    OutlinedTextField(
                        value = state.keyword,
                        onValueChange = viewModel::search,
                        placeholder = { Text("搜索书名 / 作者") },
                        singleLine = true,
                        textStyle = MaterialTheme.typography.bodyMedium,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = androidx.compose.ui.graphics.Color.Transparent,
                            unfocusedBorderColor = androidx.compose.ui.graphics.Color.Transparent
                        ),
                        leadingIcon = {
                            Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(18.dp))
                        },
                        trailingIcon = {
                            if (state.keyword.isNotEmpty()) {
                                IconButton(onClick = { viewModel.search("") }) {
                                    Icon(Icons.Default.Close, contentDescription = "清空", modifier = Modifier.size(18.dp))
                                }
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .focusRequester(focusRequester)
                    )
                }
            )

            if (state.keyword.isBlank()) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    EmptyState(message = "输入关键词开始搜索本地书籍")
                }
                return@Column
            }

            LazyVerticalGrid(
                columns = GridCells.Adaptive(minSize = 108.dp), // 列数
                contentPadding = PaddingValues(16.dp), // 列间距
                verticalArrangement = Arrangement.spacedBy(12.dp), // 垂直间距
                horizontalArrangement = Arrangement.spacedBy(12.dp), // 水平间距
                modifier = Modifier.fillMaxSize() // 填充剩余空间
            ) {
                if (state.searchResults.isEmpty()) {
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        EmptyState(
                            message = "没有找到「${state.keyword}」相关的书",
                            modifier = Modifier.padding(top = 48.dp)
                        )
                    }
                }
                items(state.searchResults, key = { it.id }) { book ->
                    BookCoverCard(
                        book = book,
                        onClick = { onBookClick(book.id) }
                    )
                }
            }
        }
    }
}
