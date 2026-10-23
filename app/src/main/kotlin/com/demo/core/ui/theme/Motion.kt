package com.demo.core.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.withFrameNanos

import com.demo.core.common.util.DeviceTier

/**
 * 动效配置：由 [ReaderTheme] 注入，组件按需读取。
 *
 * @param animationsEnabled 界面动效总开关。关闭后：
 *  - 背景光斑静止（不创建任何动画帧循环）；
 *  - 小说翻页退化为直接切换；
 *  - 顶栏/底栏/面板的进出动画退化为瞬时显示。
 * @param frameIntervalMs 持续型动画的帧间隔（毫秒），0 表示跟随系统刷新率。
 *  30fps 档位下背景光斑与翻页帧循环每秒只更新 30 次，显著降低滚动/翻页时的 GPU 压力。
 */
data class MotionConfig(
    val animationsEnabled: Boolean = true,
    val frameIntervalMs: Long = 0L,
    val deviceTier: DeviceTier = DeviceTier.MID
) {
    /** 时长在关闭动效时退化为 0（配合 rememberTween 使用） */
    fun durationMs(base: Int): Int = if (animationsEnabled) base else 0
}

val LocalMotionConfig = staticCompositionLocalOf { MotionConfig() }

/** 按配置折算动画时长：关闭动效时为 0 */
@Composable
fun motionDuration(baseMs: Int): Int = LocalMotionConfig.current.durationMs(baseMs)

/**
 * 背景光斑的往复进度 0f..1f。
 *
 * - 关闭动效：恒为 0.5f（偏移为 0），且不启动任何帧循环；
 * - 开启动效：按 [frameIntervalMs] 节流推进，避免 120Hz 屏上无意义的满帧重绘。
 */
@Composable
fun rememberBackdropProgress(
    enabled: Boolean,
    frameIntervalMs: Long,
    durationMs: Int = 12_000
): Float {
    var progress by remember(enabled) { mutableFloatStateOf(0f) }
    if (!enabled) return 0.5f
    LaunchedEffect(enabled, frameIntervalMs, durationMs) {
        while (true) {
            runThrottledFrameLoop(durationMs.toLong(), frameIntervalMs) { progress = it }
            runThrottledFrameLoop(durationMs.toLong(), frameIntervalMs) { progress = 1f - it }
        }
    }
    return progress
}

/**
 * 带帧率节流的帧循环：每帧只做时间计算，只有跨过 [frameIntervalMs] 才回调 [onProgress]。
 *
 * @param frameIntervalMs <= 0 时不节流（跟随系统刷新率）
 */
suspend fun runThrottledFrameLoop(
    durationMs: Long,
    frameIntervalMs: Long,
    onProgress: (Float) -> Unit
) {
    if (durationMs <= 0L) {
        onProgress(1f)
        return
    }
    val startNanos = withFrameNanos { it }
    var lastEmitMs = -1L
    var elapsedMs = 0L
    while (elapsedMs < durationMs) {
        val nowNanos = withFrameNanos { it }
        elapsedMs = ((nowNanos - startNanos) / 1_000_000L).coerceIn(0L, durationMs)
        val reachedEnd = elapsedMs >= durationMs
        if (frameIntervalMs <= 0L || reachedEnd || elapsedMs - lastEmitMs >= frameIntervalMs) {
            lastEmitMs = elapsedMs
            onProgress(elapsedMs.toFloat() / durationMs.toFloat())
        }
    }
}
