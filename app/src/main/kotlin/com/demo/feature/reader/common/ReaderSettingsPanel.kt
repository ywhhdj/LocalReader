package com.demo.feature.reader.common

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.FormatSize
import androidx.compose.material.icons.filled.RecordVoiceOver
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp


import com.demo.core.model.PageTurnMode
import com.demo.core.model.ReaderBackground
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.ReaderShapes
import com.demo.core.ui.components.AppSlider
import com.demo.feature.reader.common.readerColors
import com.demo.feature.reader.common.readerOnColor

/**
 * 阅读设置面板（小说 / 漫画共用）
 *
 * @param showTextSettings 是否显示字号 / 行距（漫画不需要）
 * @param onOpenToc 非空时显示「目录」入口：关闭面板并打开目录抽屉，点击章节即跳转
 */
@Composable
fun ReaderSettingsPanel(
    fontSize: Int,
    lineHeight: Float,
    background: ReaderBackground,
    keepScreenOn: Boolean,
    volumeTurn: Boolean,
    onFontSize: (Int) -> Unit,
    onLineHeight: (Float) -> Unit,
    onBackground: (ReaderBackground) -> Unit,
    onKeepScreenOn: (Boolean) -> Unit,
    onVolumeTurn: (Boolean) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    showTextSettings: Boolean = true,
    onOpenToc: (() -> Unit)? = null,
    /** 非空时显示「翻页动画」选择（仅小说） */
    pageTurnMode: PageTurnMode? = null,
    onPageTurn: ((PageTurnMode) -> Unit)? = null,
    /** 非空时显示「听读设置」入口（仅小说） */
    onOpenTtsSettings: (() -> Unit)? = null,
    /**
     * 面板内容色：阅读器背景可能是深色（夜间），
     * 之前统一取 onSurface，夜间背景下会出现"黑底黑字"。
     */
    contentColor: Color = Color.Unspecified
) {
    val bgColor= readerColors(background)
    // 未显式指定时按底色亮度反推，保证任何背景下文字都可读
    val resolved = if (contentColor != Color.Unspecified) contentColor else readerOnColor(bgColor)
    GlassSurface(
        modifier = modifier
            .fillMaxWidth()
            .padding(12.dp),
        backgroundColor= bgColor,
        shape = ReaderShapes.extraSmall,
        contentColor = resolved
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(Modifier
                .fillMaxWidth()
                //垂直居中
                
            ){
                // 目录入口：点开抽屉后可直接跳章 / 跳卷
                if (onOpenToc != null) {
                    FilterChip(
                        selected = false,
                        onClick = onOpenToc,
                        label = { Text(
                            "目录",
                            style = MaterialTheme.typography.labelLarge
                        ) },
                        leadingIcon = {
                            Icon(
                                Icons.AutoMirrored.Filled.List,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp)
                            )
                        },
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    Spacer(Modifier.width(10.dp))
                }
                if (onOpenTtsSettings != null) {
                    FilterChip(
                        selected = false,
                        onClick = onOpenTtsSettings,
                        label = { Text(
                            "听读设置",
                            style = MaterialTheme.typography.labelLarge,
                            color = resolved
                        ) },
                        leadingIcon = {
                            Icon(
                                Icons.Default.RecordVoiceOver,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp)
                            )
                        },
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }
            
            if (showTextSettings) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.FormatSize, contentDescription = null)
                    Text("字号 ${fontSize}sp",
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.padding(start = 8.dp),
                        color = resolved
                    )
                    AppSlider(
                        value = fontSize.toFloat(),
                        onValueChange = { onFontSize(it.toInt()) },
                        valueRange = 14f..24f,
                        steps = 9,
                        modifier = Modifier
                            .weight(1f)
                            .padding(start = 8.dp)
                    )
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "行距",
                        style = MaterialTheme.typography.labelLarge,
                        color = resolved
                    )
                    AppSlider(
                        value = lineHeight,
                        onValueChange = { onLineHeight(it) },
                        valueRange = 1.6f..3.2f,
                        modifier = Modifier
                            .weight(1f)
                            .padding(start = 12.dp)
                    )
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "背景", 
                    style = MaterialTheme.typography.labelLarge,
                    color = resolved
                )
                Spacer(Modifier.weight(1f))
                ReaderBackground.entries.forEach { bg ->
                    FilterChip(
                        selected = bg == background,
                        onClick = { onBackground(bg) },
                        label = { Text(labelOf(bg)) },
                        modifier = Modifier.padding(start = 4.dp)
                    )
                }
            }
            if (pageTurnMode != null && onPageTurn != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("翻页动画", style = MaterialTheme.typography.labelLarge)
                    Spacer(Modifier.width(8.dp))
                    PageTurnMode.entries.forEach { mode ->
                        FilterChip(
                            selected = mode == pageTurnMode,
                            onClick = { onPageTurn(mode) },
                            label = { Text(
                                mode.label,
                                color = resolved
                            ) },
                            modifier = Modifier.padding(start = 4.dp)
                        )
                    }
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "屏幕常亮", 
                    style = MaterialTheme.typography.labelLarge,
                    color = resolved
                )
                Spacer(Modifier.weight(1f))
                Switch(checked = keepScreenOn, onCheckedChange = onKeepScreenOn)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "音量键翻页",
                    style = MaterialTheme.typography.labelLarge,
                    color = resolved,
                )
                Spacer(Modifier.weight(1f))
                Switch(checked = volumeTurn, onCheckedChange = onVolumeTurn)
            }
        }
    }
}

private fun labelOf(bg: ReaderBackground): String = when (bg) {
    ReaderBackground.PAPER -> "纸白"
    ReaderBackground.CREAM -> "米黄"
    ReaderBackground.NIGHT -> "夜间"
    ReaderBackground.GREEN -> "护眼"
}
