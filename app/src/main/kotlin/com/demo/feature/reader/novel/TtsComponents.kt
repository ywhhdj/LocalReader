package com.demo.feature.reader.novel

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.RecordVoiceOver
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

import coil.compose.AsyncImage

import com.demo.core.model.TtsTimbre
import com.demo.core.model.TtsVoice
import com.demo.core.ui.components.AppSlider
import com.demo.core.ui.components.settings.VoiceRow
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.LocalMotionConfig
import com.demo.feature.reader.common.readerOnColor
import com.demo.core.ui.theme.CoverPlaceholderA
import com.demo.core.ui.theme.CoverPlaceholderB
import com.demo.core.ui.glass.GlassIconButton

/** 悬浮球尺寸 */
private val FabSize = 50.dp
/** 进度球内封面尺寸 */
private val OrbCoverSize = 44.dp
/** 环形进度条直径 */
private val OrbRingSize = 40.dp

/**
 * 右下角「朗读」悬浮球：点击开始朗读。
 * 开始朗读后由调用方隐藏本球，改用左下角 [TtsProgressOrb]。
 */
@Composable
fun TtsFab(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    GlassIconButton(
        size = FabSize,
        onClick = onClick
    ) {
        Icon(
            imageVector = Icons.Default.RecordVoiceOver,
            contentDescription = "朗读",
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(26.dp)
        )
    }
}

/**
 * 左下角「朗读进度」悬浮球：
 * `[旋转封面] [环形进度 + 播放/暂停] [关闭]`
 */
@Composable
fun TtsProgressOrb(
    title: String,
    coverPath: String?,
    progress: Float,
    playing: Boolean,
    onTogglePlay: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier
) {
    val shape = androidx.compose.foundation.shape.RoundedCornerShape(28.dp)
    Surface(
        modifier = modifier,
        shape = shape,
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.94f),
        contentColor = MaterialTheme.colorScheme.onSurface,
        tonalElevation = 4.dp,
        shadowElevation = 6.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            SpinningCover(
                title = title,
                coverPath = coverPath,
                spinning = playing
            )
            Spacer(Modifier.width(10.dp))
            Box(contentAlignment = Alignment.Center, modifier = Modifier.size(OrbRingSize)) {
                CircularProgressIndicator(
                    progress = {
                        progress.coerceIn(0f, 1f)
                    },
                    modifier = Modifier.size(OrbRingSize),
                    strokeWidth = 3.dp,
                    color = MaterialTheme.colorScheme.primary,
                    trackColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.18f)
                )
                IconButton(
                    onClick = onTogglePlay,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        imageVector = if (playing) Icons.Default.Pause else Icons.Default.PlayArrow,
                        contentDescription = if (playing) "暂停" else "继续",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
            IconButton(onClick = onClose, modifier = Modifier.size(32.dp)) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "关闭朗读",
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

/** 旋转封面：无封面时以书名首字 + 渐变填充 */
@Composable
private fun SpinningCover(
    title: String,
    coverPath: String?,
    spinning: Boolean
) {
    val motion = LocalMotionConfig.current
    // 关闭动效（或暂停）时目标值恒为 0：InfiniteTransition 不再产生有效变化
    val spinTarget = if (motion.animationsEnabled && spinning) 360f else 0f
    val transition = rememberInfiniteTransition(label = "ttsCover")
    val rotation by transition.animateFloat(
        initialValue = 0f,
        targetValue = spinTarget,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 7_000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotation"
    )
    Box(
        modifier = Modifier
            .size(OrbCoverSize)
            .clip(CircleShape)
            .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.25f), CircleShape)
            .background(Brush.linearGradient(listOf(CoverPlaceholderA, CoverPlaceholderB)))
            // 暂停时停在原地（不再持续驱动动画，省一点 GPU）
            .graphicsLayer { rotationZ = if (spinning) rotation else 0f },
        contentAlignment = Alignment.Center
    ) {
        if (!coverPath.isNullOrBlank()) {
            AsyncImage(
                model = coverPath,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(OrbCoverSize)
            )
        } else {
            Text(
                text = title.trim().firstOrNull()?.toString() ?: "书",
                style = MaterialTheme.typography.titleMedium,
                color = Color.White,
                textAlign = TextAlign.Center
            )
        }
    }
}

/**
 * 听读设置面板：语速 / 音调 / 音色 / 自动下章 / 系统语音。
 */
