package com.demo.feature.reader.common

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp

private const val TAP_ZONE_WIDTH_RATIO = 0.32f
private const val TAP_ZONE_HEIGHT_RATIO = 0.22f

/**
 * 翻页点击热区：左下 / 右下角。
 *
 * 仅在 [enabled] 时响应点击并显示提示文字，提示文字半透明不抢视线。
 * 小说「上一页 / 下一页」常用；漫画连续滚动用不到。
 */
@Composable
fun BoxScope.ReaderTapZone(
  alignment: Alignment,
  enabled: Boolean,
  onClick: () -> Unit,
  label: String? = null,
  textColor: Color? = null,
  modifier: Modifier = Modifier,
  widthRatio: Float = TAP_ZONE_WIDTH_RATIO,
  heightRatio: Float = TAP_ZONE_HEIGHT_RATIO
) {
  val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
  // 用最新的回调，但手势只按 enabled 重建：否则每次重组都重启一次手势检测
  val currentOnClick = rememberUpdatedState(onClick)
  Box(
    modifier = modifier
      .fillMaxWidth(widthRatio)
      .fillMaxHeight(heightRatio)
      .align(alignment)
      .padding(bottom = bottomInset)
      .then(
        if (enabled) {
          Modifier.pointerInput(enabled) {
            detectTapGestures(onTap = { currentOnClick.value() })
          }
        } else Modifier
      )
  ) {
    if (enabled && label != null) {
      Text(
        text = label,
        style = MaterialTheme.typography.labelSmall,
        color = if (textColor != null) textColor else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
        modifier = Modifier
        .align(
          if (alignment == Alignment.BottomStart) Alignment.BottomStart
          else Alignment.BottomEnd
        )
        .padding(12.dp)
      )
    }
  }
}