package com.demo.feature.reader.novel

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.background
import kotlin.math.abs
import kotlin.math.max


import com.demo.core.model.PageTurnMode
import com.demo.core.ui.theme.LocalMotionConfig
import com.demo.core.ui.theme.runThrottledFrameLoop

private const val TURN_DURATION_MS = 260
private const val CURL_TURN_DURATION_MS = 420
/** 仿真翻页：背面页整体压暗系数（替代每帧 saveLayer） */
private const val BACK_PAGE_ALPHA = 0.55f
private const val TUBE_RATIO = 0.62f

/**
 * 右上 / 右下角「按住翻页预览」。
 *
 * 关键设计：
 *  全屏 Box 不挂 pointerInput，触摸逻辑只在右侧窄条上监听；
 *  避免 `awaitEachGesture` 的 finally 长时间占位打断下层 `detectTapGestures`，
 *  预览内容层、Canvas 绘制层仍全屏，负责显示和绘制；
 *  松手判定沿用 `maxSeen >= maxSize * armRatio`。
 */
@Composable
fun PageCornerPeekLayer(
    enabled: Boolean,
    onPeekCommit: () -> Unit,
    modifier: Modifier = Modifier,
    armRatio: Float = 0.6f,
    previewContent: (@Composable BoxScope.() -> Unit)? = null,
) {
    val density = LocalDensity.current
    val baseSizePx = with(density) { 40.dp.toPx() }
    val maxSizePx = with(density) { 200.dp.toPx() }
    val grabThresholdPx = with(density) { 6.dp.toPx() }
    // 触摸监听窄条宽度：卷角永远出现在右侧，所以只需要监听这一条
    val touchWidthDp = 120.dp

    var active by remember { mutableStateOf(false) }
    var cornerTop by remember { mutableStateOf(true) }
    var peekSize by remember { mutableFloatStateOf(0f) }

    val animatedSize by animateFloatAsState(
        targetValue = if (active) peekSize else 0f,
        animationSpec = tween(
            durationMillis = if (active) 60 else 240,
            easing = FastOutSlowInEasing,
        ),
        label = "peekSize",
    )
    val previewVisible by remember { derivedStateOf { animatedSize > 0.5f } }

    val fillPath = remember { Path() }
    val strokePath = remember { Path() }
    val clipPathObj = remember { Path() }

    Box(modifier = modifier.fillMaxSize()) {
        // ---------- 预览内容（全屏铺底，靠 clipPath 裁到卷角范围） ----------
        if (previewContent != null && previewVisible) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .drawWithContent {
                        val s = animatedSize
                        if (s > 0.5f) {
                            buildCornerPath(clipPathObj, size, s, cornerTop)
                            clipPath(clipPathObj) {
                                this@drawWithContent.drawContent()
                            }
                        }
                    }
            ) {
                previewContent()
            }
        }

        // ---------- 卷角本体（Canvas 只绘制，不拦截触摸） ----------
        Canvas(modifier = Modifier.fillMaxSize()) {
            val s = animatedSize
            if (s <= 0.5f) return@Canvas
            val w = size.width
            val h = size.height
            val isTop = cornerTop

            val corner = if (isTop) Offset(w, 0f) else Offset(w, h)
            val alongTop = if (isTop) Offset(w - s, 0f) else Offset(w - s, h)
            val alongSide = if (isTop) Offset(w, s) else Offset(w, h - s)
            val ctrl = if (isTop) {
                Offset(w - s * 0.72f, s * 0.72f)
            } else {
                Offset(w - s * 0.72f, h - s * 0.72f)
            }

            // 外投影
            fillPath.reset()
            fillPath.moveTo(alongTop.x, alongTop.y)
            fillPath.lineTo(alongTop.x - s * 0.18f, alongTop.y)
            fillPath.lineTo(alongSide.x, alongSide.y + if (isTop) s * 0.18f else -s * 0.18f)
            fillPath.lineTo(alongSide.x, alongSide.y)
            fillPath.close()
            drawPath(fillPath, Color.Black.copy(alpha = 0.08f))

            // 卷角本体
            buildCornerPath(fillPath, size, s, isTop)
            val brush = Brush.linearGradient(
                colors = listOf(
                    Color.White.copy(alpha = 0.12f),
                    Color.Black.copy(alpha = 0.34f),
                ),
                start = corner,
                end = if (isTop) Offset(w - s, s) else Offset(w - s, h - s),
            )
            drawPath(fillPath, brush)

            // 折痕描边
            strokePath.reset()
            strokePath.moveTo(alongTop.x, alongTop.y)
            strokePath.quadraticTo(ctrl.x, ctrl.y, alongSide.x, alongSide.y)
            drawPath(
                strokePath,
                Color.Black.copy(alpha = 0.30f),
                style = Stroke(width = 1.2.dp.toPx()),
            )
        }

        // ---------- 触摸层：只在右侧窄条上监听 ----------
        Box(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .fillMaxHeight()
                .width(touchWidthDp)
                .pointerInput(enabled, armRatio, baseSizePx, maxSizePx, grabThresholdPx) {
                    if (!enabled) return@pointerInput
                    awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = false)
                        val h = size.height.toFloat()
                        val y = down.position.y
                        val inCorner = y < h * 0.28f || y > h * 0.72f
                        if (!inCorner) return@awaitEachGesture

                        val isTop = y < h * 0.5f
                        cornerTop = isTop
                        active = true
                        peekSize = baseSizePx
                        var maxSeen = baseSizePx
                        var grabbed = false
                        val pointerId = down.id
                        val stripWidth = size.width.toFloat()

                        while (true) {
                            val ev = awaitPointerEvent()
                            val ch = ev.changes.firstOrNull { it.id == pointerId }
                            if (ch == null || !ch.pressed) break
                            val pos = ch.position
                            val cornerY = if (isTop) 0f else h
                            // 窄条坐标系：pos.x 从窄条左边界起算，右侧 = stripWidth - pos.x
                            val dx = (stripWidth - pos.x) * 3f
                            val dy = abs(pos.y - cornerY) * 1.2f
                            val newSize = max(baseSizePx, max(dx, dy)).coerceAtMost(maxSizePx)
                            peekSize = newSize
                            if (newSize > maxSeen) maxSeen = newSize
                            if (!grabbed && newSize > baseSizePx + grabThresholdPx) {
                                grabbed = true
                            }
                            if (grabbed) ch.consume()
                        }

                        active = false
                        if (maxSeen >= maxSizePx * armRatio) {
                            onPeekCommit()
                        }
                    }
                }
        )
    }
}

