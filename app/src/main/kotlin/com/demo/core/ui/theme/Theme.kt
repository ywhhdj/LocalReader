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
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

import com.demo.core.model.ThemeMode
import com.demo.core.ui.glass.GlassLevel

/** 玻璃配置（由 ReaderTheme 注入，组件读取） */
data class GlassConfig(
    val level: GlassLevel = GlassLevel.OFF,
    val tint: Color = Color.Unspecified,
    val strokeAlpha: Float = 0.45f
)

val LocalGlassConfig = staticCompositionLocalOf { GlassConfig() }

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
    content: @Composable () -> Unit
) {
    val dark = when (themeMode) {
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
    }
    val context = LocalContext.current
    val useDynamic = dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
    val colorScheme = when {
        useDynamic && dark -> dynamicDarkColorScheme(context)
        useDynamic && !dark -> dynamicLightColorScheme(context)
        dark -> DarkColors
        else -> LightColors
    }
    val glassConfig = GlassConfig(
        level = glassLevel,
        tint = if (dark) GlassTintDark else GlassTintLight,
        strokeAlpha = if (dark) 0.32f else 0.45f
    )
    CompositionLocalProvider(LocalGlassConfig provides glassConfig) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = ReaderTypography,
            shapes = ReaderShapes,
            content = content
        )
    }
}
