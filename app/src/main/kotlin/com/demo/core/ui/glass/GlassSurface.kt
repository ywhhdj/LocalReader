package com.demo.core.ui.glass

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.contentColorFor
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.Alignment

import com.demo.core.ui.theme.LocalGlassConfig
import com.demo.core.ui.theme.ReaderShapes

/** 液态玻璃容器：统一的圆角 + 玻璃质感 + 内容色 */
@Composable
fun GlassSurface(
    modifier: Modifier = Modifier,
    shape: Shape = ReaderShapes.extraSmall,
    tintAlpha: Float? = null,
    blurRadiusDp: Int? = null,
    onClick: (() -> Unit)? = null,
    alignment:Alignment = Alignment.Center,
    content: @Composable () -> Unit
) {
    val config = LocalGlassConfig.current
    val tint = if (config.tint == Color.Unspecified) Color.White else config.tint
    val alpha = tintAlpha ?: config.level.tintAlpha
    val blur = (blurRadiusDp ?: config.level.blurRadiusDp).dp
    val clickable = if (onClick != null) {
        Modifier.clickable(
            interactionSource = remember { MutableInteractionSource() },
            indication = null,
            role = Role.Button,
            onClick = onClick
        )
    } else Modifier

    val contentColor = contentColorFor(MaterialTheme.colorScheme.surface)
    androidx.compose.runtime.CompositionLocalProvider(LocalContentColor provides contentColor) {
        Box(
            modifier = modifier
                .clip(shape)
                .glass(
                    shape = shape,
                    tint = tint,
                    tintAlpha = alpha,
                    blurRadius = blur,
                    strokeAlpha = config.strokeAlpha
                )
                .then(clickable),
            contentAlignment = alignment
        ) {
            content()
        }
    }
}

/** 玻璃圆形按钮（主题切换、设置等图标按钮容器） */
@Composable
fun GlassIconButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    GlassSurface(
        modifier = modifier,
        shape = CircleShape,
        tintAlpha = LocalGlassConfig.current.level.tintAlpha + 0.04f,
        onClick = onClick,
        content = content
    )
}

/** 半透明填充（用于列表项内，避免列表滚动中的实时模糊开销） */
@Composable
fun SoftSurface(
    modifier: Modifier = Modifier,
    shape: Shape = ReaderShapes.extraSmall,
    alpha: Float = 0.10f,
    content: @Composable () -> Unit
) {
    val tint = MaterialTheme.colorScheme.onSurface
    Box(
        modifier = modifier
            .clip(shape)
            .background(tint.copy(alpha = alpha), shape)
    ) { content() }
}
