package com.demo.feature.shelf

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import com.demo.core.ui.components.AppBackdrop
import com.demo.core.ui.components.EmptyState
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.glass.GlassTopBar
import com.demo.core.ui.theme.CardShape

/**
 * 在线书源搜索页（默认关闭，需先在设置中开启并配置书源）。
 * 结果只能"另存为 TXT 到本地书库"，不提供在线缓存阅读。
 */
@Composable
fun OnlineSearchScreen(
    viewModel: OnlineSearchViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }

    LaunchedEffect(state.message) {
        val msg = state.message ?: return@LaunchedEffect
        snackbar.showSnackbar(msg)
        viewModel.consumeMessage()
    }

    AppBackdrop {
        Box(modifier = modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize()) {
                GlassTopBar(
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                        }
                    },
                    title = {
                        OutlinedTextField(
                            value = state.keyword,
                            onValueChange = viewModel::onKeywordChange,
                            placeholder = { Text("搜索在线书源") },
                            singleLine = true,
                            enabled = state.enabled,
                            leadingIcon = {
                                Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(18.dp))
                            },
                            trailingIcon = {
                                if (state.keyword.isNotEmpty()) {
                                    IconButton(onClick = { viewModel.onKeywordChange("") }) {
                                        Icon(Icons.Default.Close, contentDescription = "清空", modifier = Modifier.size(18.dp))
                                    }
                                } else {
                                    TextButton(onClick = viewModel::search) { Text("搜索") }
                                }
                            },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                )

                if (!state.enabled) {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        EmptyState(
                            message = "在线书源默认关闭。\n如需使用，请在「设置 → 在线书源」中开启并自行配置书源。"
                        )
                    }
                    return@Column
                }

                if (state.sources.size > 1) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        state.sources.forEach { source ->
                            FilterChip(
                                selected = source.id == state.selectedSourceId,
                                onClick = { viewModel.selectSource(source.id) },
                                label = { Text(source.name) },
                                shape = CircleShape
                            )
                        }
                    }
                }

                if (state.loading) {
                    Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }

                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    if (state.results.isEmpty() && !state.loading) {
                        item {
                            EmptyState(message = "输入关键词开始搜索（结果可另存为 TXT 到书架）")
                        }
                    }
                    items(state.results) { book ->
                        OnlineBookRow(
                            title = book.title,
                            author = book.author,
                            source = book.sourceName,
                            onClick = { viewModel.openDetail(book) }
                        )
                    }
                }
            }

            SnackbarHost(
                hostState = snackbar,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(16.dp)
            )

            // 详情：目录 + 保存
            state.detail?.let { book ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clickable(enabled = true, onClick = {}),
                    contentAlignment = Alignment.BottomCenter
                ) {
                    GlassSurface(shape = CardShape, modifier = Modifier.fillMaxWidth().padding(12.dp)) {
                        Column(Modifier.padding(16.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(book.title, style = MaterialTheme.typography.titleMedium, maxLines = 2)
                                    Text(
                                        "${book.sourceName} · ${book.author.ifBlank { "未知作者" }} · ${state.chapters.size} 章",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f)
                                    )
                                }
                                IconButton(onClick = viewModel::closeDetail) {
                                    Icon(Icons.Default.Close, contentDescription = "关闭")
                                }
                            }
                            state.saveProgress?.let { (done, total) ->
                                LinearProgressIndicator(
                                    progress = { if (total == 0) 0f else done.toFloat() / total },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 10.dp)
                                )
                                Text("保存中 $done/$total", style = MaterialTheme.typography.labelSmall)
                            }
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 12.dp),
                                horizontalArrangement = Arrangement.End
                            ) {
                                Button(
                                    onClick = viewModel::saveToLibrary,
                                    enabled = !state.saving && state.chapters.isNotEmpty()
                                ) {
                                    Icon(Icons.Default.Download, contentDescription = null, modifier = Modifier.size(18.dp))
                                    Text(" 保存到书架", modifier = Modifier.padding(start = 6.dp))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun OnlineBookRow(
    title: String,
    author: String,
    source: String,
    onClick: () -> Unit
) {
    GlassSurface(shape = CardShape, modifier = Modifier.fillMaxWidth(), onClick = onClick) {
        Column(Modifier.padding(14.dp)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, maxLines = 2)
            Text(
                "${author.ifBlank { "未知作者" }} · $source",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                modifier = Modifier.padding(top = 4.dp)
            )
        }
    }
}