/** 卷角三角形（弧线折痕），供绘制和裁剪共用 */
private fun buildCornerPath(path: Path, size: Size, s: Float, isTop: Boolean) {
    val w = size.width
    val h = size.height
    path.reset()
    if (isTop) {
        path.moveTo(w, 0f)
        path.lineTo(w - s, 0f)
        path.quadraticTo(w - s * 0.72f, s * 0.72f, w, s)
        path.close()
    } else {
        path.moveTo(w, h)
        path.lineTo(w - s, h)
        path.quadraticTo(w - s * 0.72f, h - s * 0.72f, w, h - s)
        path.close()
    }
}

/**
 * 按 [mode] 渲染翻页过渡。
 */
@Composable
fun PageTurnContainer(
    pageIndex: Int,
    forward: Boolean,
    mode: PageTurnMode,
    modifier: Modifier = Modifier,
    backgroundColor: Color = Color.Transparent,
    content: @Composable (Int) -> Unit
) {
    val wrapped: @Composable (Int) -> Unit = { idx ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(backgroundColor)
        ) {
            content(idx)
        }
    }

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
        ) { idx -> wrapped(idx) }

        PageTurnMode.NONE -> Box(modifier = modifier) { wrapped(pageIndex) }

        PageTurnMode.SIMULATION -> CurlPageTurn(
            pageIndex = pageIndex,
            forward = forward,
            modifier = modifier,
            content = wrapped
        )
    }
}

