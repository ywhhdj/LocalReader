package com.demo.core.ui.components

import android.app.ActivityManager
import android.content.Context
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext

import com.demo.core.ui.theme.LocalMotionConfig
import com.demo.core.ui.theme.rememberBackdropProgress

/**
 * 应用背景：主题色渐变 + 缓慢漂移的光斑。
 *
 * 性能设计：
 * 1. 光斑渐变只在 size/颜色变化时构建一次（drawWithCache 真正命中缓存）；
 * 2. 动画只修改 graphicsLayer 的 translation（走合成，不重绘内容）；
 * 3. 关闭动效（设置项「界面动效」或系统「移除动画」）时完全不启动帧循环，退化为静态渐变；
 * 4. 帧率上限（30fps 档）下按 [com.demo.core.ui.theme.MotionConfig.frameIntervalMs] 节流推进，
 *    120Hz 屏上不再无意义地满帧刷新；
 * 5. 每个光斑按半径裁剪绘制区域，减少全屏 overdraw。
 */
@Composable
fun AppBackdrop(
    modifier: Modifier = Modifier,
    /** null = 跟随设置（推荐）；也可由调用方强制开关 */
    animated: Boolean? = null,
    content: @Composable () -> Unit
) {
    val motion = LocalMotionConfig.current
    val systemAllows = rememberBackdropAnimated()
    val enabled = animated ?: (motion.animationsEnabled && systemAllows)
    val primary = MaterialTheme.colorScheme.primary
    val secondary = MaterialTheme.colorScheme.secondary
    val bg = MaterialTheme.colorScheme.background
    // 动画值：静态模式下恒为 0.5f（偏移为 0），且不启动任何帧循环
    val t: Float = rememberBackdropProgress(
        enabled = enabled,
        frameIntervalMs = motion.frameIntervalMs
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(bg)
    ) {
        // 光斑层：静态绘制 + 整体平移
        BackdropAnimated(
            animated = enabled,
            t = t,
            primary = primary,
            secondary = secondary
        )
        content()
    }
}

/** 光斑动画组件：内容只绘制一次，动画阶段只做图层平移 */
@Composable
fun BackdropAnimated(
    animated: Boolean = true,
    modifier: Modifier = Modifier,
    t: Float = 0.5f,
    primary: Color = MaterialTheme.colorScheme.primary,
    secondary: Color = MaterialTheme.colorScheme.secondary
) {
    Box(
        Modifier
            .then(modifier)
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
                val centerA = Offset(w * 0.22f, h * 0.18f)
                val radiusA = w * 0.9f
                val centerB = Offset(w * 0.82f, h * 0.46f)
                val radiusB = w * 0.8f
                val centerC = Offset(w * 0.5f, h * 0.90f)
                val radiusC = w * 1.0f
                val blobA = Brush.radialGradient(
                    colors = listOf(primary.copy(alpha = 0.28f), Color.Transparent),
                    center = centerA,
                    radius = radiusA
                )
                val blobB = Brush.radialGradient(
                    colors = listOf(secondary.copy(alpha = 0.22f), Color.Transparent),
                    center = centerB,
                    radius = radiusB
                )
                val blobC = Brush.radialGradient(
                    colors = listOf(primary.copy(alpha = 0.14f), Color.Transparent),
                    center = centerC,
                    radius = radiusC
                )
                onDrawBehind {
                    // 按光斑半径裁剪，避免每个光斑都按整屏绘制（减少 overdraw）
                    drawBlob(blobA, centerA, radiusA, w, h)
                    drawBlob(blobB, centerB, radiusB, w, h)
                    drawBlob(blobC, centerC, radiusC, w, h)
                }
            }
    )
}

/**
 * 是否允许背景动画（系统层面）：
 * - 低内存设备（isLowRamDevice）直接关闭；
 * - 系统“移除动画 / 动画缩放为 0”时关闭，尊重无障碍设置。
 * 应用内「界面动效」开关在 [AppBackdrop] 里再叠加一层判断。
 */
@Composable
fun rememberBackdropAnimated(): Boolean {
    val context = LocalContext.current
    return remember(context) {
        val lowRam = runCatching {
            (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).isLowRamDevice
        }.getOrDefault(false)
        val animationsDisabled = runCatching {
            Settings.Global.getFloat(
                context.contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f
            ) == 0f
        }.getOrDefault(false)
        !lowRam && !animationsDisabled
    }
}

/** 单个光斑：裁剪到外接矩形后再绘制，超出屏幕的部分不参与光栅化 */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawBlob(
    brush: Brush,
    center: Offset,
    radius: Float,
    width: Float,
    height: Float
) {
    if (radius <= 0f) return
    val left = (center.x - radius).coerceIn(0f, width)
    val top = (center.y - radius).coerceIn(0f, height)
    val right = (center.x + radius).coerceIn(0f, width)
    val bottom = (center.y + radius).coerceIn(0f, height)
    if (right <= left || bottom <= top) return
    clipRect(left, top, right, bottom) {
        drawRect(brush = brush, size = Size(width, height))
    }
}
