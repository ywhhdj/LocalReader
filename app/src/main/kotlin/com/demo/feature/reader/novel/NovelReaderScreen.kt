package com.demo.feature.reader.novel

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.RecordVoiceOver
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextIndent
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import coil.compose.AsyncImage

import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.BookBlock
import com.demo.core.model.ReaderBackground
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.ReaderShapes
import com.demo.feature.reader.common.ReaderSettingsPanel

/** 底部翻章热区：宽高占比（左下角上一章 / 右下角下一章） */
private const val TAP_ZONE_WIDTH_RATIO = 0.32f
private const val TAP_ZONE_HEIGHT_RATIO = 0.22f

@Composable
fun NovelReaderScreen(
    viewModel: NovelReaderViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    var showChrome by remember { mutableStateOf(false) }
    val colors = readerColors(state.settings.readerBackground)
    val view = LocalView.current
    val currentChapter = state.chapters.getOrNull(state.chapterIndex)
    // 与首页一致：内容区避开状态栏与导航栏
    val topInset = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    LaunchedEffect(state.settings.keepScreenOn) {
        view.keepScreenOn = state.settings.keepScreenOn
    }

    // 章节切换时回到顶部
    LaunchedEffect(state.chapterIndex) {
        runCatching { listState.scrollToItem(0) }
    }

    // 滚动位置投递给 ViewModel（内部节流后写库）
    LaunchedEffect(listState.firstVisibleItemIndex, state.chapterIndex) {
        viewModel.onScrollPosition(state.chapterIndex, listState.firstVisibleItemIndex)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(colors.background)
    ) {
        if (state.loading && state.blocks.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = colors.text)
            }
        }

        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                // 中间区域点击只切换上下栏；左右下角热区负责翻章
                .clickable { showChrome = !showChrome },
            contentPadding = PaddingValues(
                start = 20.dp, end = 20.dp,
                top = topInset + 64.dp,
                bottom = bottomInset + 88.dp
            )
        ) {
            item {
                ChapterHeader(
                    chapter = currentChapter,
                    fontSize = state.settings.fontSize,
                    colors = colors
                )
            }
            // key 用索引：正文天然存在重复段落，用内容 hash 做 key 会直接崩溃
            itemsIndexed(state.blocks, key = { index, _ -> index }) { _, block ->
                BlockView(block, state.settings.fontSize, state.settings.lineHeightMultiplier, colors)
            }
            item { Spacer(Modifier.height(24.dp)) }
        }

        // 左下角：上一章（显示上下栏时禁用，避免误触）
        TapZone(
            alignment = Alignment.BottomStart,
            enabled = !showChrome && !state.showToc && !state.showSettings && state.canPrev,
            label = "上一章",
            colors = colors,
            onClick = viewModel::prevChapter
        )
        // 右下角：下一章
        TapZone(
            alignment = Alignment.BottomEnd,
            enabled = !showChrome && !state.showToc && !state.showSettings && state.canNext,
            label = "下一章",
            colors = colors,
            onClick = viewModel::nextChapter
        )

        // 顶部栏
        AnimatedVisibility(
            visible = showChrome,
            enter = slideInVertically { -it },
            exit = slideOutVertically { -it },
            modifier = Modifier.align(Alignment.TopCenter)
        ) {
            GlassSurface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(bottomStart = 24.dp, bottomEnd = 24.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(WindowInsets.statusBars.asPaddingValues())
                        .padding(horizontal = 8.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                    Text(
                        text = state.book?.title.orEmpty(),
                        style = MaterialTheme.typography.titleMedium,
                        maxLines = 1,
                        modifier = Modifier.weight(1f)
                    )
                    IconButton(onClick = viewModel::toggleTts) {
                        Icon(
                            if (state.tts.speaking) Icons.Default.Stop else Icons.Default.RecordVoiceOver,
                            contentDescription = "朗读",
                            tint = if (state.tts.speaking) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.onSurface
                        )
                    }
                    IconButton(onClick = { viewModel.toggleToc(true) }) {
                        Icon(Icons.AutoMirrored.Filled.List, contentDescription = "目录")
                    }
                    IconButton(onClick = { viewModel.toggleSettings(true) }) {
                        Icon(Icons.Default.Settings, contentDescription = "设置")
                    }
                }
            }
        }

        // 底部进度
        AnimatedVisibility(
            visible = showChrome,
            enter = slideInVertically { it },
            exit = slideOutVertically { it },
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            GlassSurface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)
            ) {
                Column(
                    Modifier
                        .padding(WindowInsets.navigationBars.asPaddingValues())
                        .padding(12.dp)
                ) {
                    Text(
                        text = chapterLabel(currentChapter, state.chapterIndex, state.chapters.size),
                        style = MaterialTheme.typography.labelMedium
                    )
                    if (state.chapters.size > 1) {
                        Slider(
                            value = (state.chapterIndex + 1).toFloat(),
                            onValueChange = { viewModel.jumpToChapter(it.toInt() - 1) },
                            valueRange = 1f..state.chapters.size.toFloat(),
                            steps = (state.chapters.size - 2).coerceAtLeast(0),
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            }
        }

        // 目录抽屉（按卷分组）
        AnimatedVisibility(
            visible = state.showToc,
            enter = slideInHorizontally { -it },
            exit = slideOutHorizontally { -it }
        ) {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .width(300.dp)
                    .background(colors.background.copy(alpha = 0.98f))
                    .clickable(enabled = true, onClick = {})
            ) {
                TocList(
                    entries = VolumeSplitter.tocEntries(state.chapters),
                    currentIndex = state.chapterIndex,
                    colors = colors,
                    onSelect = { index ->
                        viewModel.jumpToChapter(index)
                        showChrome = false
                    }
                )
            }
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.25f))
                    .clickable { viewModel.toggleToc(false) }
            )
        }

        // 朗读控制条
        AnimatedVisibility(
            visible = state.tts.speaking || state.tts.error != null,
            enter = slideInVertically { it },
            exit = slideOutVertically { it },
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            GlassSurface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
                shape = ReaderShapes.large
            ) {
                Column(Modifier.padding(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = state.tts.error ?: "朗读中 ${state.tts.progressText}",
                            style = MaterialTheme.typography.labelMedium,
                            modifier = Modifier.weight(1f)
                        )
                        TextButton(onClick = viewModel::stopTts) { Text("停止") }
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("语速", style = MaterialTheme.typography.labelSmall)
                        Slider(
                            value = state.settings.ttsRate,
                            onValueChange = viewModel::setTtsRate,
                            valueRange = 0.5f..2.0f,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }

        // 阅读设置面板
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
                onDismiss = { viewModel.toggleSettings(false) }
            )
        }
    }
}