@Composable
fun TtsSettingsPanel(
    rate: Float,
    pitch: Float,
    timbre: TtsTimbre,
    autoNext: Boolean,
    voices: List<TtsVoice>,
    voiceName: String,
    bgColor: Color,
    /** 面板内容色：夜间等深色阅读背景下保证文字可读 */
    contentColor: Color = Color.Unspecified,
    onRate: (Float) -> Unit,
    onPitch: (Float) -> Unit,
    onTimbre: (TtsTimbre) -> Unit,
    onAutoNext: (Boolean) -> Unit,
    onVoice: (String) -> Unit,
    onOpenSystemTts: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    val resolved = if (contentColor != Color.Unspecified) {
        contentColor
    } else {
        readerOnColor(bgColor)
    }
    GlassSurface(
        modifier = modifier
            .fillMaxWidth()
            .padding(12.dp),
        shape = androidx.compose.foundation.shape.RoundedCornerShape(24.dp),
        backgroundColor = bgColor,
        contentColor = resolved
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Tune, contentDescription = null)
                Text(
                    "听读设置",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 8.dp)
                )
                IconButton(onClick = onDismiss) {
                    Icon(Icons.Default.Close, contentDescription = "关闭")
                }
            }

            Spacer(Modifier.height(8.dp))
            Text("音色", style = MaterialTheme.typography.labelLarge)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                TtsTimbre.entries.forEach { item ->
                    TimbreChip(
                        label = item.label,
                        selected = item == timbre,
                        onClick = { onTimbre(item) },
                        contentColor = resolved,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
            Text(
                "音色为音调/语速组合，不下载语音包；真正的发声人请在系统「文字转语音」中安装后选择。",
                style = MaterialTheme.typography.labelSmall,
                color = resolved.copy(alpha = 0.6f),
                modifier = Modifier.padding(top = 6.dp)
            )

            Spacer(Modifier.height(12.dp))
            LabeledSlider("语速", rate, 0.5f..2.0f, onRate, resolved) { "${oneDecimal(it)}x" }
            LabeledSlider("音调", pitch, 0.5f..2.0f, onPitch, resolved) { oneDecimal(it) }

            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("读完自动下一章", style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.weight(1f))
                Switch(checked = autoNext, onCheckedChange = onAutoNext)
            }

            Spacer(Modifier.height(12.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("发声人（系统语音）", style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.weight(1f))
                Text(
                    text = "系统设置",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier
                        .clickable(onClick = onOpenSystemTts)
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }
            if (voices.isEmpty()) {
                Text(
                    "未检测到已安装语音（引擎可能仍在初始化），可先使用默认语音。",
                    style = MaterialTheme.typography.labelSmall,
                    color = resolved.copy(alpha = 0.6f),
                    modifier = Modifier.padding(top = 4.dp)
                )
            } else {
                // 语音可能很多，限制高度避免面板过长
                androidx.compose.foundation.lazy.LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp)
                        .padding(top = 6.dp)
                ) {
                    item {
                        VoiceRow(
                            "系统默认", 
                            voiceName.isBlank(),
                            onClick={ onVoice("") }
                        ) 
                    }
                    items(voices.size) { i ->
                        val v = voices[i]
                        VoiceRow(
                            v.displayName, 
                            v.name == voiceName,
                            onClick={ onVoice(v.name) }
                        )
                    }
                }
            }
        }
    }
}

private fun oneDecimal(value: Float): String = "${(value * 10).toInt() / 10f}"

/** 音色选择 chip */
@Composable
private fun TimbreChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    contentColor: Color = Color.Unspecified,
    modifier: Modifier = Modifier
) {
    val base = if (contentColor != Color.Unspecified) contentColor else MaterialTheme.colorScheme.onSurface
    Box(
        modifier = modifier
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
            .background(
                if (selected) MaterialTheme.colorScheme.primary.copy(alpha = 0.16f)
                else base.copy(alpha = 0.06f)
            )
            .border(
                width = 1.dp,
                color = if (selected) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
                shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp)
            )
            .clickable(onClick = onClick)
            .padding(vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = if (selected) MaterialTheme.colorScheme.primary
            else base.copy(alpha = 0.75f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun LabeledSlider(
    label: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    onChange: (Float) -> Unit,
    contentColor: Color = Color.Unspecified,
    format: (Float) -> String
) {
    val base = if (contentColor != Color.Unspecified) contentColor else MaterialTheme.colorScheme.onSurface
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.labelLarge)
        Spacer(Modifier.width(12.dp))
        AppSlider(
            value = value,
            onValueChange = onChange,
            valueRange = range,
            modifier = Modifier.weight(1f),
            rounded = true
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text = format(value),
            style = MaterialTheme.typography.labelSmall,
            color = base.copy(alpha = 0.7f),
            modifier = Modifier.width(40.dp)
        )
    }
}