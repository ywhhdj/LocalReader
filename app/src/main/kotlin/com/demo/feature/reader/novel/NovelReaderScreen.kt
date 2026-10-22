package com.demo.feature.reader.novel

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
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
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.ui.graphics.Color

import coil.compose.AsyncImage

import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.BookBlock
import com.demo.core.model.Book
import com.demo.core.model.Chapter
import com.demo.core.model.ReaderBackground
import com.demo.core.ui.components.VolumeTocList
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.ReaderShapes
import com.demo.feature.reader.common.ReaderSettingsPanel
import com.demo.core.ui.theme.SheetShape
import com.demo.core.ui.components.AppSlider
import com.demo.feature.reader.common.ReaderColors
import com.demo.feature.reader.common.readerColors

/** 底部翻页热区：宽高占比 */
private const val TAP_ZONE_WIDTH_RATIO = 0.32f
private const val TAP_ZONE_HEIGHT_RATIO = 0.22f

/** 内容左右内边距 */
private val ContentHorizontalPadding = 20.dp

@Composable
fun NovelReaderScreen(
    viewModel: NovelReaderViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var showChrome by remember { mutableStateOf(false) }
    var pageIndex by remember { mutableIntStateOf(0) }
    var forward by remember { mutableStateOf(true) }
    val colors = readerColors(state.settings.readerBackground)
    val view = LocalView.current
    val currentChapter = state.chapters.getOrNull(state.chapterIndex)
    val topInset = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    LaunchedEffect(state.settings.keepScreenOn) {
        view.keepScreenOn = state.settings.keepScreenOn
    }

    // 章节切换 → 回到该章首页
    LaunchedEffect(state.chapterIndex) {
        pageIndex = 0
        viewModel.onScrollPosition(state.chapterIndex, 0)
    }

    if (state.loading && state.blocks.isEmpty()) {
        Box(
            modifier.fillMaxSize().background(colors.background),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = colors.text)
        }
        return
    }

    // 注意：必须用 BoxWithConstraints 提供 maxWidth/maxHeight 与 BoxScope.align
    BoxWithConstraints(
        modifier = modifier
            .fillMaxSize()
            .background(colors.background)
    ) {
        val density = LocalDensity.current
        val textMeasurer = rememberTextMeasurer()

        val pageWidthPx = with(density) {
            (maxWidth - ContentHorizontalPadding * 2).toPx().toInt().coerceAtLeast(1)
        }
        val pageHeightPx = with(density) {
            (maxHeight - topInset - bottomInset).toPx().toInt().coerceAtLeast(1)
        }

        // 合成：章节标题 + 本章 blocks
        val allBlocks = remember(state.chapterIndex, state.blocks, currentChapter) {
            val header = currentChapter?.let {
                val volume = it.volume.orEmpty()
                val title = VolumeSplitter.displayTitle(it)
                val text = if (volume.isNotBlank()) "$volume\n$title" else title
                BookBlock.Heading(text)
            }
            listOfNotNull(header) + state.blocks
        }

        val pages = remember(
            allBlocks, state.settings.fontSize, state.settings.lineHeightMultiplier,
            pageWidthPx, pageHeightPx
        ) {
            paginateNovel(
                measurer = textMeasurer,
                blocks = allBlocks,
                pageWidth = pageWidthPx,
                pageHeight = pageHeightPx,
                fontSize = state.settings.fontSize,
                lineHeightMultiplier = state.settings.lineHeightMultiplier,
                density = density
            )
        }

        if (pageIndex > pages.lastIndex) {
            pageIndex = pages.lastIndex.coerceAtLeast(0)
        }

        fun goNext() {
            forward = true
            if (pageIndex < pages.lastIndex) pageIndex++
            else if (state.canNext) viewModel.nextChapter()
        }

        fun goPrev() {
            forward = false
            if (pageIndex > 0) pageIndex--
            else if (state.canPrev) viewModel.prevChapter()
        }

        // ---------- 当前页内容（含左右滑动手势） ----------
        AnimatedContent(
            targetState = pageIndex,
            transitionSpec = {
                if (forward) {
                    (slideInHorizontally(tween(220)) { it } + fadeIn(tween(220)))
                        .togetherWith(slideOutHorizontally(tween(220)) { -it } + fadeOut(tween(220)))
                } else {
                    (slideInHorizontally(tween(220)) { -it } + fadeIn(tween(220)))
                        .togetherWith(slideOutHorizontally(tween(220)) { it } + fadeOut(tween(220)))
                }
            },
            modifier = Modifier
                .fillMaxSize()
                .padding(
                    start = ContentHorizontalPadding,
                    end = ContentHorizontalPadding,
                    top = topInset,
                    bottom = bottomInset
                )
                .pointerInput(pageIndex, pages.size) {
                    var accumulated = 0f
                    detectHorizontalDragGestures(
                        onDragStart = { accumulated = 0f },
                        onDragEnd = {
                            val threshold = size.width * 0.15f
                            when {
                                accumulated < -threshold -> goNext()
                                accumulated > threshold -> goPrev()
                            }
                        },
                        onHorizontalDrag = { change, dragAmount ->
                            change.consume()
                            accumulated += dragAmount
                        }
                    )
                }
                // 轻点：切换顶栏 / 底栏
                .pointerInput(Unit) {
                    detectTapGestures(onTap = { showChrome = !showChrome })
                }
        ) { idx ->
            val page = pages.getOrNull(idx)
            Column(Modifier.fillMaxSize()) {
                page?.items?.forEach { item ->
                    BlockView(
                        block = item.block,
                        fontSize = state.settings.fontSize,
                        lineHeight = state.settings.lineHeightMultiplier,
                        colors = colors,
                        isContinuation = item.isContinuation
                    )
                }
            }
        }

        // ---------- 左下：上一页 / 上一章 ----------
        val canPrevPage = pageIndex > 0
        TapZone(
            alignment = Alignment.BottomStart,
            enabled = !showChrome && !state.showToc && !state.showSettings &&
                (canPrevPage || state.canPrev),
            label = if (canPrevPage) "上一页" else "上一章",
            colors = colors,
            onClick = { goPrev() }
        )

        // ---------- 右下：下一页 / 下一章 ----------
        val canNextPage = pageIndex < pages.lastIndex
        TapZone(
            alignment = Alignment.BottomEnd,
            enabled = !showChrome && !state.showToc && !state.showSettings &&
                (canNextPage || state.canNext),
            label = if (canNextPage) "下一页" else "下一章",
            colors = colors,
            onClick = { goNext() }
        )

        // ---------- 顶栏 ----------
        AnimatedVisibility(
            visible = showChrome,
            enter = slideInVertically { -it },
            exit = slideOutVertically { -it },
            modifier = Modifier.align(Alignment.TopCenter)
        ) {
            GlassSurface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(bottomStart = 24.dp, bottomEnd = 24.dp),
                backgroundColor = colors.background
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
                    IconButton(onClick = viewModel::toggleToc) {
                        Icon(Icons.AutoMirrored.Filled.List, contentDescription = "目录")
                    }
                    IconButton(onClick = viewModel::toggleSettings) {
                        Icon(Icons.Default.Settings, contentDescription = "设置")
                    }
                }
            }
        }

        // ---------- 底栏 ----------
        AnimatedVisibility(
            visible = showChrome,
            enter = slideInVertically { it },
            exit = slideOutVertically { it },
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            GlassSurface(
                modifier = Modifier.fillMaxWidth(),
                shape = SheetShape,
                backgroundColor = colors.background
            ) {
                Column(
                    Modifier
                        .padding(WindowInsets.navigationBars.asPaddingValues())
                        .padding(12.dp)
                ) {
                    Text(
                        text = chapterAndPageLabel(
                            currentChapter, state.chapterIndex, state.chapters.size,
                            pageIndex, pages.size
                        ),
                        style = MaterialTheme.typography.labelMedium
                    )
                    if (state.chapters.size > 1) {
                        // 拖动过程中只更新本地值，松手才跳章：避免拖动时连续解析每一章
                        var chapterSlider by remember(state.chapters.size) {
                            mutableFloatStateOf((state.chapterIndex + 1).toFloat())
                        }
                        LaunchedEffect(state.chapterIndex) {
                            chapterSlider = (state.chapterIndex + 1).toFloat()
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "上一章",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier
                                    .clickable {
                                        if (state.canPrev) {
                                            chapterSlider--
                                            viewModel.prevChapter()
                                        }
                                    }
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                            AppSlider(
                                value = chapterSlider,
                                onValueChange = { chapterSlider = it },
                                onValueChangeFinished = {
                                    viewModel.jumpToChapter(chapterSlider.toInt() - 1)
                                },
                                valueRange = 1f..state.chapters.size.toFloat(),
                                modifier = Modifier.weight(1f),
                                steps = (state.chapters.size - 2).coerceAtLeast(0),
                                rounded=true,
                            )
                            Text(
                                text = "下一章",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier
                                    .clickable {
                                        if (state.canNext) {
                                            chapterSlider++
                                            viewModel.nextChapter()
                                        }
                                    }
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }
                }
            }
        }

        // ---------- 目录抽屉 ----------
        AnimatedVisibility(
            visible = state.showToc,
            enter = slideInHorizontally { -it },
            exit = slideOutHorizontally { -it }
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
                        ) { viewModel.toggleToc(false) }
                )
                Column(
                    Modifier
                        .fillMaxHeight()
                        .fillMaxWidth(0.7f)
                        .background(colors.background)
                ) {
                    VolumeTocList(
                        entries = VolumeSplitter.tocEntries(state.chapters),
                        currentIndex = state.chapterIndex,
                        textColor = colors.text,
                        onSelect = { index ->
                            viewModel.jumpToChapter(index)
                            viewModel.toggleToc(false)
                        },
                        header = {
                            Text(
                                "目录",
                                style = MaterialTheme.typography.titleMedium,
                                color = colors.text,
                                modifier = Modifier.padding(16.dp)
                            )
                        }
                    )
                }
            }
        }

        // ---------- 朗读控制条 ----------
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
                shape = ReaderShapes.large,
                backgroundColor = colors.background
            ) {
                Column(Modifier.padding(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = state.tts.error ?: "朗读中 ${state.tts.progressText}",
                            style = MaterialTheme.typography.labelMedium,
                            modifier = Modifier.weight(1f),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        TextButton(onClick = viewModel::stopTts) { 
                            Text("停止")
                        }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("语速", style = MaterialTheme.typography.labelSmall)
                        Spacer(Modifier.height(6.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                "0.5x",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            AppSlider(
                                value = state.settings.ttsRate,
                                onValueChange = viewModel::setTtsRate,
                                valueRange = 0.5f..2.0f,
                                modifier = Modifier.weight(1f),
                                rounded=true,
                            )
                            Text(
                                "2.0x",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }

        // ---------- 设置面板 ----------
        AnimatedVisibility(
            visible = state.showSettings,
            enter = slideInVertically { it },
            exit = slideOutVertically { it },
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .padding(bottom = 0.dp)
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
                // 设置面板里的目录入口：关闭面板并拉出目录抽屉，点章即跳转
                onOpenToc = {
                    viewModel.toggleSettings(false)
                    viewModel.toggleToc(true)
                },
                onDismiss = { viewModel.toggleSettings(false) }
            )
        }
    }
}

/** 底栏文字：卷名 · 章节（第几章/共几章 · 第几页/共几页） */
private fun chapterAndPageLabel(
    chapter: Chapter?,
    chapterIndex: Int,
    chapterTotal: Int,
    pageIndex: Int,
    pageTotal: Int
): String {
    val volume = chapter?.volume.orEmpty()
    val name = chapter?.let { VolumeSplitter.displayTitle(it) }.orEmpty()
    val chapterPart = if (chapterTotal > 0) "（${chapterIndex + 1}/$chapterTotal）" else ""
    val pagePart = if (pageTotal > 0) " · ${pageIndex + 1}/$pageTotal 页" else ""
    return buildString {
        if (volume.isNotBlank()) append(volume).append(" · ")
        append(name)
        append(chapterPart)
        append(pagePart)
    }
}

/** 左下 / 右下角热区 */
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
                    .align(
                        if (alignment == Alignment.BottomStart) Alignment.BottomStart
                        else Alignment.BottomEnd
                    )
                    .padding(12.dp)
            )
        }
    }
}

