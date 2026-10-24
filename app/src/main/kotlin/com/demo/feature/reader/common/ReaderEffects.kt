package com.demo.feature.reader.common

import android.app.Activity
import android.view.WindowManager

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat

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

/**
 * 沉浸阅读：隐藏状态栏，正文/漫画顶到屏幕最上沿。
 *
 * - 隐藏方式用 [WindowInsetsCompat.Type.statusBars]，保留"顶部下滑临时呼出"的手势；
 * - 离开阅读页（DisposableEffect 回收）一定恢复显示，不会把状态栏带到别的界面。
 */
@Composable
fun ImmersiveModeEffect(enabled: Boolean) {
  val view = LocalView.current
  val context = LocalContext.current
  DisposableEffect(enabled, view) {
    val activity = context as? Activity
      ?: view.context as? Activity
    val window = activity?.window
    val controller = window?.let { WindowCompat.getInsetsController(it, view) }
    if (controller != null) {
      if (enabled) {
        controller.hide(WindowInsetsCompat.Type.statusBars())
      } else {
        controller.show(WindowInsetsCompat.Type.statusBars())
      }
    }
    onDispose {
      controller?.show(WindowInsetsCompat.Type.statusBars())
    }
  }
}