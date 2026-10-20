package com.demo.core.ui.glass

import android.os.Build
import androidx.compose.foundation.shape.RoundedCornerShape
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
 * 液态玻璃Modifier：
 * 1) 半透明底色
 * 2) API 31+ 背景模糊（低版本自动降级为纯半透明）
 * 3) 渐变高光描边（模拟玻璃折射边缘）
 * 4) 顶部反光层
 */
fun Modifier.glass(
    shape: Shape = ReaderShapes.large,
    tint: Color = Color.White,
    tintAlpha: Float = 0.14f,
    blurRadius: Dp = 18.dp,
    strokeAlpha: Float = 0.45f,
    showReflection: Boolean = true
): Modifier = this
    .then(
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && blurRadius.value > 0f) {
            Modifier.blur(blurRadius)
        } else Modifier
    )
    .drawWithCache {
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
