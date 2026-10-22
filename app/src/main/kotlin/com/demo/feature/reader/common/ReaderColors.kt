package com.demo.feature.reader.common

import androidx.compose.ui.graphics.Color
import androidx.compose.runtime.Composable
import androidx.compose.material3.MaterialTheme

import com.demo.core.model.ReaderBackground

data class ReaderColors(
  val background: Color,
  val text: Color
)

@Composable
fun readerColors(background: ReaderBackground): ReaderColors {
  val bg = MaterialTheme.colorScheme.background
  val dark = (bg.red + bg.green + bg.blue) / 3f < 0.5f
  return when (background) {
    ReaderBackground.CREAM -> ReaderColors(Color(0xFFF6EFE2), Color(0xFF3B3226))
    ReaderBackground.GREEN -> ReaderColors(Color(0xFFE8F0E3), Color(0xFF2E3A2A))
    ReaderBackground.NIGHT -> ReaderColors(Color(0xFF12141A), Color(0xFFC7CBD1))
    ReaderBackground.PAPER -> if (dark) {
      ReaderColors(Color(0xFF15181E), Color(0xFFD6DAE0))
    } else {
      ReaderColors(Color(0xFFFAFAFA), Color(0xFF23262B))
    }
  }
}