/**
 * 单块渲染。
 * 首行缩进由 TextStyle.textIndent 承担（与分页测量同一套规则），
 * [isContinuation] 为 true 表示本块是从上一页延续而来，不缩进。
 */
@Composable
private fun BlockView(
    block: BookBlock,
    fontSize: Int,
    lineHeight: Float,
    colors: ReaderColors,
    isContinuation: Boolean = false
) {
    when (block) {
        is BookBlock.Heading -> SelectionContainer {
            Text(
                text = block.text,
                style = MaterialTheme.typography.titleMedium.copy(
                    color = colors.text,
                    fontSize = (fontSize + 2).sp,
                    lineHeight = (fontSize * lineHeight).sp,
                    fontWeight = FontWeight.Bold
                ),
                modifier = Modifier.padding(vertical = 8.dp)
            )
        }
        is BookBlock.Paragraph -> SelectionContainer {
            Text(
                text = block.text,
                style = MaterialTheme.typography.bodyLarge.copy(
                    color = colors.text,
                    fontSize = fontSize.sp,
                    lineHeight = (fontSize * lineHeight).sp,
                    textAlign = TextAlign.Start,
                    textIndent = paragraphIndent(fontSize, isContinuation)
                ),
                modifier = Modifier.padding(vertical = 6.dp)
            )
        }
        is BookBlock.Quote -> SelectionContainer {
            Text(
                text = block.text,
                style = MaterialTheme.typography.bodyMedium.copy(
                    color = colors.text.copy(alpha = 0.75f),
                    fontSize = fontSize.sp,
                    lineHeight = (fontSize * lineHeight).sp
                ),
                modifier = Modifier.padding(vertical = 6.dp, horizontal = 8.dp)
            )
        }
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