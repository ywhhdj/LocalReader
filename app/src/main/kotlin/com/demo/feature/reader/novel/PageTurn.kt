package com.demo.feature.reader.novel

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer

import com.demo.core.model.PageTurnMode


private fun lerp(start: Float, stop: Float, fraction: Float): Float =
    start + (stop - start) * fraction

/** 翻页动画时长 */
private const val TURN_DURATION_MS = 260
/** 仿真翻页时长（略长一点，翻书动作才不显得生硬） */
private const val SIM_TURN_DURATION_MS = 420

/**
 * 按 [mode] 渲染翻页过渡。
 *
 * - [PageTurnMode.SLIDE]：左右平移（原行为）
 * - [PageTurnMode.SIMULATION]：伪 3D 仿真翻页——当前页绕书脊向背面翻 90°，
 *   新页从背面翻回 0°，翻动页叠加一层随进度加深的阴影。
 *   注意：这是"绕轴旋转 + 阴影"的近似实现，**不是逐像素卷曲**，
 *   不做网格变形与实时位图采样，性能与平移同级（纯 graphicsLayer，无额外绘制层）。
 * - [PageTurnMode.NONE]：无动画直接切换
 */
@Composable
fun PageTurnContainer(
    pageIndex: Int,
    forward: Boolean,
    mode: PageTurnMode,
    modifier: Modifier = Modifier,
    content: @Composable (Int) -> Unit
) {
    when (mode) {
        PageTurnMode.SLIDE -> AnimatedContent(
            targetState = pageIndex,
            transitionSpec = {
                if (forward) {
                    (slideInHorizontally(tween(TURN_DURATION_MS)) { it } + fadeIn(tween(TURN_DURATION_MS)))
                        .togetherWith(slideOutHorizontally(tween(TURN_DURATION_MS)) { -it } + fadeOut(tween(TURN_DURATION_MS)))
                } else {
                    (slideInHorizontally(tween(TURN_DURATION_MS)) { -it } + fadeIn(tween(TURN_DURATION_MS)))
                        .togetherWith(slideOutHorizontally(tween(TURN_DURATION_MS)) { it } + fadeOut(tween(TURN_DURATION_MS)))
                }
            },
            modifier = modifier,
            label = "pageTurnSlide"
        ) { idx -> content(idx) }

        PageTurnMode.NONE -> Box(modifier = modifier) { content(pageIndex) }

        PageTurnMode.SIMULATION -> SimulatedPageTurn(
            pageIndex = pageIndex,
            forward = forward,
            modifier = modifier,
            content = content
        )
    }
}

/**
 * 伪 3D 仿真翻页。
 *
 * 用 [androidx.compose.ui.graphics.graphicsLayer] 的 rotationY 绕页面边缘旋转：
 * - 正向：旧页 0° → -100°（绕左边缘向内），新页 100° → 0°；
 * - 反向：镜像处理。
 * 旋转中的页面叠一层渐变阴影（这里用 alpha 遮罩近似，不额外开绘制层）。
 */
@Composable
private fun SimulatedPageTurn(
    pageIndex: Int,
    forward: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable (Int) -> Unit
) {
    // 稳定渲染的页 + 正在翻出的页，动画结束后合并
    var base by remember { mutableStateOf(pageIndex) }
    var outgoing by remember { mutableStateOf<Int?>(null) }
    var animForward by remember { mutableStateOf(forward) }
    var progress by remember { androidx.compose.runtime.mutableFloatStateOf(0f) }

    LaunchedEffect(pageIndex, forward) {
        if (pageIndex == base) return@LaunchedEffect
        animForward = forward
        outgoing = base
        base = pageIndex
        val steps = SIM_TURN_DURATION_MS / 16
        val duration = SIM_TURN_DURATION_MS.toLong()
        val start = withFrameNanos { it }
        // 用帧循环推进：直接拿进度，省掉一层动画调度
        runFrameLoop(start, duration) { elapsed ->
            val raw = (elapsed.toFloat() / duration).coerceIn(0f, 1f)
            progress = FastOutSlowInEasing.transform(raw)
        }
        progress = 0f
        outgoing = null
    }

    Box(modifier = modifier) {
        // 新页（底层）：从背面翻回来
        Box(
            modifier = Modifier.matchParentSize().graphicsLayer {
                rotationY = if (animForward) lerp(90f, 0f, progress) else lerp(-90f, 0f, progress)
                cameraDistance = 24f * density
                transformOrigin = if (animForward) {
                    androidx.compose.ui.graphics.TransformOrigin(0f, 0.5f)
                } else {
                    androidx.compose.ui.graphics.TransformOrigin(1f, 0.5f)
                }
                alpha = if (progress <= 0f && outgoing == null) 1f else progress.coerceAtLeast(0.15f)
            }
        ) { content(base) }

        // 旧页（顶层）：翻向背面并淡出，模拟纸张背光
        outgoing?.let { old ->
            Box(
                modifier = Modifier.matchParentSize().graphicsLayer {
                    rotationY = if (animForward) -100f * progress else 100f * progress
                    cameraDistance = 24f * density
                    transformOrigin = if (animForward) {
                        androidx.compose.ui.graphics.TransformOrigin(0f, 0.5f)
                    } else {
                        androidx.compose.ui.graphics.TransformOrigin(1f, 0.5f)
                    }
                    alpha = (1f - progress).coerceIn(0f, 1f)
                    shadowElevation = 8f * progress
                }
            ) { content(old) }
        }
    }
}

/** 简单的帧循环：从 startNanos 起按 16ms 节奏回调已耗时长 */
private suspend fun runFrameLoop(
    startNanos: Long,
    durationMs: Long,
    onFrame: (Long) -> Unit
) {
    var elapsed = 0L
    while (elapsed < durationMs) {
        val now = withFrameNanos { it }
        elapsed = (now - startNanos) / 1_000_000L
        onFrame(elapsed.coerceIn(0L, durationMs))
    }
    onFrame(durationMs)
}
