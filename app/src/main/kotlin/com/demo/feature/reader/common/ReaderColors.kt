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
    ReaderBackground.PAPER -> if (dark) {
      Color(0xFF15181E)
    } else {
      Color(0xFFFAFAFA)
    }
  }
}