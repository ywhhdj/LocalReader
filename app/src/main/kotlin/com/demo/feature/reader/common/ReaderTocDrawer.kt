package com.demo.feature.reader.common

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

/** 抽屉宽度占屏比 */
private const val TOC_WIDTH_RATIO = 0.7f

/**
 * 阅读器目录抽屉外壳：左滑入 + 0.7 宽内容区 + 半透明遮罩点击关闭。
 *
 * 目录内容（[VolumeTocList] / [ComicTocList]）由调用方通过 [content] 提供，
 * 抽屉方向、遮罩、宽度等交互统一在这里维护。
 */
@Composable
fun ReaderTocDrawer(
  visible: Boolean,
  background: Color,
  onDismiss: () -> Unit,
  modifier: Modifier = Modifier,
  content: @Composable () -> Unit
) {
  AnimatedVisibility(
    visible = visible,
    enter = slideInHorizontally { -it },
    exit = slideOutHorizontally { -it },
    modifier = modifier
  ) {
    Box(Modifier.fillMaxSize()) {
      // 遮罩只负责点空白关闭，不改变内容层透明度
      Box(
        Modifier
          .fillMaxSize()
          .background(Color.Transparent)
          .clickable(
              interactionSource = remember { MutableInteractionSource() },
              indication = null
          ) { onDismiss() }
      )
      Column(
        Modifier
          .fillMaxHeight()
          .fillMaxWidth(TOC_WIDTH_RATIO)
          .background(background)
      ) {
        content()
      }
    }
  }
}