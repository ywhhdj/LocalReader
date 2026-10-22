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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.clickable

import coil.compose.AsyncImage

import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.ReaderShapes
import com.demo.feature.reader.common.ReaderSettingsPanel
import com.demo.core.ui.theme.SheetShape
import com.demo.core.model.ComicChapter
import com.demo.core.ui.components.AppSlider

/**
 * 漫画阅读器（固定竖向连续滚动）
 * - 话：顶部/底部提供话按钮列表，点击加载该话页面；
 * - 滚到当前话最后一张时，右侧出现「下一话」按钮；
 * - 图片按宽高比占位、异步解码，不支持双击放大与拖动（避免误触与额外内存）；
 * - 顶部/底部留出状态栏与导航栏空间，与首页视觉一致。
 */
@Composable
fun ComicReaderScreen(
    viewModel: ComicReaderViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val paths by viewModel.paths.collectAsStateWithLifecycle()
    val aspects by viewModel.pageAspects.collectAsStateWithLifecycle()
    val scroll by viewModel.scrollRequest.collectAsStateWithLifecycle()
    val view = LocalView.current
    val pages = state.pages
    val range = state.chapterRange
    var showSettings by remember { mutableStateOf(false) }

    val topInset = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    LaunchedEffect(state.settings.keepScreenOn) {
        view.keepScreenOn = state.settings.keepScreenOn
    }

    val listState = rememberLazyListState(
        initialFirstVisibleItemIndex = (state.pageIndex - range.first).coerceAtLeast(0)
    )

    // 切话 / 跳转：滚动到目标页
    LaunchedEffect(scroll?.token) {
        val target = scroll?.index ?: return@LaunchedEffect
        val offset = (target - range.first).coerceAtLeast(0)
        runCatching { listState.scrollToItem(offset) }
    }

    // 当前可见的页面是否已到该话开头
    // 注意：LazyColumn 只渲染「当前话」的页，index 是话内偏移，判定要用 0 而不是全局索引
    val atChapterStart by remember {
        derivedStateOf {
            val visibleFirst = listState.layoutInfo.visibleItemsInfo.firstOrNull()?.index ?: 0
            visibleFirst <= 0
        }
    }

    // 当前可见的最后一页是否已到该话末尾
    val atChapterEnd by remember {
        derivedStateOf {
            val visibleLast = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            val count = listState.layoutInfo.totalItemsCount
            count > 0 && visibleLast >= count - 1
        }
    }

    LaunchedEffect(listState.firstVisibleItemIndex, range.first) {
        val global = (range.first + listState.firstVisibleItemIndex)
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
                contentPadding = PaddingValues(top = topInset, bottom = bottomInset)
            ) {
                // 用 count + key 而非 range.toList()：避免每次重组都新建整段索引列表
                items(
                    count = range.count(),
                    key = { offset -> range.first + offset }
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

        // 到当前话开头 → 左下角出现「上一话」
        if (state.hasPrevChapter && atChapterStart) {
            ChapterButton(
                onClick = viewModel::prevChapter,
                text="上一话",
                align = Alignment.CenterStart
            )
        }

        // 到当前话末尾 → 右下角出现「下一话」
        if (state.hasNextChapter && atChapterEnd) {
            ChapterButton(
                onClick = viewModel::nextChapter,
                text="下一话",
                align = Alignment.CenterEnd
            )
        }

        AnimatedVisibility(
            visible = state.showOverlay,
            enter = slideInVertically { -it },
            exit = slideOutVertically { -it },
            modifier = Modifier.align(Alignment.TopCenter)
        ) {
            GlassSurface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(bottomStart = 24.dp, bottomEnd = 24.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(WindowInsets.statusBars.asPaddingValues())
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                        }
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = state.book?.title.orEmpty(),
                                style = MaterialTheme.typography.titleMedium,
                                maxLines = 1
                            )
                            Text(
                                text = chapterPositionText(state),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                                maxLines = 1
                            )
                        }
                        IconButton(onClick = { showSettings = true }) {
                            Icon(Icons.Default.Settings, contentDescription = "设置")
                        }
                    }
                }
            }
        }

        AnimatedVisibility(
            visible = state.showOverlay,
            enter = slideInVertically { it },
            exit = slideOutVertically { it },
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            GlassSurface(
                modifier = Modifier.fillMaxWidth(),
                shape =  SheetShape
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(WindowInsets.navigationBars.asPaddingValues())
                        .padding(12.dp)
                ) {
                    if (pages.size > 1) {
                        // 拖动时只更新本地值，松手才真正跳转：
                        // 逐帧 jumpToPage 会产生大量滚动请求与进度写库
                        var sliderValue by remember(pages.size) {
                            mutableFloatStateOf((state.pageIndex + 1).toFloat())
                        }
                        LaunchedEffect(state.pageIndex) {
                            sliderValue = (state.pageIndex + 1).toFloat()
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "上一话",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier
                                    .clickable { 
                                        if(state.hasPrevChapter){
                                            viewModel.prevChapter()
                                        }
                                    }
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                            AppSlider(
                                value = sliderValue,
                                onValueChange = { sliderValue = it },
                                onValueChangeFinished = {
                                    viewModel.jumpToPage(
                                        (sliderValue.toInt() - 1).coerceIn(0, pages.lastIndex)
                                    )
                                },
                                valueRange = 1f..pages.size.toFloat(),
                                steps = (pages.size - 2).coerceAtLeast(0),
                                modifier = Modifier.weight(1f),
                                rounded=true,
                            )
                            Text(
                                text = "下一话",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier
                                    .clickable {
                                        if(state.hasNextChapter){
                                            viewModel.nextChapter()
                                        }
                                    }
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }
                    // 话按钮列表：多话时展示，点击加载对应话
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

        AnimatedVisibility(
            visible = showSettings,
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
                // 漫画没有正文排版，隐藏字号 / 行距，避免误改小说阅读设置
                showTextSettings = false,
                onDismiss = { showSettings = false }
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
        "${chapter.title} · $inChapter/${chapter.pageCount.coerceAtLeast(1)} · "
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
            // 已知宽高比：用固定高度约束，避免 LazyColumn 无界高度导致按原图尺寸解码（省内存）
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
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(chapters, key = { it.index }) { chapter ->
            FilterChip(
                selected = chapter.index == selectedIndex,
                onClick = { onSelect(chapter.index) },
                label = { Text(chapter.title, style = MaterialTheme.typography.labelMedium) },
                shape = ReaderShapes.small
            )
        }
    }
}

/** 话按钮 */
@Composable
private fun BoxScope.ChapterButton(
    onClick: () -> Unit,
    text: String,
    align: Alignment = Alignment.CenterStart,
){
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.92f),
        contentColor = MaterialTheme.colorScheme.onPrimary,
        modifier = Modifier
            .align(align)
    ){
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

