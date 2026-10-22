package com.demo.feature.reader.common

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

import com.demo.core.ui.glass.GlassSurface

/**
 * 阅读器顶栏：返回 / 标题（可选副标题）/ 自定义操作按钮。
 *
 * 玻璃外壳、状态栏避让、显隐动画都封装在这里；右侧按钮通过 [actions] slot 注入，
 * 不同阅读器按需拼装（小说：朗读/目录/设置，漫画：目录/设置）。
 *
 * @param backgroundColor 玻璃面板底色；不指定则沿用 [GlassSurface] 默认值
 */
@Composable
fun ReaderTopBar(
  visible: Boolean,
  title: String,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
  subtitle: String? = null,
  backgroundColor: Color = Color.Unspecified,
  actions: @Composable RowScope.() -> Unit = {}
) {
  AnimatedVisibility(
    visible = visible,
    enter = slideInVertically { -it },
    exit = slideOutVertically { -it },
    modifier = modifier
  ) {
    GlassSurface(
      modifier = Modifier.fillMaxWidth(),
      shape = RoundedCornerShape(bottomStart = 24.dp, bottomEnd = 24.dp),
      backgroundColor = backgroundColor
    ) {
      Column(
        modifier = Modifier
          .fillMaxWidth()
          .padding(WindowInsets.statusBars.asPaddingValues())
      ) {
        Row(
          modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
          verticalAlignment = Alignment.CenterVertically
        ) {
          IconButton(onClick = onBack) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
          }
          Column(modifier = Modifier.weight(1f)) {
            Text(
              text = title,
              style = MaterialTheme.typography.titleMedium,
              maxLines = 1
            )
            if (!subtitle.isNullOrBlank()) {
              Text(
                text = subtitle,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                maxLines = 1
              )
            }
          }
          actions()
        }
      }
    }
  }
}