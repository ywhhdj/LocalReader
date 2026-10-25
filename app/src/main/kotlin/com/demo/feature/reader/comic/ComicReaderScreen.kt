package com.demo.feature.reader.comic

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import coil.compose.AsyncImage

import com.demo.core.model.ComicChapter
import com.demo.core.ui.components.AppChipRow
import com.demo.core.ui.components.ComicTocList
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.ReaderShapes
import com.demo.core.ui.theme.SheetShape
import com.demo.feature.reader.common.ImmersiveModeEffect
import com.demo.feature.reader.common.KeepScreenOnEffect
import com.demo.feature.reader.common.ReaderProgressBar
import com.demo.feature.reader.common.ReaderSettingsPanel
import com.demo.feature.reader.common.ReaderTocDrawer
import com.demo.feature.reader.common.ReaderTopBar
import com.demo.feature.reader.common.readerColors
import com.demo.feature.reader.common.readerContentColor
import com.demo.feature.reader.common.rememberReaderInsets

/** 判定"已滚到底部"的容差（px） */
private const val BOTTOM_TOLERANCE_PX = 12

@Composable
fun ComicReaderScreen(
    viewModel: ComicReaderViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    // 直接读快照表（按 key 粒度订阅）：不再整体 collect Map，避免每解析一页整列重组
    val paths = viewModel.paths
    val aspects = viewModel.pageAspects
    val scroll by viewModel.scrollRequest.collectAsStateWithLifecycle()
    val pages = state.pages
    val range = state.chapterRange
    // 沉浸模式：状态栏收起，漫画页顶到屏幕最上沿
    val insets = rememberReaderInsets(state.settings.immersiveMode)

    KeepScreenOnEffect(state.settings.keepScreenOn)
    ImmersiveModeEffect(state.settings.immersiveMode)

    val listState = rememberLazyListState(
        initialFirstVisibleItemIndex = (state.pageIndex - range.first).coerceAtLeast(0)
    )

    LaunchedEffect(scroll?.token) {
        val target = scroll?.index ?: return@LaunchedEffect
        val offset = (target - range.first).coerceAtLeast(0)
        runCatching { listState.scrollToItem(offset) }
    }

    val atChapterStart by remember {
        derivedStateOf {
            val visibleFirst = listState.layoutInfo.visibleItemsInfo.firstOrNull()?.index ?: 0
            visibleFirst <= 0
        }
    }

    val atChapterEnd by remember {
        derivedStateOf {
            val visibleLast = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            val count = listState.layoutInfo.totalItemsCount
            count > 0 && visibleLast >= count - 1
        }
    }

    val scrolledToBottom by remember {
        derivedStateOf {
            val info = listState.layoutInfo
            val last = info.visibleItemsInfo.lastOrNull() ?: return@derivedStateOf false
            last.index >= info.totalItemsCount - 1 &&
                last.offset + last.size <= info.viewportEndOffset + BOTTOM_TOLERANCE_PX
        }
    }

    LaunchedEffect(listState.firstVisibleItemIndex, scrolledToBottom, range.first) {
        val localIndex = if (scrolledToBottom) {
            (listState.layoutInfo.totalItemsCount - 1).coerceAtLeast(0)
        } else {
            listState.firstVisibleItemIndex.coerceAtLeast(0)
        }
        val global = (range.first + localIndex)
            .coerceAtMost(state.pages.lastIndex.coerceAtLeast(0))
        viewModel.onPageChanged(global)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        if (pages.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                if (state.loading) CircularProgressIndicator() else Text("没有可显示的页面", color = Color.White)
            }
        } else {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(top = insets.top, bottom = insets.bottom)
            ) {
                items(
                    count = range.count(),
                    key = { offset -> range.first + offset },
                    contentType = { "comicPage" }
                ) { offset ->
                    val index = range.first + offset
                    ComicPageItem(
                        path = paths[index],
                        aspect = aspects[index] ?: pages.getOrNull(index)?.aspect ?: 0.72f,
                        onTap = viewModel::toggleOverlay
                    )
                }
            }
        }

        if (state.hasPrevChapter && atChapterStart) {
            ChapterButton(
                onClick = viewModel::prevChapter,
                text = "上一话",
                align = Alignment.CenterStart
            )
        }
        if (state.hasNextChapter && atChapterEnd) {
            ChapterButton(
                onClick = viewModel::nextChapter,
                text = "下一话",
                align = Alignment.CenterEnd
            )
        }

        // ---------- 顶栏（通用） ----------
        ReaderTopBar(
            visible = state.showOverlay,
            title = state.book?.title.orEmpty(),
            subtitle = chapterPositionText(state),
            onBack = onBack,
            modifier = Modifier.align(Alignment.TopCenter),
            contentColor = Color.White,
            immersive = state.settings.immersiveMode,
            actions = {
                if (state.chapters.size > 1) {
                    IconButton(onClick = viewModel::toggleToc) {
                        Icon(
                            Icons.AutoMirrored.Filled.List,
                            contentDescription = "目录",
                            tint = if (state.showToc) MaterialTheme.colorScheme.primary
                            else LocalContentColor.current
                        )
                    }
                }
                IconButton(onClick = viewModel::toggleSettings) {
                    Icon(Icons.Default.Settings, contentDescription = "设置")
                }
            }
        )

        // ---------- 目录抽屉（通用外壳 + 漫画专用列表） ----------
        ReaderTocDrawer(
            visible = state.showToc,
            background = readerColors(state.settings.readerBackground),
            onDismiss = { viewModel.toggleToc(false) }
        ) {
            ComicTocList(
                chapters = state.chapters,
                currentIndex = state.chapterIndex,
                textColor = readerContentColor(state.settings.readerBackground),
                onSelect = { index -> viewModel.selectChapter(index) },
                header = {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "话集 · 共 ${state.chapters.size} 话",
                            style = MaterialTheme.typography.titleMedium,
                            color = readerContentColor(state.settings.readerBackground),
                            modifier = Modifier.weight(1f)
                        )
                        TextButton(onClick = { viewModel.toggleToc(false) }) {
                            Text("关闭")
                        }
                    }
                }
            )
        }

        // ---------- 底栏 ----------
        AnimatedVisibility(
            visible = state.showOverlay,
            enter = slideInVertically { it },
            exit = slideOutVertically { it },
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            GlassSurface(
                modifier = Modifier.fillMaxWidth(),
                shape = SheetShape,
                contentColor = Color.White
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(WindowInsets.navigationBars.asPaddingValues())
                        .padding(12.dp)
                ) {
                    // 页进度条（通用）：拖动本地值，松手跳页
                    ReaderProgressBar(
                        current = state.pageIndex,
                        count = pages.size,
                        hasPrev = state.hasPrevChapter,
                        hasNext = state.hasNextChapter,
                        onPrev = viewModel::prevChapter,
                        onNext = viewModel::nextChapter,
                        onSeek = { viewModel.jumpToPage(it) },
                        contentColor = Color.White,
                        prevLabel = "上一话",
                        nextLabel = "下一话"
                    )
                    if (state.chapters.size > 1) {
                        ChapterButtons(
                            chapters = state.chapters,
                            selectedIndex = state.chapterIndex,
                            onSelect = viewModel::selectChapter
                        )
                    }
                }
            }
        }

        // ---------- 设置面板（已通用） ----------
        AnimatedVisibility(
            visible = state.showSettings,
            enter = slideInVertically { it },
            exit = slideOutVertically { it },
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            ReaderSettingsPanel(
                fontSize = state.settings.fontSize,
                lineHeight = state.settings.lineHeightMultiplier,
                background = state.settings.readerBackground,
                keepScreenOn = state.settings.keepScreenOn,
                volumeTurn = state.settings.volumeKeyTurnPage,
                onFontSize = { viewModel.updateSettings { s -> s.copy(fontSize = it) } },
                onLineHeight = { viewModel.updateSettings { s -> s.copy(lineHeightMultiplier = it) } },
                onBackground = { viewModel.updateSettings { s -> s.copy(readerBackground = it) } },
                onKeepScreenOn = { viewModel.updateSettings { s -> s.copy(keepScreenOn = it) } },
                onVolumeTurn = { viewModel.updateSettings { s -> s.copy(volumeKeyTurnPage = it) } },
                showTextSettings = false,
                contentColor = readerContentColor(state.settings.readerBackground),
                onOpenToc = {
                    viewModel.toggleSettings(false)
                    viewModel.toggleToc(true)
                },
                onDismiss = { viewModel.toggleSettings(false) }
            )
        }
    }
}

