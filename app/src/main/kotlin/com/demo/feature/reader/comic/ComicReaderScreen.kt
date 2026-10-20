package com.demo.feature.reader.comic

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import kotlinx.coroutines.launch

import coil.compose.AsyncImage

import com.demo.core.model.ComicDirection
import com.demo.core.ui.glass.GlassSurface
import com.demo.feature.reader.common.ReaderSettingsPanel
import com.demo.core.ui.theme.ReaderShapes

@Composable
fun ComicReaderScreen(
    viewModel: ComicReaderViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val paths by viewModel.paths.collectAsStateWithLifecycle()
    val pages = state.pages
    val pagerState = rememberPagerState(
        initialPage = state.pageIndex.coerceAtLeast(0),
        pageCount = { pages.size.coerceAtLeast(1) }
    )
    val scope = rememberCoroutineScope()
    var showSettings by remember { mutableStateOf(false) }

    LaunchedEffect(pages.size) {
        if (pages.isNotEmpty()) {
            runCatching { pagerState.scrollToPage(state.pageIndex.coerceIn(0, pages.lastIndex)) }
        }
    }

    LaunchedEffect(pagerState.currentPage) {
        if (pages.isNotEmpty()) viewModel.onPageChanged(pagerState.currentPage)
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
            HorizontalPager(
                state = pagerState,
                beyondViewportPageCount = state.settings.comicPreload.coerceIn(1, 3),
                modifier = Modifier.fillMaxSize()
            ) { index ->
                val path = paths[index]
                ZoomablePage(
                    path = path,
                    onTap = { viewModel.toggleOverlay() }
                )
            }
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
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(8.dp),
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
                    Text(
                        text = "${state.pageIndex + 1}/${pages.size}",
                        style = MaterialTheme.typography.labelLarge
                    )
                    IconButton(onClick = { showSettings = true }) {
                        Icon(Icons.Default.Settings, contentDescription = "设置")
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
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
                shape = ReaderShapes.large
            ) {
                Column(Modifier.padding(12.dp)) {
                    if (pages.size > 1) {
                        Slider(
                            value = (state.pageIndex + 1).toFloat(),
                            onValueChange = { target ->
                                scope.launch {
                                    runCatching {
                                        pagerState.animateScrollToPage((target.toInt() - 1).coerceIn(0, pages.lastIndex))
                                    }
                                }
                            },
                            valueRange = 1f..pages.size.toFloat(),
                            steps = (pages.size - 2).coerceAtLeast(0),
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        ComicDirection.entries.forEach { direction ->
                            FilterChip(
                                selected = state.settings.comicDirection == direction,
                                onClick = {
                                    viewModel.updateSettings { s -> s.copy(comicDirection = direction) }
                                },
                                label = { Text(labelOf(direction)) }
                            )
                        }
                        Spacer(Modifier.weight(1f))
                        FilterChip(
                            selected = state.settings.comicDoublePage,
                            onClick = {
                                viewModel.updateSettings { s -> s.copy(comicDoublePage = !s.comicDoublePage) }
                            },
                            label = { Text("双页") }
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
                onDismiss = { showSettings = false }
            )
        }
    }
}

@Composable
private fun ZoomablePage(path: String?, onTap: () -> Unit) {
    var scale by remember { mutableFloatStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    val state = rememberTransformableState { zoomChange, panChange, _ ->
        scale = (scale * zoomChange).coerceIn(1f, 4f)
        offset = if (scale > 1f) offset + panChange else Offset.Zero
    }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(Unit) {
                detectTapGestures(
                    onTap = { onTap() },
                    onDoubleTap = {
                        scale = if (scale > 1f) 1f else 2f
                        offset = Offset.Zero
                    }
                )
            }
            .transformable(state = state),
        contentAlignment = Alignment.Center
    ) {
        if (path == null) {
            CircularProgressIndicator()
        } else {
            AsyncImage(
                model = path,
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer(
                        scaleX = scale,
                        scaleY = scale,
                        translationX = offset.x,
                        translationY = offset.y
                    )
            )
        }
    }
}

private fun labelOf(direction: ComicDirection): String = when (direction) {
    ComicDirection.LTR -> "从左"
    ComicDirection.RTL -> "从右"
    ComicDirection.VERTICAL -> "竖向"
}
