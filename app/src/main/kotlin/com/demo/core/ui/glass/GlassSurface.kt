package com.demo.core.ui.glass

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
import androidx.compose.foundation.background
import androidx.compose.runtime.CompositionLocalProvider

import com.demo.core.ui.theme.LocalGlassConfig
import com.demo.core.ui.theme.ReaderShapes

/**
 * 液态玻璃容器：统一的圆角 + 玻璃质感 + 内容色。
 *
 * 结构拆成「背景玻璃层 + 内容层」两层：
 * - 玻璃层只负责绘制（半透明底色 / 描边 / 反光），可选真实模糊；
 * - 内容层在玻璃层之上，**永远清晰**。
 *
 *
 * @param blur 是否对玻璃层做真实模糊（RenderEffect）。默认 false：
 *   1) 真实模糊在滚动列表里代价极高；
 *   2) 中低端机由 [com.demo.core.ui.theme.GlassConfig.allowBlur] 统一降级。
 *   只有固定不随滚动的面板（底栏 / FAB / 对话框）才建议开启。
 * @param contentColor 内容色，用于自定义底色（如阅读器夜间背景）时保证文字对比度。
 */
@Composable
fun GlassSurface(
    modifier: Modifier = Modifier,
    shape: Shape = ReaderShapes.extraSmall,
    tintAlpha: Float? = null,
    blurRadiusDp: Int? = null,
    blur: Boolean = false,
    onClick: (() -> Unit)? = null,
    alignment: Alignment = Alignment.Center,
    /** 非 Unspecified 时，在玻璃层下方先铺一层纯色背景，完全挡住底层内容 */
    backgroundColor: Color = Color.Unspecified,
    contentColor: Color = Color.Unspecified,
    content: @Composable () -> Unit
) {
    val config = LocalGlassConfig.current
    val tint = if (config.tint == Color.Unspecified) Color.White else config.tint
    val alpha = tintAlpha ?: config.level.tintAlpha
    val blurRadius = (blurRadiusDp ?: config.level.blurRadiusDp).dp
    val allowBlur = blur && config.allowBlur
    val clickable = if (onClick != null) {
        Modifier.clickable(
            interactionSource = remember { MutableInteractionSource() },
            indication = null,
            role = Role.Button,
            onClick = onClick
        )
    } else Modifier

    // 给了自定义底色时，内容色按该底色推导（夜间背景上文字自动转浅色）
    val resolvedContent = when {
        contentColor != Color.Unspecified -> contentColor
        backgroundColor != Color.Unspecified -> contentColorFor(backgroundColor)
        else -> contentColorFor(MaterialTheme.colorScheme.surface)
    }

    CompositionLocalProvider(LocalContentColor provides resolvedContent) {
        Box(
            modifier = modifier
                .clip(shape)
                .then(
                    if (backgroundColor != Color.Unspecified)
                        Modifier.background(backgroundColor, shape)
                    else Modifier
                )
                .then(clickable),
            contentAlignment = alignment   // ← 新增：内容层在容器内居中
        ) {
            // 玻璃层
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .then(if (allowBlur) Modifier.glassBlur(blurRadius) else Modifier)
                    .glassPaint(
                        shape = shape,
                        tint = tint,
                        tintAlpha = alpha,
                        strokeAlpha = config.strokeAlpha
                    )
            )
            Box(contentAlignment = alignment) {
                content()
            }
        }
    }
}