/** 章节标题区：卷名单独一行小字，章节名已去掉卷名前缀 */
@Composable
private fun ChapterHeader(
    chapter: com.demo.core.model.Chapter?,
    fontSize: Int,
    colors: ReaderColors
) {
    val volume = chapter?.volume.orEmpty()
    Column(modifier = Modifier.padding(bottom = 16.dp)) {
        if (volume.isNotBlank()) {
            Text(
                text = volume,
                style = MaterialTheme.typography.labelLarge.copy(
                    color = colors.text.copy(alpha = 0.65f),
                    fontSize = (fontSize - 1).sp
                ),
                modifier = Modifier.padding(bottom = 4.dp)
            )
        }
        Text(
            text = chapter?.let { VolumeSplitter.displayTitle(it) }.orEmpty(),
            style = MaterialTheme.typography.titleLarge.copy(
                color = colors.text,
                fontSize = (fontSize + 4).sp,
                fontWeight = FontWeight.Bold
            )
        )
    }
}

private fun chapterLabel(
    chapter: com.demo.core.model.Chapter?,
    index: Int,
    total: Int
): String {
    val volume = chapter?.volume.orEmpty()
    val name = chapter?.let { VolumeSplitter.displayTitle(it) }.orEmpty()
    val position = if (total > 0) "（${index + 1}/$total）" else ""
    return buildString {
        if (volume.isNotBlank()) append(volume).append(" · ")
        append(name)
        append(position)
    }
}

/** 左下 / 右下角翻章热区（只在可用时接收点击，其余区域仍可滑动与呼出上下栏） */
@Composable
private fun BoxScope.TapZone(
    alignment: Alignment,
    enabled: Boolean,
    label: String,
    colors: ReaderColors,
    onClick: () -> Unit
) {
    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Box(
        modifier = Modifier
            .fillMaxWidth(TAP_ZONE_WIDTH_RATIO)
            .fillMaxHeight(TAP_ZONE_HEIGHT_RATIO)
            .align(alignment)
            .padding(bottom = bottomInset)
            .then(
                if (enabled) {
                    Modifier.pointerInput(onClick) {
                        detectTapGestures(onTap = { onClick() })
                    }
                } else Modifier
            )
    ) {
        if (enabled) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = colors.text.copy(alpha = 0.25f),
                modifier = Modifier
                    .align(if (alignment == Alignment.BottomStart) Alignment.BottomStart else Alignment.BottomEnd)
                    .padding(12.dp)
            )
        }
    }
}

