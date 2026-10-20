package com.demo.feature.reader.common

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FormatSize
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

import com.demo.core.model.ReaderBackground
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.ReaderShapes

/** 阅读设置面板（小说/漫画共用） */
@Composable
fun ReaderSettingsPanel(
    fontSize: Int,
    lineHeight: Float,
    background: ReaderBackground,
    keepScreenOn: Boolean,
    volumeTurn: Boolean,
    onFontSize: (Int) -> Unit,
    onLineHeight: (Float) -> Unit,
    onBackground: (ReaderBackground) -> Unit,
    onKeepScreenOn: (Boolean) -> Unit,
    onVolumeTurn: (Boolean) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    GlassSurface(
        modifier = modifier
            .fillMaxWidth()
            .padding(12.dp),
        shape = ReaderShapes.extraSmall
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.FormatSize, contentDescription = null)
                Text("字号 ${fontSize}sp", style = MaterialTheme.typography.labelLarge,
                    modifier = Modifier.padding(start = 8.dp))
                Slider(
                    value = fontSize.toFloat(),
                    onValueChange = { onFontSize(it.toInt()) },
                    valueRange = 14f..24f,
                    steps = 9,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 8.dp)
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("行距", style = MaterialTheme.typography.labelLarge)
                Slider(
                    value = lineHeight,
                    onValueChange = { onLineHeight(it) },
                    valueRange = 1.2f..2.2f,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 12.dp)
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("背景", style = MaterialTheme.typography.labelLarge)
                androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
                ReaderBackground.entries.forEach { bg ->
                    FilterChip(
                        selected = bg == background,
                        onClick = { onBackground(bg) },
                        label = { Text(labelOf(bg)) },
                        modifier = Modifier.padding(start = 4.dp)
                    )
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("屏幕常亮", style = MaterialTheme.typography.labelLarge)
                androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
                Switch(checked = keepScreenOn, onCheckedChange = onKeepScreenOn)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("音量键翻页", style = MaterialTheme.typography.labelLarge)
                androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
                Switch(checked = volumeTurn, onCheckedChange = onVolumeTurn)
            }
        }
    }
}

private fun labelOf(bg: ReaderBackground): String = when (bg) {
    ReaderBackground.PAPER -> "纸白"
    ReaderBackground.CREAM -> "米黄"
    ReaderBackground.NIGHT -> "夜间"
    ReaderBackground.GREEN -> "护眼"
}
