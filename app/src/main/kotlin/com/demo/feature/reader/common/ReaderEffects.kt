package com.demo.feature.reader.common

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalView

/**
 * 屏幕常亮。
 *
 * 用 DisposableEffect 而非 LaunchedEffect：退出 / 页面销毁时主动清掉 keepScreenOn，
 * 避免影响其它界面的电源策略。
 */
@Composable
fun KeepScreenOnEffect(enabled: Boolean) {
  val view = LocalView.current
  DisposableEffect(enabled) {
    view.keepScreenOn = enabled
    onDispose { view.keepScreenOn = false }
  }
}