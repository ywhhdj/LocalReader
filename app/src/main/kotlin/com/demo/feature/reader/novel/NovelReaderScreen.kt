package com.demo.feature.reader.novel

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.statusBars
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.foundation.layout.Arrangement

import coil.compose.AsyncImage

import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.BookBlock
import com.demo.core.model.Chapter
import com.demo.core.model.PageTurnMode
import com.demo.core.ui.components.VolumeTocList
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.LocalMotionConfig
import com.demo.core.ui.theme.SheetShape
import com.demo.feature.reader.common.ImmersiveModeEffect
import com.demo.feature.reader.common.KeepScreenOnEffect
import com.demo.feature.reader.common.ReaderProgressBar
import com.demo.feature.reader.common.ReaderSettingsPanel
import com.demo.feature.reader.common.ReaderTapZone
import com.demo.feature.reader.common.ReaderTocDrawer
import com.demo.feature.reader.common.ReaderTopBar
import com.demo.feature.reader.common.readerColors
import com.demo.feature.reader.common.readerContentColor
import com.demo.feature.reader.common.readerSecondaryColor
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
    var pageIndex by remember(state.chapterIndex) { mutableIntStateOf(0) }
    val ttsProgress by viewModel.ttsProgress.collectAsStateWithLifecycle()
    var showTtsSettings by remember { mutableStateOf(false) }
    var forward by remember { mutableStateOf(true) }
    /** 朗读会话是否激活（朗读中 / 已暂停都算，保证进度球不闪） */
    val ttsActive = state.ttsActive
    /** 系统语音列表：ViewModel 异步拉取，引擎就绪后自动刷新（不再在组合期同步阻塞读取） */
    val ttsVoices by viewModel.ttsVoices.collectAsStateWithLifecycle()
    val bgColor = readerColors(state.settings.readerBackground)
    // 目录切分（卷名识别 + 标题清洗）较重，按章节列表缓存，避免每次重组都重算一遍
    val tocEntries = remember(state.chapters) { VolumeSplitter.tocEntries(state.chapters) }
    // 前景色随背景走：夜间背景下正文/目录/底栏文字自动转浅色
    val contentColor = readerContentColor(state.settings.readerBackground)
    val motion = LocalMotionConfig.current
    
    // 关闭动效时翻页退化为直接切换
    val turnMode = if (motion.animationsEnabled) state.settings.pageTurnMode else PageTurnMode.NONE
    val currentChapter = state.chapters.getOrNull(state.chapterIndex)
    // 沉浸模式：状态栏收起，正文顶到屏幕最上沿
    val insets = rememberReaderInsets(state.settings.immersiveMode)

    KeepScreenOnEffect(state.settings.keepScreenOn)
    ImmersiveModeEffect(state.settings.immersiveMode)

    // 打开听读设置时再拉一次语音列表（引擎可能刚好才初始化完）
    LaunchedEffect(showTtsSettings) {
        if (showTtsSettings) viewModel.refreshTtsVoices()
    }

    // 章节切换 → 回到该章首页
    LaunchedEffect(state.chapterIndex, pageIndex) {
        viewModel.onScrollPosition(state.chapterIndex, pageIndex)
    }

    if (state.loading && state.blocks.isEmpty()) {
        Box(
            modifier.fillMaxSize().background(bgColor),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = contentColor)
        }
        return
    }

    BoxWithConstraints(
        modifier = modifier
            .fillMaxSize()
            .background(bgColor)
    ) {
        val density = LocalDensity.current
        val textMeasurer = rememberTextMeasurer()

        val statusBarHeight = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
        val topHeaderTop = if (state.settings.immersiveMode) 10.dp else 10.dp+insets.top
        val topHeaderHeight = if (state.settings.immersiveMode) {
            statusBarHeight.coerceAtLeast(24.dp)
        } else {
            32.dp
        }
        // 正文从章节名下方开始（+4dp 视觉间隔）；分页测量与渲染共用这一个值
        val contentTopPadding = topHeaderTop + topHeaderHeight

        val pageWidthPx = with(density) {
            (maxWidth - ContentHorizontalPadding * 2).toPx().toInt().coerceAtLeast(1)
        }
        val pageHeightPx = with(density) {
            (maxHeight - contentTopPadding - insets.bottom).toPx().toInt().coerceAtLeast(1)
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

        // 排版参数（引用比较，避免整章 blocks 做值相等比较）
        val paginationKey = remember(
            allBlocks, state.settings.fontSize, state.settings.lineHeightMultiplier,
            pageWidthPx, pageHeightPx
        ) {
            PaginationKey(
                chapterIndex = state.chapterIndex,
                blocks = allBlocks,
                fontSize = state.settings.fontSize,
                lineHeightMultiplier = state.settings.lineHeightMultiplier,
                pageWidth = pageWidthPx,
                pageHeight = pageHeightPx
            )
        }

        /**
         * 分页不再在组合期同步执行。
         *
         * 旧写法 `remember { paginateNovel(...) }` 会在**组合帧内**测量整章几千个块，
         * 长章节占用主线程数百毫秒～数秒，直接表现为切章黑屏 / 掉帧 / ANR。
         * 这里改为：首帧先给出缓存（或空页），排版放到 LaunchedEffect 里执行 ——
         * 组合帧不再被阻塞，界面保持可响应。
         *
         * 注意：TextMeasurer 不是线程安全的，因此这里仍然跑在主线程，
         * 只是**不在组合帧内**；真正下沉到后台线程需要先把文本测量换成自绘排版。
         */
        var pages by remember { mutableStateOf(NovelPaginationCache.get(paginationKey) ?: listOf(NovelPage(emptyList()))) }
        LaunchedEffect(paginationKey) {
            NovelPaginationCache.get(paginationKey)?.let { pages = it; return@LaunchedEffect }
            // 切章/改字号时先清空，避免上一章的页内容在本帧残留
            pages = listOf(NovelPage(emptyList()))
            val result = paginateNovel(
                measurer = textMeasurer,
                blocks = paginationKey.blocks,
                pageWidth = paginationKey.pageWidth,
                pageHeight = paginationKey.pageHeight,
                fontSize = paginationKey.fontSize,
                lineHeightMultiplier = paginationKey.lineHeightMultiplier,
                density = density
            )
            NovelPaginationCache.put(paginationKey, result)
            pages = result
        }

        // 字号/行距变化后页数会变少，副作用里把越界页码收回
        LaunchedEffect(pages.size) {
            if (pageIndex > pages.lastIndex) pageIndex = pages.lastIndex.coerceAtLeast(0)
        }
        val safePageIndex = pageIndex.coerceIn(0, pages.lastIndex.coerceAtLeast(0))

        fun goNext() {
            forward = true
            if (safePageIndex < pages.lastIndex) pageIndex = safePageIndex + 1
            else if (state.canNext) viewModel.nextChapter()
        }

        fun goPrev() {
            forward = false
            if (safePageIndex > 0) pageIndex = safePageIndex - 1
            else if (state.canPrev) viewModel.prevChapter()
        }

        // ---------- 当前页内容（含左右滑动手势 + 可切换的翻页动画） ----------
        val renderPageContent: @Composable (Int) -> Unit = { idx ->
            val page = pages.getOrNull(idx)
            Column(Modifier.fillMaxSize()) {
                page?.items?.forEach { item ->
                    BlockView(
                        block = item.block,
                        fontSize = state.settings.fontSize,
                        lineHeight = state.settings.lineHeightMultiplier,
                        color = contentColor,
                        isContinuation = item.isContinuation
                    )
                }
            }
        }

        // ---------- 当前页内容（含手势 + 翻页动画） ----------
        Box(Modifier.fillMaxSize()) {

            // ---------- 翻页层（底层）：正文从顶部章节名下方开始 ----------
            PageTurnContainer(
                pageIndex = safePageIndex,
                forward = forward,
                mode = turnMode,
                backgroundColor = bgColor,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(
                        start = ContentHorizontalPadding,
                        end = ContentHorizontalPadding,
                        top = contentTopPadding,
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
                    .pointerInput(Unit) {
                        detectTapGestures(onTap = {
                            showChrome = !showChrome
                            viewModel.toggleSettings(false)
                            viewModel.toggleToc(false)
                        })
                    }
            ) { idx ->
                SelectionContainer { renderPageContent(idx) }
            }

            // ---------- 顶部章节名（上层，不与正文重叠） ----------
            // 除每章第一页外都显示；沉浸模式贴顶顶替状态栏，非沉浸模式在状态栏下方
            if (safePageIndex > 0) {
                val topChapterTitle = remember(state.chapterIndex, currentChapter) {
                    currentChapter?.let { VolumeSplitter.displayTitle(it) }.orEmpty()
                }
                Row(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .fillMaxWidth()
                        .padding(top = topHeaderTop)
                        .height(topHeaderHeight)
                        .padding(start = ContentHorizontalPadding, end = ContentHorizontalPadding),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "返回",
                        tint = contentColor.copy(alpha = 0.55f),
                        modifier = Modifier
                            .size(20.dp)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                onClick = onBack
                            )
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        text = topChapterTitle,
                        style = MaterialTheme.typography.labelMedium,
                        color = contentColor.copy(alpha = 0.5f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            // ---------- 右上/右下角按住预览真实下一页内容 ----------
            PageCornerPeekLayer(
                enabled = turnMode == PageTurnMode.SIMULATION,
                onPeekCommit = { goNext() },
                previewContent = {
                    val nextIdx = safePageIndex + 1
                    Box(
                        Modifier
                            .fillMaxSize()
                            .background(bgColor)
                            .padding(
                                start = ContentHorizontalPadding,
                                end = ContentHorizontalPadding,
                                top = contentTopPadding,
                                bottom = insets.bottom
                            )
                    ) {
                        if (nextIdx < pages.size) {
                            renderPageContent(nextIdx)
                        } else {
                            Column(
                                modifier = Modifier
                                    .align(Alignment.BottomEnd)
                                    .padding(end = 22.dp, bottom = 22.dp),
                                horizontalAlignment = Alignment.End,
                            ) {
                                Text(
                                    "下一章",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                                Text(
                                    "第 ${state.chapterIndex + 2} 章",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = contentColor.copy(alpha = 0.65f),
                                )
                            }
                        }
                    }
                }
            )
        }

        // ---------- 左下 / 右下热区 ----------
        val canPrevPage = safePageIndex > 0
        ReaderTapZone(
            alignment = Alignment.BottomStart,
            enabled = !showChrome && !state.showToc && !state.showSettings &&
                (canPrevPage || state.canPrev),
            onClick = { goPrev() }
        )

        val canNextPage = safePageIndex < pages.lastIndex
        ReaderTapZone(
            alignment = Alignment.BottomEnd,
            enabled = !showChrome && !state.showToc && !state.showSettings &&
                (canNextPage || state.canNext),
            onClick = { goNext() }
        )

        // ---------- 顶栏（通用） ----------
        ReaderTopBar(
            visible = showChrome,
            title = state.book?.title.orEmpty(),
            onBack = onBack,
            modifier = Modifier.align(Alignment.TopCenter),
            backgroundColor = bgColor,
            contentColor = contentColor,
            immersive = state.settings.immersiveMode,
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
                backgroundColor = bgColor,
                contentColor = contentColor
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
                        style = MaterialTheme.typography.labelMedium,
                        color = contentColor
                    )
                    // 章节进度条（通用）：拖动本地值，松手跳章
                    ReaderProgressBar(
                        current = state.chapterIndex,
                        count = state.chapters.size,
                        hasPrev = state.canPrev,
                        hasNext = state.canNext,
                        onPrev = viewModel::prevChapter,
                        onNext = viewModel::nextChapter,
                        onSeek = { viewModel.jumpToChapter(it) },
                        contentColor = readerSecondaryColor(state.settings.readerBackground)
                    )
                }
            }
        }

        // ---------- 目录抽屉（通用外壳 + 小说专用列表） ----------
        ReaderTocDrawer(
            visible = state.showToc,
            background = bgColor,
            onDismiss = { viewModel.toggleToc(false) }
        ) {
            VolumeTocList(
                entries = tocEntries,
                currentIndex = state.chapterIndex,
                textColor = contentColor,
                onSelect = { index ->
                    viewModel.jumpToChapter(index)
                    viewModel.toggleToc(false)
                },
                header = {
                    Text(
                        "目录",
                        style = MaterialTheme.typography.titleMedium,
                        color = contentColor,
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
                .padding(end = 16.dp, bottom = 80.dp)
        ) {
            TtsFab(onClick = viewModel::startTtsFromFab)
        }

        // ---------- 左下角「朗读进度」悬浮球 ----------
        DraggableTtsProgressOrb(
            title = state.book?.title.orEmpty(),
            coverPath = state.book?.coverPath,
            progress = ttsProgress,
            playing = state.tts.speaking,
            onTogglePlay = {
                if (state.tts.speaking) viewModel.pauseTts()
                else viewModel.resumeTts()
            },
            onClose = viewModel::cancelTts,
            visible = ttsActive,
        )

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
                bgColor = bgColor,
                contentColor = contentColor,
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
                contentColor = contentColor,
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
    color: Color,
    isContinuation: Boolean = false
) {
    when (block) {
        is BookBlock.Heading -> Text(
            text = block.text,
            style = MaterialTheme.typography.titleMedium.copy(
                color = color,
                fontSize = (fontSize + 2).sp,
                lineHeight = (fontSize * lineHeight).sp,
                fontWeight = FontWeight.Bold
            ),
            modifier = Modifier.padding(vertical = 8.dp)
        )
        is BookBlock.Paragraph -> Text(
            text = block.text,
            style = MaterialTheme.typography.bodyLarge.copy(
                color = color,
                fontSize = fontSize.sp,
                lineHeight = (fontSize * lineHeight).sp,
                textAlign = TextAlign.Start,
                textIndent = paragraphIndent(fontSize, isContinuation)
            ),
            modifier = Modifier.padding(vertical = 6.dp)
        )
        is BookBlock.Quote -> Text(
            text = block.text,
            color = color,
            style = MaterialTheme.typography.bodyMedium.copy(
                color = color.copy(alpha = 0.75f),
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
        BookBlock.Break -> androidx.compose.foundation.layout.Spacer(Modifier.height(12.dp))
    }
}