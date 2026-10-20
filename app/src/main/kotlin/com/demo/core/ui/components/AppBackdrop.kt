package com.demo.core.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

/**
 * 应用背景：主题色渐变 + 两团缓慢漂移的光斑（低成本：仅绘制，不参与布局/测量）。
 * 为液态玻璃提供"有内容可折射"的底层，玻璃感更真实。
 */
@Composable
fun AppBackdrop(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    val primary = MaterialTheme.colorScheme.primary
    val secondary = MaterialTheme.colorScheme.secondary
    val bg = MaterialTheme.colorScheme.background

    val transition = rememberInfiniteTransition(label = "backdrop")
    val t by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 12_000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "blob"
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(bg)
            .drawWithCache {
                val w = size.width
                val h = size.height
                val blobA = Brush.radialGradient(
                    colors = listOf(primary.copy(alpha = 0.28f), Color.Transparent),
                    center = Offset(w * (0.15f + 0.12f * t), h * (0.12f + 0.08f * t)),
                    radius = w * 0.9f
                )
                val blobB = Brush.radialGradient(
                    colors = listOf(secondary.copy(alpha = 0.22f), Color.Transparent),
                    center = Offset(w * (0.88f - 0.10f * t), h * (0.42f + 0.06f * t)),
                    radius = w * 0.8f
                )
                val blobC = Brush.radialGradient(
                    colors = listOf(primary.copy(alpha = 0.14f), Color.Transparent),
                    center = Offset(w * 0.5f, h * (0.92f - 0.05f * t)),
                    radius = w * 1.0f
                )
                onDrawBehind {
                    drawRect(blobA)
                    drawRect(blobB)
                    drawRect(blobC)
                }
            }
    ) { content() }
}