/** 目录：卷标题 + 卷内章节（章节名不含卷名） */
@Composable
private fun TocList(
    entries: List<VolumeSplitter.TocEntry>,
    currentIndex: Int,
    colors: ReaderColors,
    onSelect: (Int) -> Unit
) {
    Column(Modifier.fillMaxSize()) {
        Text(
            "目录",
            style = MaterialTheme.typography.titleMedium,
            color = colors.text,
            modifier = Modifier.padding(16.dp)
        )
        LazyColumn(modifier = Modifier.weight(1f)) {
            itemsIndexed(entries, key = { index, _ -> index }) { _, entry ->
                when (entry) {
                    is VolumeSplitter.TocEntry.Volume -> Text(
                        text = entry.title,
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                        color = colors.text,
                        maxLines = 2,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 10.dp)
                    )
                    is VolumeSplitter.TocEntry.Item -> {
                        val selected = entry.chapter.index == currentIndex
                        Text(
                            text = VolumeSplitter.displayTitle(entry.chapter),
                            style = MaterialTheme.typography.bodyMedium,
                            color = if (selected) MaterialTheme.colorScheme.primary else colors.text,
                            maxLines = 1,
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    if (selected) MaterialTheme.colorScheme.primary.copy(alpha = 0.10f)
                                    else Color.Transparent
                                )
                                .clickable { onSelect(entry.chapter.index) }
                                .padding(horizontal = 16.dp, vertical = 10.dp)
                                .padding(start = 16.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun BlockView(
    block: BookBlock,
    fontSize: Int,
    lineHeight: Float,
    colors: ReaderColors
) {
    when (block) {
        is BookBlock.Heading -> Text(
            text = block.text,
            style = MaterialTheme.typography.titleMedium.copy(
                color = colors.text,
                fontSize = (fontSize + 2).sp,
                lineHeight = (fontSize * lineHeight).sp,
                fontWeight = FontWeight.Bold
            ),
            modifier = Modifier.padding(vertical = 8.dp)
        )
        is BookBlock.Paragraph -> Text(
            text = block.text,
            style = MaterialTheme.typography.bodyLarge.copy(
                color = colors.text,
                fontSize = fontSize.sp,
                lineHeight = (fontSize * lineHeight).sp,
                // 首行缩进两字符，段落内保留原有换行
                textIndent = TextIndent(firstLine = (fontSize * 2).sp),
                textAlign = TextAlign.Start
            ),
            modifier = Modifier.padding(vertical = 6.dp)
        )
        is BookBlock.Quote -> Text(
            text = block.text,
            style = MaterialTheme.typography.bodyMedium.copy(
                color = colors.text.copy(alpha = 0.75f),
                fontSize = fontSize.sp,
                lineHeight = (fontSize * lineHeight).sp,
                textIndent = TextIndent(firstLine = (fontSize * 2).sp)
            ),
            modifier = Modifier.padding(vertical = 6.dp, horizontal = 8.dp)
        )
        is BookBlock.Image -> AsyncImage(
            model = block.src,
            contentDescription = block.alt,
            contentScale = ContentScale.FillWidth,
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp)
        )
        BookBlock.Break -> Spacer(Modifier.height(12.dp))
    }
}

data class ReaderColors(val background: Color, val text: Color)

@Composable
fun readerColors(background: ReaderBackground): ReaderColors {
    val dark = MaterialTheme.colorScheme.background.red + MaterialTheme.colorScheme.background.green +
        MaterialTheme.colorScheme.background.blue < 1.5f
    return when (background) {
        ReaderBackground.CREAM -> ReaderColors(Color(0xFFF6EFE2), Color(0xFF3B3226))
        ReaderBackground.GREEN -> ReaderColors(Color(0xFFE8F0E3), Color(0xFF2E3A2A))
        ReaderBackground.NIGHT -> ReaderColors(Color(0xFF12141A), Color(0xFFC7CBD1))
        ReaderBackground.PAPER -> if (dark) {
            ReaderColors(Color(0xFF15181E), Color(0xFFD6DAE0))
        } else {
            ReaderColors(Color(0xFFFAFAFA), Color(0xFF23262B))
        }
    }
}