/** 顶部：话名 · 话内页码 / 话内总页 · 全书页码 / 全书总页 */
private fun chapterPositionText(state: ComicReaderUiState): String {
    val chapter = state.chapters.getOrNull(state.chapterIndex)
    val inChapter = (state.pageIndex - (chapter?.startIndex ?: 0) + 1).coerceAtLeast(1)
    val total = state.pages.size.coerceAtLeast(1)
    val chapterPart = if (state.chapters.size > 1 && chapter != null) {
        val chapterPages = (chapter.endIndex - chapter.startIndex + 1).coerceAtLeast(1)
        "${chapter.title} · $inChapter/$chapterPages · "
    } else ""
    return "${chapterPart}${state.pageIndex + 1}/$total"
}

/** 单页：按宽高比占位 + 异步解码；不响应双击与拖动 */
@Composable
private fun ComicPageItem(
    path: String?,
    aspect: Float,
    onTap: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.Black)
            .pointerInput(onTap) { detectTapGestures(onTap = { onTap() }) },
        contentAlignment = Alignment.Center
    ) {
        if (path == null) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(if (aspect > 0.05f) aspect else 0.72f),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CircularProgressIndicator(modifier = Modifier.size(28.dp), color = Color.White)
                    Spacer(Modifier.size(8.dp))
                    Text("加载中…", style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.6f))
                }
            }
        } else if (aspect > 0.05f) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(aspect)
            ) {
                AsyncImage(
                    model = path,
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxSize()
                )
            }
        } else {
            AsyncImage(
                model = path,
                contentDescription = null,
                contentScale = ContentScale.FillWidth,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

/** 话按钮列表（横向滚动，当前话高亮） */
@Composable
private fun ChapterButtons(
    chapters: List<ComicChapter>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit
) {
    AppChipRow(
        options = chapters.map { it.index },
        selected = selectedIndex,
        label = { idx -> chapters.first { it.index == idx }.title },
        onSelect = onSelect,
        lazy = true,
        shape = ReaderShapes.small,
        rowHeight = 48.dp,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    )
}

/** 上一话 / 下一话圆形按钮 */
@Composable
private fun BoxScope.ChapterButton(
    onClick: () -> Unit,
    text: String,
    align: Alignment = Alignment.CenterStart
) {
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.92f),
        contentColor = MaterialTheme.colorScheme.onPrimary,
        modifier = Modifier.align(align)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = text,
                style = MaterialTheme.typography.labelLarge,
                textAlign = TextAlign.Center
            )
        }
    }
}