/**
 * 卷边翻页。
 *
 * 卷边方向**永远从右往左**，[forward] 不再影响几何：
 * - 翻下一页：底层 = 新页，旧页从右边卷起；
 * - 翻上一页：底层 = 上一页，旧页（当前页）同样从右边卷起。
 */
@Composable
private fun CurlPageTurn(
    pageIndex: Int,
    forward: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable (Int) -> Unit
) {
    var base by remember { mutableStateOf(pageIndex) }
    var outgoing by remember { mutableStateOf<Int?>(null) }
    var progress by remember { mutableFloatStateOf(0f) }
    var turnForward by remember { mutableStateOf(forward) }
    val frameIntervalMs = LocalMotionConfig.current.frameIntervalMs

    LaunchedEffect(pageIndex) {
        if (pageIndex == base) return@LaunchedEffect
        outgoing = base
        base = pageIndex
        turnForward = forward
        progress = 0f
        runThrottledFrameLoop(CURL_TURN_DURATION_MS.toLong(), frameIntervalMs) { raw ->
            progress = FastOutSlowInEasing.transform(raw)
        }
        progress = 1f
        outgoing = null
    }

    // 上一页 → 卷边从左向右；下一页 → 卷边从右向左
    val mirror = !turnForward

    Box(modifier = modifier) {
        // 新页：全程正视（底/上层统一）
        Box(modifier = Modifier.matchParentSize()) { content(base) }

        outgoing?.let { old ->
            val p = progress.coerceIn(0f, 1f)

            // 旧页正面：卷轴内侧，仍平铺
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .drawWithContent {
                        val g = curlGeometry(size.width, p, mirror)
                        if (g.frontR > g.frontL) {
                            clipRect(
                                left = g.frontL,
                                top = 0f,
                                right = g.frontR.coerceAtMost(size.width),
                                bottom = size.height
                            ) { this@drawWithContent.drawContent() }
                        }
                    }
            ) { content(old) }

            // 旧页背面：卷筒区域，镜像压缩 + 内容降 alpha + 底色压暗
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .graphicsLayer {
                        val g = curlGeometry(size.width, p, mirror)
                        scaleX = g.scaleX
                        translationX = g.translationX
                        transformOrigin = TransformOrigin(0f, 0.5f)
                        // 背面压暗。旧实现在这里每帧 drawIntoCanvas + saveLayer + new Paint()：
                        // 每帧都分配一块全屏离屏缓冲和一个 Paint 对象，中低端机 420ms 动画明显掉帧。
                        // 用 graphicsLayer 的 alpha 直接合成，省掉离屏缓冲与对象分配。
                        alpha = BACK_PAGE_ALPHA
                    }
                    .drawWithContent {
                        val g = curlGeometry(size.width, p, mirror)
                        if (g.backR > g.backL) {
                            clipRect(
                                left = g.backL,
                                top = 0f,
                                right = g.backR.coerceAtMost(size.width),
                                bottom = size.height
                            ) {
                                this@drawWithContent.drawContent()
                                drawRect(
                                    color = Color.Black.copy(alpha = 0.30f),
                                    topLeft = Offset(g.backL, 0f),
                                    size = Size(g.backR - g.backL, size.height)
                                )
                                drawRect(
                                    brush = Brush.horizontalGradient(
                                        listOf(
                                            Color.Black.copy(alpha = 0.40f),
                                            Color.Transparent,
                                            Color.Transparent,
                                            Color.Black.copy(alpha = 0.32f)
                                        ),
                                        startX = g.backL,
                                        endX = g.backR
                                    ),
                                    topLeft = Offset(g.backL, 0f),
                                    size = Size(g.backR - g.backL, size.height)
                                )
                            }
                        }
                    }
            ) { content(old) }

            // 卷轴阴影（随 mirror 镜像）
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .drawBehind {
                        val g = curlGeometry(size.width, p, mirror)
                        val tube = g.curlR - g.curlL
                        if (tube > 0.5f) {
                            val shade = 18.dp.toPx()
                            if (!mirror) {
                                // 下一页：折痕在左侧 curlL
                                val axis = g.curlL
                                drawRect(
                                    brush = Brush.horizontalGradient(
                                        listOf(Color.Transparent, Color.Black.copy(alpha = 0.16f)),
                                        startX = axis - shade,
                                        endX = axis + shade * 0.2f
                                    ),
                                    topLeft = Offset((axis - shade).coerceAtLeast(0f), 0f),
                                    size = Size(shade * 1.2f, size.height)
                                )
                                val edge = g.curlR
                                drawRect(
                                    brush = Brush.horizontalGradient(
                                        listOf(Color.Black.copy(alpha = 0.14f), Color.Transparent),
                                        startX = edge - shade * 0.5f,
                                        endX = edge
                                    ),
                                    topLeft = Offset((edge - shade * 0.5f).coerceAtLeast(0f), 0f),
                                    size = Size(shade * 0.5f, size.height)
                                )
                            } else {
                                // 上一页：折痕在右侧 curlR
                                val axis = g.curlR
                                drawRect(
                                    brush = Brush.horizontalGradient(
                                        listOf(Color.Black.copy(alpha = 0.16f), Color.Transparent),
                                        startX = axis - shade * 0.2f,
                                        endX = axis + shade
                                    ),
                                    topLeft = Offset((axis - shade * 0.2f).coerceAtLeast(0f), 0f),
                                    size = Size(shade * 1.2f, size.height)
                                )
                                val edge = g.curlL
                                drawRect(
                                    brush = Brush.horizontalGradient(
                                        listOf(Color.Transparent, Color.Black.copy(alpha = 0.14f)),
                                        startX = edge,
                                        endX = edge + shade * 0.5f
                                    ),
                                    topLeft = Offset(edge.coerceAtLeast(0f), 0f),
                                    size = Size(shade * 0.5f, size.height)
                                )
                            }
                        }
                    }
            )
        }
    }
}

