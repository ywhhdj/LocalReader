package com.demo.feature.reader.novel

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.FormatSize
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import coil.compose.AsyncImage

import com.demo.core.model.BookBlock
import com.demo.core.model.ReaderBackground
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.LocalGlassConfig
import com.demo.feature.reader.common.ReaderSettingsPanel
import com.demo.core.ui.theme.ReaderShapes

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

    LaunchedEffect(state.settings.keepScreenOn) {
        view.keepScreenOn = state.settings.keepScreenOn
    }

    // 章节切换时回到顶部
    LaunchedEffect(state.chapterIndex) {
        listState.scrollToItem(0)
    }

    // 滚动位置节流保存进度
    LaunchedEffect(listState.firstVisibleItemIndex, state.chapterIndex) {
        viewModel.saveProgress(state.chapterIndex, listState.firstVisibleItemIndex)
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
                .clickable { showChrome = !showChrome },
            contentPadding = PaddingValues(
                start = 20.dp, end = 20.dp, top = 72.dp, bottom = 96.dp
            )
        ) {
            item {
                Text(
                    text = state.chapters.getOrNull(state.chapterIndex)?.title.orEmpty(),
                    style = MaterialTheme.typography.titleLarge.copy(
                        color = colors.text,
                        fontSize = (state.settings.fontSize + 4).sp
                    ),
                    modifier = Modifier.padding(bottom = 16.dp)
                )
            }
            items(state.blocks, key = { it.hashCode() }) { block ->
                BlockView(block, state.settings.fontSize, state.settings.lineHeightMultiplier, colors)
            }
            item {
                Spacer(Modifier.height(24.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    ChapterButton("上一章", enabled = state.canPrev) { viewModel.prevChapter() }
                    ChapterButton("下一章", enabled = state.canNext) { viewModel.nextChapter() }
                }
            }
        }

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
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
                shape = ReaderShapes.large
            ) {
                Column(Modifier.padding(12.dp)) {
                    Text(
                        text = "第 ${state.chapterIndex + 1}章",
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

        // 目录抽屉
        AnimatedVisibility(
            visible = state.showToc,
            enter = slideInHorizontally { -it },
            exit = slideOutHorizontally { -it }
        ) {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .width(280.dp)
                    .background(colors.background.copy(alpha = 0.98f))
                    .clickable(enabled = true, onClick = {})
            ) {
                Column(Modifier.fillMaxSize()) {
                    Text(
                        "目录",
                        style = MaterialTheme.typography.titleMedium,
                        color = colors.text,
                        modifier = Modifier.padding(16.dp)
                    )
                    LazyColumn(modifier = Modifier.weight(1f)) {
                        items(state.chapters, key = { it.index }) { chapter ->
                            Text(
                                text = chapter.title,
                                style = MaterialTheme.typography.bodyMedium,
                                color = if (chapter.index == state.chapterIndex) {
                                    MaterialTheme.colorScheme.primary
                                } else colors.text,
                                maxLines = 1,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { viewModel.jumpToChapter(chapter.index) }
                                    .padding(horizontal = 16.dp, vertical = 10.dp)
                            )
                        }
                    }
                }
            }
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.25f))
                    .clickable { viewModel.toggleToc(false) }
            )
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

@Composable
private fun BlockView(
    block: BookBlock,
    fontSize: Int,
    lineHeight: Float,
    colors: ReaderColors
) {
    when (block) {
        is BookBlock.Heading -> Text(
            text = buildAnnotatedString {
                append(block.text)
                addStyle(SpanStyle(fontWeight = FontWeight.Bold), 0, block.text.length)
            },
            style = MaterialTheme.typography.titleMedium.copy(
                color = colors.text,
                fontSize = (fontSize + 2).sp,
                lineHeight = (fontSize * lineHeight).sp
            ),
            modifier = Modifier.padding(vertical = 8.dp)
        )
        is BookBlock.Paragraph -> Text(
            text = block.text,
            style = MaterialTheme.typography.bodyLarge.copy(
                color = colors.text,
                fontSize = fontSize.sp,
                lineHeight = (fontSize * lineHeight).sp
            ),
            textAlign = TextAlign.Start,
            modifier = Modifier.padding(vertical = 4.dp)
        )
        is BookBlock.Quote -> Text(
            text = block.text,
            style = MaterialTheme.typography.bodyMedium.copy(
                color = colors.text.copy(alpha = 0.75f),
                fontSize = fontSize.sp,
                lineHeight = (fontSize * lineHeight).sp
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

@Composable
private fun ChapterButton(text: String, enabled: Boolean, onClick: () -> Unit) {
    GlassSurface(
        shape = CircleShape,
        onClick = if (enabled) onClick else null,
        tintAlpha = if (enabled) 0.18f else 0.06f
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge,
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 10.dp)
        )
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
