package com.demo.core.ui.components

import android.app.ActivityManager
import android.content.Context
import android.provider.Settings
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext

/**
 * 应用背景：主题色渐变 + 缓慢漂移的光斑。
 *
 * 性能设计：
 * 1. 光斑渐变只在 size/颜色变化时构建一次（drawWithCache 真正命中缓存）；
 * 2. 动画只修改 graphicsLayer 的 translation（合成阶段），不触发任何重绘；
 * 3. animated = false 时完全不创建 InfiniteTransition，退化为纯静态渐变；
 * 4. 默认在低内存设备或系统“移除动画”开启时自动静态化。
 */
@Composable
fun AppBackdrop(
    modifier: Modifier = Modifier,
    animated: Boolean = rememberBackdropAnimated(),
    content: @Composable () -> Unit
) {
    val primary = MaterialTheme.colorScheme.primary
    val secondary = MaterialTheme.colorScheme.secondary
    val bg = MaterialTheme.colorScheme.background
    // 动画值：静态模式下恒为 0.5f（偏移为 0），且不创建 transition
    val t: Float = if (animated) {
        val transition = rememberInfiniteTransition(label = "backdrop")
        val v by transition.animateFloat(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 12_000, easing = LinearEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "blob"
        )
        v
    } else {
        0.5f
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(bg)
    ) {
        // 光斑层：静态绘制 + 整体平移
        BackdropAnimated(
            animated, 
            t = t,
            primary = primary,
            secondary = secondary
        )
        content()
    }
}

/** 光斑动画组件 */
@Composable
fun BackdropAnimated(
    animated: Boolean = true,
    modifier: Modifier = Modifier,
    t: Float = 0.5f,
    primary: Color = MaterialTheme.colorScheme.primary,
    secondary: Color = MaterialTheme.colorScheme.secondary
){
    Box(
        Modifier
        .fillMaxSize()
        .graphicsLayer {
            if (animated) {
                // 只改 layer 属性，走合成，不重绘内容
                translationX = size.width * 0.10f * (t - 0.5f)   // ±5% 屏宽
                translationY = size.height * 0.06f * (t - 0.5f)  // ±3% 屏高
            }
        }
        .drawWithCache {
            val w = size.width
            val h = size.height
            // 中心固定：Brush 只构建一次，之后每帧复用
            val blobA = Brush.radialGradient(
                colors = listOf(primary.copy(alpha = 0.28f), Color.Transparent),
                center = Offset(w * 0.22f, h * 0.18f),
                radius = w * 0.9f
            )
            val blobB = Brush.radialGradient(
                colors = listOf(secondary.copy(alpha = 0.22f), Color.Transparent),
                center = Offset(w * 0.82f, h * 0.46f),
                radius = w * 0.8f
            )
            val blobC = Brush.radialGradient(
                colors = listOf(primary.copy(alpha = 0.14f), Color.Transparent),
                center = Offset(w * 0.5f, h * 0.90f),
                radius = w * 1.0f
            )
            onDrawBehind {
                drawRect(blobA)
                drawRect(blobB)
                drawRect(blobC)
            }
        }
    )
}


/**
 * 是否允许背景动画：
 * - 低内存设备（isLowRamDevice）直接关闭；
 * - 系统“移除动画 / 动画缩放为 0”时关闭，尊重无障碍设置。
 */
@Composable
fun rememberBackdropAnimated(): Boolean {
    val context = LocalContext.current
    val lowRam = remember(context) {
        (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager)
            .isLowRamDevice
    }
    val animationsDisabled = remember(context) {
        Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f
        ) == 0f
    }
    return !lowRam && !animationsDisabled
}