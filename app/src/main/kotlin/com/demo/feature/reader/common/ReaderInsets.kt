package com.demo.feature.reader.common

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.statusBars
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** 阅读器需要避让的系统栏高度 */
data class ReaderInsets(val top: Dp, val bottom: Dp)

/**
 * 一次性读取状态栏 / 导航栏高度。
 *
 * 不 remember：Insets 可能随系统栏显隐变化，必须随重组重新读取。
 *
 * @param immersive 沉浸模式下状态栏已收起，顶部不再留白（正文/漫画直接到顶）。
 */
@Composable
fun rememberReaderInsets(immersive: Boolean = false): ReaderInsets = ReaderInsets(
  top = if (immersive) 0.dp else WindowInsets.statusBars.asPaddingValues().calculateTopPadding(),
  bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
)
