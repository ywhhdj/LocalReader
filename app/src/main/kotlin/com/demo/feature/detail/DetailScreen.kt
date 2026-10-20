package com.demo.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.automirrored.filled.DriveFileMove
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.foundation.layout.RowScope

import coil.compose.AsyncImage

import com.demo.core.common.util.FormatUtil
import com.demo.core.model.Book
import com.demo.core.model.BookType
import com.demo.core.model.Chapter
import com.demo.core.ui.components.AppBackdrop
import com.demo.core.ui.components.CoverSkeleton
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.glass.GlassTopBar
import com.demo.core.ui.theme.ReaderShapes


@Composable
fun DetailScreen(
    viewModel: DetailViewModel,
    onBack: () -> Unit,
    onRead: (Book) -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(state.deleted) {
        if (state.deleted) onBack()
    }

    AppBackdrop {
        Column(modifier = modifier.fillMaxSize()) {
            GlassTopBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
                title = {
                    Text(
                        text = state.book?.title.orEmpty(),
                        style = MaterialTheme.typography.titleMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                },
                actions = { DetailMenu(viewModel) }
            )

            if (state.isLoading || state.book == null) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CoverSkeleton(modifier = Modifier.width(160.dp))
                }
                return@Column
            }

            val book = state.book ?: return@Column
            val chapters = state.chapters
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item { HeaderCard(book, onRead) }
                item { MetaCard(book) }
                item { ActionsCard(book, viewModel) }
                item { ChaptersCard(chapters, viewModel) }
            }
        }
    }
}

@Composable
private fun HeaderCard(book: Book, onRead: (Book) -> Unit) {
    GlassSurface(shape = ReaderShapes.extraSmall, modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(16.dp)) {
            Box(
                modifier = Modifier
                    .width(120.dp)
                    .height(170.dp)
                    .clip(ReaderShapes.medium)
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                if (!book.coverPath.isNullOrBlank()) {
                    AsyncImage(
                        model = book.coverPath,
                        contentDescription = book.title,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize()
                    )
                }else {
                    //显示无封面
                    Text(
                        text = book.title.firstOrNull()?.uppercaseChar().toString(),
                        style = MaterialTheme.typography.headlineLarge,
                        modifier = Modifier.align(Alignment.Center)
                    )

                }
            }
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    book.title,
                    style = MaterialTheme.typography.titleLarge,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    text = book.author.ifBlank { "未知作者" },
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                )
                Spacer(Modifier.height(10.dp))
                InfoChip(text = if (book.type == BookType.NOVEL) "小说" else "漫画")
                Spacer(Modifier.height(6.dp))
                InfoChip(text = book.format.value)
                Spacer(Modifier.height(6.dp))
                Text(
                    text = if (book.type == BookType.NOVEL) "${book.chapterCount} 章" else "${book.pageCount} 页",
                    style = MaterialTheme.typography.labelSmall
                )
                Spacer(Modifier.height(14.dp))
                GlassSurface(
                    shape = CircleShape,
                    tintAlpha = 0.22f,
                    onClick = { onRead(book) }
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 18.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.PlayArrow,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(Modifier.width(6.dp))
                        Text(
                            text = if (book.progress > 0f) "继续阅读" else "开始阅读",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun InfoChip(text: String) {
    Box(
        modifier = Modifier
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(horizontal = 10.dp, vertical = 4.dp)
    ) {
        Text(text, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun MetaCard(book: Book) {
    GlassSurface(shape = ReaderShapes.extraSmall, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(
                text = "进度 ${FormatUtil.formatPercent(book.progress)}",
                style = MaterialTheme.typography.labelLarge
            )
            Spacer(Modifier.height(8.dp))
            LinearProgressIndicator(
                progress = { book.progress.coerceIn(0f, 1f) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(CircleShape)
            )
            Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth()) {
                MetaItem("大小", FormatUtil.formatBytes(book.sizeBytes))
                MetaItem("加入时间", FormatUtil.formatDate(book.addedAt))
                MetaItem("最近阅读", if (book.lastReadAt > 0) FormatUtil.formatDate(book.lastReadAt) else "未读")
            }
        }
    }
}

@Composable
private fun RowScope.MetaItem(label: String, value: String) {
    Column(Modifier.weight(1f)) {
        Text(label, style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
        Text(value, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun ActionsCard(book: Book, viewModel: DetailViewModel) {
    var showGroupMenu by remember { mutableStateOf(false) }
    val groups = viewModel.uiState.collectAsStateWithLifecycle().value.groups
    GlassSurface(shape = ReaderShapes.extraSmall, modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            ActionButton(
                icon = if (book.favorite) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                label = if (book.favorite) "已收藏" else "收藏",
                onClick = viewModel::toggleFavorite
            )
            Box {
                ActionButton(
                    icon = Icons.AutoMirrored.Filled.DriveFileMove,
                    label = "分组",
                    onClick = { showGroupMenu = true }
                )
                DropdownMenu(expanded = showGroupMenu, onDismissRequest = { showGroupMenu = false }) {
                    DropdownMenuItem(
                        text = { Text("未分组") },
                        onClick = { showGroupMenu = false; viewModel.moveToGroup(null) }
                    )
                    groups.forEach { group ->
                        DropdownMenuItem(
                            text = { Text(group.name) },
                            onClick = { showGroupMenu = false; viewModel.moveToGroup(group.id) }
                        )
                    }
                }
            }
            ActionButton(
                icon = Icons.Default.CheckCircle,
                label = "标记读完",
                onClick = viewModel::markFinished
            )
            ActionButton(
                icon = Icons.Default.Delete,
                label = "删除",
                onClick = viewModel::delete
            )
        }
    }
}


//目录卡片
@Composable
private fun ChaptersCard(
    chapters: List<Chapter>,
    viewModel: DetailViewModel
) {
    if (chapters.isNotEmpty()) {
        GlassSurface(shape = ReaderShapes.extraSmall, modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(12.dp)) {
                Text(
                    "目录",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(top = 8.dp, bottom = 4.dp)
                )
                chapters.take(20).forEach { chapter ->
                    Text(
                        text = chapter.title,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.85f),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 6.dp, horizontal = 4.dp)
                    )
                }
            }
        }
    }
}


@Composable
private fun ActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .clip(ReaderShapes.medium)
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        GlassSurface(shape = CircleShape, tintAlpha = 0.18f, onClick = onClick) {
            Box(
                modifier = Modifier.size(44.dp),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, contentDescription = label, tint = MaterialTheme.colorScheme.primary)
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(label, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun DetailMenu(viewModel: DetailViewModel) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { expanded = true }) {
            Icon(Icons.Default.Delete, contentDescription = "更多")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            DropdownMenuItem(text = { Text("重置进度") }, onClick = { expanded = false; viewModel.resetProgress() })
            DropdownMenuItem(text = { Text("删除本书") }, onClick = { expanded = false; viewModel.delete() })
        }
    }
}
