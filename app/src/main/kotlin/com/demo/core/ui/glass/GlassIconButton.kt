package com.demo.core.ui.glass

import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.Modifier

import com.demo.core.ui.theme.LocalGlassConfig

/** 玻璃圆形按钮（主题切换、设置等图标按钮容器） */
@Composable
fun GlassIconButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    size: Dp = 40.dp,
    content: @Composable () -> Unit
) {
    GlassSurface(
        modifier = modifier.size(size),
        shape = CircleShape,
        tintAlpha = LocalGlassConfig.current.level.tintAlpha + 0.04f,
        onClick = onClick,
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            content()
        }
    }
}