private class CurlGeometry(
    val frontL: Float,
    val frontR: Float,
    val backL: Float,
    val backR: Float,
    val scaleX: Float,
    val translationX: Float,
    val curlL: Float,
    val curlR: Float
)

private fun smoothStep(edge0: Float, edge1: Float, x: Float): Float {
    val t = ((x - edge0) / (edge1 - edge0)).coerceIn(0f, 1f)
    return t * t * (3f - 2f * t)
}

/**
 * 卷边几何。
 * - mirror=false：卷轴从右向左（翻下一页）
 * - mirror=true ：卷轴从左向右（翻上一页），几何以 [0, width] 水平镜像
 */
private fun curlGeometry(width: Float, p: Float, mirror: Boolean): CurlGeometry {
    val w = width.coerceAtLeast(1f)
    val exit = smoothStep(0.72f, 1f, p)
    val axisF = (w * (1f - p) - w * 0.72f * exit).coerceIn(-w, w)
    val rolled = (w - axisF).coerceIn(0f, w)
    val tube = (TUBE_RATIO * rolled * (1f - exit)).coerceAtLeast(0f)
    val len = rolled.coerceAtLeast(1f)
    val scale = -(tube / len).coerceAtLeast(0.0001f)

    return if (!mirror) {
        // 下一页：正面 [0, axisF]，卷轴 [axisF, axisF+tube]，背面 [axisF, w]
        val beta = axisF + tube + tube * axisF / len
        CurlGeometry(
            frontL = 0f,
            frontR = axisF,
            backL = axisF,
            backR = w,
            scaleX = scale,
            translationX = beta,
            curlL = axisF,
            curlR = axisF + tube
        )
    } else {
        // 上一页：镜像后 正面 [axisB, w]，卷轴 [axisB-tube, axisB]，背面 [0, axisB]
        val axisB = w - axisF
        CurlGeometry(
            frontL = axisB,
            frontR = w,
            backL = 0f,
            backR = axisB,
            scaleX = scale,
            translationX = axisB,
            curlL = axisB - tube,
            curlR = axisB
        )
    }
}