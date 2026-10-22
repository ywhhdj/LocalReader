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
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import coil.compose.AsyncImage

import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.BookBlock
import com.demo.core.model.Chapter
import com.demo.core.ui.components.VolumeTocList
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.ReaderShapes
import com.demo.core.ui.theme.SheetShape
import com.demo.feature.reader.common.KeepScreenOnEffect
import com.demo.feature.reader.common.ReaderProgressBar
import com.demo.feature.reader.common.ReaderTapZone
import com.demo.feature.reader.common.ReaderTocDrawer
import com.demo.feature.reader.common.ReaderTopBar
import com.demo.feature.reader.common.ReaderColors
import com.demo.feature.reader.common.ReaderSettingsPanel
import com.demo.feature.reader.common.readerColors
import com.demo.feature.reader.common.rememberReaderInsets

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
    val ttsProgress by viewModel.ttsProgress.collectAsStateWithLifecycle()
    var showTtsSettings by remember { mutableStateOf(false) }
    var forward by remember { mutableStateOf(true) }
    /** 朗读会话是否激活（朗读中 / 已暂停都算，保证进度球不闪） */
    val ttsActive = state.ttsActive
    /** 系统语音列表：只在打开听读设置时取一次，避免每次重组都遍历引擎语音 */
    val ttsVoices = remember(showTtsSettings) {
        if (showTtsSettings) viewModel.ttsVoices() else emptyList()
    }
    val colors = readerColors(state.settings.readerBackground)
    val currentChapter = state.chapters.getOrNull(state.chapterIndex)
    val insets = rememberReaderInsets()

    KeepScreenOnEffect(state.settings.keepScreenOn)

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
            (maxHeight - insets.top - insets.bottom).toPx().toInt().coerceAtLeast(1)
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

        // 字号/行距变化后页数会变少，副作用里把越界页码收回
        LaunchedEffect(pages.size) {
            if (pageIndex > pages.lastIndex) pageIndex = pages.lastIndex.coerceAtLeast(0)
        }
        val safePageIndex = pageIndex.coerceIn(0, pages.lastIndex.coerceAtLeast(0))

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

        // ---------- 当前页内容（含左右滑动手势 + 可切换的翻页动画） ----------
        PageTurnContainer(
            pageIndex = safePageIndex,
            forward = forward,
            mode = state.settings.pageTurnMode,
            modifier = Modifier
                .fillMaxSize()
                .padding(
                    start = ContentHorizontalPadding,
                    end = ContentHorizontalPadding,
                    top = insets.top,
                    bottom = insets.bottom
                )
                .pointerInput(safePageIndex, pages.size) {
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
                    detectTapGestures(onTap = {
                        showChrome = !showChrome
                        viewModel.toggleSettings(false)
                        viewModel.toggleToc(false) 
                    })
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

        // ---------- 左下 / 右下热区 ----------
        val canPrevPage = safePageIndex > 0
        ReaderTapZone(
            alignment = Alignment.BottomStart,
            enabled = !showChrome && !state.showToc && !state.showSettings &&
                (canPrevPage || state.canPrev),
            label = if (canPrevPage) "上一页" else "上一章",
            textColor = colors.text,
            onClick = { goPrev() }
        )

        val canNextPage = safePageIndex < pages.lastIndex
        ReaderTapZone(
            alignment = Alignment.BottomEnd,
            enabled = !showChrome && !state.showToc && !state.showSettings &&
                (canNextPage || state.canNext),
            label = if (canNextPage) "下一页" else "下一章",
            textColor = colors.text,
            onClick = { goNext() }
        )

        // ---------- 顶栏（通用） ----------
        ReaderTopBar(
            visible = showChrome,
            title = state.book?.title.orEmpty(),
            onBack = onBack,
            modifier = Modifier.align(Alignment.TopCenter),
            backgroundColor = colors.background,
            actions = {
                IconButton(onClick = viewModel::toggleToc) {
                    Icon(Icons.AutoMirrored.Filled.List, contentDescription = "目录")
                }
                IconButton(onClick = viewModel::toggleSettings) {
                    Icon(Icons.Default.Settings, contentDescription = "设置")
                }
            }
        )

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
                            safePageIndex, pages.size
                        ),
                        style = MaterialTheme.typography.labelMedium
                    )
                    // 章节进度条（通用）：拖动本地值，松手跳章
                    ReaderProgressBar(
                        current = state.chapterIndex,
                        count = state.chapters.size,
                        hasPrev = state.canPrev,
                        hasNext = state.canNext,
                        onPrev = viewModel::prevChapter,
                        onNext = viewModel::nextChapter,
                        onSeek = { viewModel.jumpToChapter(it) }
                    )
                }
            }
        }

        // ---------- 目录抽屉（通用外壳 + 小说专用列表） ----------
        ReaderTocDrawer(
            visible = state.showToc,
            background = colors.background,
            onDismiss = { viewModel.toggleToc(false) }
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

        // ---------- 右下角「朗读」悬浮球（朗读中隐藏，改由左下角进度球接管） ----------
        AnimatedVisibility(
            visible = !ttsActive,
            enter = fadeIn(tween(180)),
            exit = fadeOut(tween(180)),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 16.dp, bottom = 72.dp)
        ) {
            TtsFab(onClick = viewModel::startTtsFromFab)
        }

        // ---------- 左下角「朗读进度」悬浮球 ----------
        AnimatedVisibility(
            visible = ttsActive,
            enter = slideInHorizontally { -it } + fadeIn(),
            exit = slideOutHorizontally { -it } + fadeOut(),
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(start = 16.dp, bottom = 72.dp)
        ) {
            TtsProgressOrb(
                title = state.book?.title.orEmpty(),
                coverPath = state.book?.coverPath,
                progress = ttsProgress,
                playing = state.tts.speaking,
                onTogglePlay = { 
                    if (state.tts.speaking) viewModel.pauseTts() 
                    else viewModel.resumeTts() 
                },
                onClose = viewModel::cancelTts
            )
        }

        // ---------- 听读设置 ----------
        AnimatedVisibility(
            visible = showTtsSettings,
            enter = slideInVertically { it },
            exit = slideOutVertically { it },
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            TtsSettingsPanel(
                rate = state.settings.ttsRate,
                pitch = state.settings.ttsPitch,
                timbre = state.settings.ttsTimbre,
                autoNext = state.settings.ttsAutoNext,
                voices = ttsVoices,
                voiceName = state.settings.ttsVoiceName,
                onRate = viewModel::setTtsRate,
                onPitch = viewModel::setTtsPitch,
                onTimbre = viewModel::setTtsTimbre,
                onAutoNext = { viewModel.updateSettings { s -> s.copy(ttsAutoNext = it) } },
                onVoice = viewModel::setTtsVoice,
                onOpenSystemTts = {
                    viewModel.openSystemTtsSettings()
                    showTtsSettings = false
                },
                onDismiss = { showTtsSettings = false }
            )
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
                pageTurnMode = state.settings.pageTurnMode,
                onPageTurn = { viewModel.updateSettings { s -> s.copy(pageTurnMode = it) } },
                onOpenTtsSettings = {
                    // 关掉阅读设置面板再开听读设置，避免两块面板叠在一起
                    viewModel.toggleSettings(false)
                    showTtsSettings = true
                },
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

/**
 * 单块渲染。
 * 首行缩进由 TextStyle.textIndent 承担（与分页测量同一套规则）；
 * [isContinuation] 为 true 表示本块从上一页延续而来，不缩进。
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
        BookBlock.Break -> androidx.compose.foundation.layout.Spacer(Modifier.height(12.dp))
    }
}