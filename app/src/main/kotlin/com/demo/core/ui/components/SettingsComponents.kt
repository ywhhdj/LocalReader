package com.demo.core.ui.components.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

import com.demo.core.ui.components.AppListItem
import com.demo.core.ui.components.AppSlider
import com.demo.core.ui.glass.GlassSurface

/** 设置卡片：玻璃 + 圆角 24dp + 图标标题 + 内容区（垂直 8dp 间距） */
@Composable
fun SettingsSection(
    title: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    trailing: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    GlassSurface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (icon != null) {
                    Icon(icon, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                }
                Text(
                    title,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f)
                )
                trailing?.invoke()
            }
            Spacer(Modifier.height(12.dp))
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                content = content
            )
        }
    }
}

/** 说明文字：统一 60% 不透明度的 labelSmall，用在卡片里的补充说明 */
@Composable
fun SettingHint(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        modifier = modifier
    )
}

/** 带标签与数值的 Slider 行 */
@Composable
fun SettingSliderRow(
    label: String,
    value: Float,
    valueRange: ClosedFloatingPointRange<Float>,
    onValueChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
    steps: Int = 0,
    valueText: (Float) -> String = { it.toString() }
) {
    Column(modifier.fillMaxWidth()) {
        Text(
            text = "$label：${valueText(value)}",
            style = MaterialTheme.typography.labelLarge
        )
        AppSlider(
            value = value,
            onValueChange = onValueChange,
            valueRange = valueRange,
            steps = steps,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

/** 开关行：[title] + 可选 [hint]，右侧 Switch */
@Composable
fun SettingSwitchRow(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    hint: String? = null
) {
    Row(
        modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.labelLarge)
            if (hint != null) {
                Text(
                    hint,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier.padding(top = 2.dp)
                )
            }
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

/** 一组 FilterChip（等宽或自适应） */
@Composable
fun <T> SettingChipGroup(
    options: List<T>,
    selected: T,
    label: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    sectionLabel: String? = null,
    equalWeight: Boolean = true
) {
    Column(modifier.fillMaxWidth()) {
        if (sectionLabel != null) {
            Text(sectionLabel, style = MaterialTheme.typography.labelLarge)
            Spacer(Modifier.height(6.dp))
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            options.forEach { option ->
                FilterChip(
                    selected = option == selected,
                    onClick = { onSelect(option) },
                    label = {
                        Text(
                            label(option),
                            style = MaterialTheme.typography.labelLarge
                        )
                    },
                    modifier = if (equalWeight) Modifier.wrapContentWidth().weight(1f)
                    else Modifier.wrapContentWidth()
                )
            }
        }
    }
}

/** 文本输入行：统一单行 / 密码 / 占位提示，宽度撑满父容器 */
@Composable
fun SettingTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    singleLine: Boolean = true,
    isPassword: Boolean = false,
    placeholder: String? = null,
    minLines: Int = 1
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        placeholder = placeholder?.let { { Text(it) } },
        singleLine = singleLine,
        minLines = minLines,
        visualTransformation = if (isPassword) PasswordVisualTransformation()
        else VisualTransformation.None,
        modifier = modifier.fillMaxWidth()
    )
}

/** 一行「标题 / 副标题 + 右侧操作按钮」 */
@Composable
fun SettingActionRow(
    title: String,
    actionText: String,
    onAction: () -> Unit,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    titleStyle: TextStyle = MaterialTheme.typography.bodyMedium,
    titleMaxLines: Int = 1
) {
    Row(
        modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, style = titleStyle, maxLines = titleMaxLines)
            if (subtitle != null) {
                Text(
                    subtitle,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
                )
            }
        }
        TextButton(onClick = onAction) { Text(actionText) }
    }
}

/** 语音选项行：显示 + 当前选中勾选，点击即切换 */
@Composable
fun VoiceRow(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    AppListItem(
        title = label,
        modifier = modifier,
        onClick = onClick,
        titleStyle = MaterialTheme.typography.bodyMedium,
        trailing = if (selected) {
            {
                Icon(
                    Icons.Default.Check,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary
                )
            }
        } else null
    )
}

/** 横向懒加载的 FilterChip 组：适合音色等"选项可能很多"的场景 */
@Composable
fun <T> SettingChipLazyRow(
    options: List<T>,
    selected: T,
    label: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    sectionLabel: String? = null,
    rowHeight: Dp = 56.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 0.dp),
    horizontalArrangement: Arrangement.Horizontal = Arrangement.spacedBy(6.dp)
) {
    Column(modifier.fillMaxWidth()) {
        if (sectionLabel != null) {
            Text(sectionLabel, style = MaterialTheme.typography.labelLarge)
            Spacer(Modifier.height(6.dp))
        }
        LazyRow(
            modifier = Modifier
                .fillMaxWidth()
                .height(rowHeight),
            contentPadding = contentPadding,
            horizontalArrangement = horizontalArrangement,
            verticalAlignment = Alignment.CenterVertically
        ) {
            items(options.size) { i ->
                val option = options[i]
                FilterChip(
                    selected = option == selected,
                    onClick = { onSelect(option) },
                    label = { Text(label(option)) }
                )
            }
        }
    }
}