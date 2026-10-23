package com.demo.feature.reader.common

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.demo.core.ui.components.AppSlider

/**
 * 阅读进度切换条：「上一章/话」- 滑块 - 「下一章/话」。
 *
 * 拖动过程只更新本地值，松手才回调 [onSeek] —— 避免逐帧触发跳转
 * （小说会重复解析章节、漫画会重复滚动并写库）。
 *
 * - 小说：滑块对应**章节**索引；
 * - 漫画：滑块对应**页**索引，两侧文字仍是"上一话 / 下一话"。
 *
 * @param current 当前位置的 0-based 索引
 * @param count 总长度（<=1 时不展示）
 * @param onSeek 松手后回调目标 0-based 索引
 */
@Composable
fun ReaderProgressBar(
  current: Int,
  count: Int,
  hasPrev: Boolean,
  hasNext: Boolean,
  onPrev: () -> Unit,
  onNext: () -> Unit,
  onSeek: (Int) -> Unit,
  modifier: Modifier = Modifier,
  prevLabel: String = "上一章",
  nextLabel: String = "下一章",
  /** 进度条文字色：阅读器自定义背景时用前景色，避免夜间背景黑字 */
  contentColor: Color = Color.Unspecified
) {
  val textColor = if (contentColor != Color.Unspecified) {
    contentColor
  } else {
    MaterialTheme.colorScheme.onSurfaceVariant
  }
  if (count <= 1) return

  // 拖动时只更新本地值，松手才跳：避免逐帧触发跳转
  var sliderValue by remember(count) { mutableFloatStateOf((current + 1).toFloat()) }
  LaunchedEffect(current) { sliderValue = (current + 1).toFloat() }

  Row(
    modifier = modifier.fillMaxWidth(),
    verticalAlignment = Alignment.CenterVertically
  ) {
    Text(
      text = prevLabel,
      style = MaterialTheme.typography.labelMedium,
      color = textColor,
      modifier = Modifier
        .clickable(enabled = hasPrev) { onPrev() }
        .padding(horizontal = 8.dp, vertical = 4.dp)
    )
    AppSlider(
      value = sliderValue,
      onValueChange = { sliderValue = it },
      onValueChangeFinished = {
          onSeek((sliderValue.toInt() - 1).coerceIn(0, count - 1))
      },
      valueRange = 1f..count.toFloat(),
      steps = (count - 2).coerceAtLeast(0),
      modifier = Modifier.weight(1f),
      rounded = true
    )
    Text(
      text = nextLabel,
      style = MaterialTheme.typography.labelMedium,
      color = textColor,
      modifier = Modifier
        .clickable(enabled = hasNext) { onNext() }
        .padding(horizontal = 8.dp, vertical = 4.dp)
    )
  }
}