package com.demo.core.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

import com.demo.core.common.util.DeviceTierDetector
import com.demo.core.model.FrameRateMode
import com.demo.core.model.ThemeMode
import com.demo.core.ui.glass.GlassLevel

/** 玻璃配置（由 ReaderTheme 注入，组件读取） */
data class GlassConfig(
    val level: GlassLevel = GlassLevel.OFF,
    val tint: Color = Color.Unspecified,
    val strokeAlpha: Float = 0.45f,
    /**
     * 是否允许真实背景模糊（RenderEffect）。
     * 中低端机（或系统不支持）自动降级为「静态玻璃」（半透明 + 描边 + 反光），
     * 避免列表滚动时每帧做高斯模糊导致掉帧。
     */
    val allowBlur: Boolean = false
)

val LocalGlassConfig = staticCompositionLocalOf { GlassConfig() }

/** fps → 帧间隔（毫秒）；<=0 表示不限制 */
private fun fpsToIntervalMs(fps: Int): Long = if (fps <= 0) 0L else (1000L / fps)

private val LightColors = lightColorScheme(
    primary = PrimaryLight,
    onPrimary = OnPrimaryLight,
    primaryContainer = PrimaryContainerLight,
    onPrimaryContainer = OnPrimaryContainerLight,
    secondary = SecondaryLight,
    tertiary = TertiaryLight,
    background = BackgroundLight,
    surface = SurfaceLight,
    surfaceVariant = SurfaceVariantLight,
    outline = OutlineLight
)

private val DarkColors = darkColorScheme(
    primary = PrimaryDark,
    onPrimary = OnPrimaryDark,
    primaryContainer = PrimaryContainerDark,
    onPrimaryContainer = OnPrimaryContainerDark,
    secondary = SecondaryDark,
    tertiary = TertiaryDark,
    background = BackgroundDark,
    surface = SurfaceDark,
    surfaceVariant = SurfaceVariantDark,
    outline = OutlineDark
)

@Composable
fun ReaderTheme(
    themeMode: ThemeMode = ThemeMode.SYSTEM,
    dynamicColor: Boolean = false,
    glassLevel: GlassLevel = GlassLevel.OFF,
    /** 界面动效总开关（设置项） */
    animationsEnabled: Boolean = true,
    /** 持续型动画帧率上限（设置项） */
    frameRateMode: FrameRateMode = FrameRateMode.AUTO,
    content: @Composable () -> Unit
) {
    val dark = when (themeMode) {
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
    }
    val context = LocalContext.current
    val tier = remember(context) { DeviceTierDetector.detect(context) }
    val useDynamic = dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
    val colorScheme = when {
        useDynamic && dark -> dynamicDarkColorScheme(context)
        useDynamic && !dark -> dynamicLightColorScheme(context)
        dark -> DarkColors
        else -> LightColors
    }
    val glassConfig = remember(glassLevel, dark, tier) {
        GlassConfig(
            level = glassLevel,
            tint = if (dark) GlassTintDark else GlassTintLight,
            strokeAlpha = if (dark) 0.32f else 0.45f,
            allowBlur = glassLevel != GlassLevel.OFF &&
                DeviceTierDetector.blurSupported() &&
                DeviceTierDetector.suggestBlur(tier)
        )
    }
    val motionConfig = remember(animationsEnabled, frameRateMode, tier) {
        val fps = if (frameRateMode == FrameRateMode.AUTO) {
            DeviceTierDetector.suggestFps(tier)
        } else {
            frameRateMode.fps
        }
        MotionConfig(
            animationsEnabled = animationsEnabled,
            frameIntervalMs = fpsToIntervalMs(fps),
            deviceTier = tier
        )
    }
    CompositionLocalProvider(
        LocalGlassConfig provides glassConfig,
        LocalMotionConfig provides motionConfig
    ) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = ReaderTypography,
            shapes = ReaderShapes,
            content = content
        )
    }
}
