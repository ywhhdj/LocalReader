package com.demo.core.ui.glass

import android.os.Build
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

import com.demo.core.ui.theme.ReaderShapes

/**
 * 液态玻璃「绘制层」：半透明底色 + 渐变高光描边 + 顶部反光。
 *
 * 只做绘制（drawBehind），**不套 blur**，因此：
 * 1) 不会连同子内容（文字 / 封面）一起被模糊 —— 这是旧实现最明显的显示问题；
 * 2) 滚动列表里的玻璃卡片不再每帧触发 RenderEffect 模糊，快滑不再掉帧。
 *
 * brush / outline 在 drawWithCache 里只构建一次，尺寸或颜色变化时才重建。
 */
fun Modifier.glassPaint(
    shape: Shape = ReaderShapes.large,
    tint: Color = Color.White,
    tintAlpha: Float = 0.14f,
    strokeAlpha: Float = 0.45f,
    showReflection: Boolean = true
): Modifier = this.drawWithCache {
    val outline = shape.createOutline(size, layoutDirection, this)
    val strokeBrush = Brush.linearGradient(
        colors = listOf(
            Color.White.copy(alpha = strokeAlpha),
            Color.White.copy(alpha = strokeAlpha * 0.25f),
            Color.White.copy(alpha = 0.05f)
        ),
        start = Offset.Zero,
        end = Offset(size.width, size.height)
    )
    val reflectionBrush = Brush.verticalGradient(
        colors = listOf(Color.White.copy(alpha = 0.20f), Color.Transparent),
        startY = 0f,
        endY = size.height * 0.42f
    )
    onDrawBehind {
        drawOutline(outline, color = tint.copy(alpha = tintAlpha))
        if (showReflection) {
            drawRect(brush = reflectionBrush, size = Size(size.width, size.height * 0.42f))
        }
        drawOutline(outline, brush = strokeBrush, style = Stroke(width = 1.2f))
    }
}

/**
 * 真实模糊（API 31+ 的 RenderEffect）。
 *
 * 只对**独立的背景层**使用：Compose 的 blur 作用于该节点及其子节点，
 * 一旦加在容器上，里面的文字与图片会一起变糊。
 * 低端设备由 [com.demo.core.ui.theme.GlassConfig.allowBlur] 统一关掉。
 */
fun Modifier.glassBlur(radius: Dp): Modifier =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && radius.value > 0f) {
        this.blur(radius)
    } else {
        this
    }

/** 旧版组合入口（blur + 绘制）：仅供不需要子内容清晰的独立背景层使用 */
fun Modifier.glass(
    shape: Shape = ReaderShapes.large,
    tint: Color = Color.White,
    tintAlpha: Float = 0.14f,
    blurRadius: Dp = 18.dp,
    strokeAlpha: Float = 0.45f,
    showReflection: Boolean = true
): Modifier = this
    .glassBlur(blurRadius)
    .glassPaint(
        shape = shape,
        tint = tint,
        tintAlpha = tintAlpha,
        strokeAlpha = strokeAlpha,
        showReflection = showReflection
    )
