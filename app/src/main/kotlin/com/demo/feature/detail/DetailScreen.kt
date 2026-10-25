package com.demo.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.repeatOnLifecycle
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.FilterChip
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.ExperimentalLayoutApi

import coil.compose.AsyncImage

import com.demo.core.common.util.FormatUtil
import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.Book
import com.demo.core.model.BookFormat
import com.demo.core.model.BookType
import com.demo.core.model.Chapter
import com.demo.core.ui.components.AppBackdrop
import com.demo.core.ui.components.CoverSkeleton
import com.demo.core.ui.components.VolumeTocList
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.glass.GlassTopBar
import com.demo.core.ui.theme.ReaderShapes
import com.demo.core.ui.theme.ChipShape
import com.demo.core.ui.theme.SheetShape

/** 详情页目录卡片最多预览的章节数，超出走「全部」抽屉 */
private const val TOC_PREVIEW_COUNT = 20

@Composable
fun DetailScreen(
    viewModel: DetailViewModel,
    onBack: () -> Unit,
    /** chapterIndex 为 null：从进度继续；非 null：跳转到指定章节 / 指定话 */
    onRead: (Book, Int?) -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val lifecycleOwner = LocalLifecycleOwner.current
    var showTocDrawer by remember { mutableStateOf(false) }

    LaunchedEffect(state.deleted) {
        if (state.deleted) onBack()
    }

    // 从阅读器返回时刷新进度、最后阅读时间等字段
    LaunchedEffect(lifecycleOwner) {
        lifecycleOwner.lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            viewModel.refresh()
        }
    }

    val book = state.book
    val chapters = state.chapters

    Box(modifier = modifier.fillMaxSize()) {
    AppBackdrop {
        Column(modifier = Modifier.fillMaxSize()) {
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
                        overflow = TextOverflow.Ellipsis,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                },
                actions = { DetailMenu(viewModel) }
            )

            if (state.isLoading || book == null) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CoverSkeleton(modifier = Modifier.width(160.dp))
                }
                return@Column
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item { HeaderCard(book, { onRead(book, null) }) }
                item { MetaCard(book) }
                item { ActionsCard(book, viewModel) }
                if (book.type == BookType.COMIC) {
                    item {
                        ComicChaptersCard(
                            chapters = chapters,
                            loading = state.chaptersLoading
                        ) { index -> onRead(book, index) }
                    }
                } else if (book.type == BookType.NOVEL) {
                    item {
                        NovelTocCard(
                            chapters = chapters,
                            loading = state.chaptersLoading,
                            currentIndex = -1,
                            onOpenAll = { showTocDrawer = true },
                            onSelect = { index -> onRead(book, index) }
                        )
                    }
                }

            }
        }
    }

        // 目录抽屉：按卷分组，点击即跳转到该章
        if (showTocDrawer && book != null) {
            AnimatedVisibility(
                visible = true,
                enter = slideInHorizontally { it },
                exit = slideOutHorizontally { it },
                modifier = Modifier.align(Alignment.CenterEnd)
            ) {
                Box(Modifier.fillMaxSize()) {
                    // 遮罩在下层：只负责点空白处关闭
                    Box(
                        Modifier
                            .fillMaxSize()
                            //遮罩无色
                            .background(Color.Transparent)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null
                            ) { showTocDrawer = false }
                    )
                    GlassSurface(
                        shape = SheetShape,
                        modifier = Modifier
                            .fillMaxHeight()
                            .fillMaxWidth(0.7f)
                    ) {
                        VolumeTocList(
                            entries = VolumeSplitter.tocEntries(chapters),
                            currentIndex = -1,
                            onSelect = { index ->
                                showTocDrawer = false
                                onRead(book, index)
                            },
                            header = {
                                Text(
                                    "目录",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    modifier = Modifier.padding(16.dp)
                                )
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun HeaderCard(book: Book,  onRead: () -> Unit) {
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
                Row(modifier = Modifier.fillMaxWidth()) {
                    InfoChip(text = book.displayType())
                    Spacer(Modifier.width(6.dp))
                    InfoChip(text = book.format.value)
                }
                Spacer(Modifier.height(6.dp))
                Text(
                    text = if (book.type == BookType.NOVEL) "${book.chapterCount} 章" else "${book.pageCount} 页",
                    style = MaterialTheme.typography.labelSmall
                )
                Spacer(Modifier.height(14.dp))
                GlassSurface(
                    shape = CircleShape,
                    tintAlpha = 0.22f,
                    onClick = onRead
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



/** 话集卡片：GlassSurface 包裹，内部是逐话可点的 GlassSurface 按钮 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ComicChaptersCard(
    chapters: List<Chapter>,
    loading: Boolean = false,
    onOpenChapter: (Int) -> Unit
) {
    if (chapters.isEmpty() && !loading) return
    GlassSurface(
        shape = ReaderShapes.extraSmall,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(
                "话集",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(top = 8.dp, bottom = 8.dp)
            )
            if (chapters.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(72.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                }
                return@Column
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 360.dp)
                    .verticalScroll(rememberScrollState())
            ) {
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    chapters.forEach { chapter ->
                        ChapterChip(
                            chapter = chapter,
                            onClick = { onOpenChapter(chapter.index) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ChapterChip(
    chapter: Chapter,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    GlassSurface(
        shape = ChipShape,
        tintAlpha = 0.18f,
        onClick = onClick,
        modifier = modifier
    ) {
        Text(
            text = "${chapter.index+1}",
            style = MaterialTheme.typography.labelMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 12.dp)
        )
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


/**
 * 小说目录卡片：按卷分组（卷名加粗 + 卷内章节缩进），点击直接跳到该章；
 * 章节较多时用「全部」打开右侧抽屉浏览完整目录。
 */
@Composable
private fun NovelTocCard(
    chapters: List<Chapter>,
    loading: Boolean,
    currentIndex: Int,
    onOpenAll: () -> Unit,
    onSelect: (Int) -> Unit
) {
    if (chapters.isEmpty() && !loading) return
    GlassSurface(
        shape = ReaderShapes.extraSmall,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "目录",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f)
                )
                if (chapters.size > TOC_PREVIEW_COUNT) {
                    TextButton(onClick = onOpenAll) { Text("全部 ${chapters.size} 章") }
                }
            }
            if (chapters.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(72.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                }
                return@Column
            }
            val preview = remember(chapters) { chapters.take(TOC_PREVIEW_COUNT) }
            var lastVolume: String? = null
            preview.forEach { chapter ->
                val volume = chapter.volume
                if (volume.isNotBlank() && volume != lastVolume) {
                    lastVolume = volume
                    Text(
                        text = volume,
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                        maxLines = 2,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp, horizontal = 4.dp)
                    )
                }
                val selected = chapter.index == currentIndex
                Text(
                    text = VolumeSplitter.displayTitle(chapter),
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (selected) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.85f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(ReaderShapes.small)
                        .clickable { onSelect(chapter.index) }
                        .padding(vertical = 8.dp, horizontal = 4.dp)
                        .padding(start = if (volume.isBlank()) 0.dp else 16.dp)
                )
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
