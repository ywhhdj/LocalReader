package com.demo.feature.reader.common

import androidx.compose.ui.graphics.Color
import androidx.compose.runtime.Composable
import androidx.compose.material3.MaterialTheme

import com.demo.core.model.ReaderBackground

@Composable
fun readerColors(background: ReaderBackground): Color {
  val bg = MaterialTheme.colorScheme.background
  val dark = (bg.red + bg.green + bg.blue) / 3f < 0.5f
  return when (background) {
    ReaderBackground.CREAM -> Color(0xFFF6EFE2)
    ReaderBackground.GREEN -> Color(0xFFE8F0E3)
    ReaderBackground.NIGHT -> Color(0xFF12141A)
    ReaderBackground.PAPER -> Color(0xFFFAFAFA)
  }
}

/**
 * 阅读区**前景色**：由背景色亮度反推，保证任意背景（含夜间）下正文都有足够对比度。
 *
 * 之前正文统一取 `MaterialTheme.colorScheme.onSurface`：
 * 浅色主题 + 夜间背景时背景是深色、文字仍是深色，直接"黑底黑字"看不见。
 */
@Composable
fun readerContentColor(background: ReaderBackground): Color =
    readerOnColor(readerColors(background))

/**
 * 次要点文字色（页码 / 提示 / 目录次级信息）：正文色降透明度。
 * 直接对 Unspecified 做 copy(alpha) 会得到不可预期的透明色，这里保证底色始终具体。
 */
@Composable
fun readerSecondaryColor(background: ReaderBackground): Color =
    readerContentColor(background).copy(alpha = 0.68f)

/** 由背景亮度推导前景色：暗底 → 浅字，亮底 → 深字 */
fun readerOnColor(background: Color): Color {
    val luminance = 0.2126f * background.red +
        0.7152f * background.green +
        0.0722f * background.blue
    return if (luminance < 0.5f) Color(0xFFE9ECF2) else Color(0xFF1B1F24)
}
