package com.demo.core.ui.glass

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

import com.demo.core.ui.theme.LocalGlassConfig
import com.demo.core.ui.theme.ReaderRadius

/**
 * 顶部导航容器（悬浮液态玻璃）：
 * 左：logo 位 / 返回； 中：标题或搜索框； 右：主题切换、设置等操作位。
 * 内容由调用方填充，保证各页面复用同一视觉基线。
 */
@Composable
fun GlassTopBar(
    modifier: Modifier = Modifier,
    scrolled: Boolean = false,
    navigationIcon: @Composable (() -> Unit)? = null,
    title: @Composable () -> Unit = {},
    actions: @Composable RowScope.() -> Unit = {}
) {
    val config = LocalGlassConfig.current
    val alpha = (if (scrolled) 0.22f else 0.10f) + config.level.tintAlpha * 0.4f
    Box(
        modifier = modifier
            .fillMaxWidth()
            .glass(
                shape = RoundedCornerShape(
                    bottomStart = ReaderRadius.L,
                    bottomEnd = ReaderRadius.L
                ),
                tint = Color.White,
                tintAlpha = alpha.coerceIn(0.06f, 0.28f),
                blurRadius = config.level.blurRadiusDp.dp,
                strokeAlpha = config.strokeAlpha
            ),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.statusBars)
                .height(56.dp)
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (navigationIcon != null) {
                Box(modifier = Modifier.padding(end = 4.dp)) { navigationIcon() }
            }
            Box(modifier = Modifier.weight(1f)) { title() }
            Row(content = actions)
        }
    }
}
