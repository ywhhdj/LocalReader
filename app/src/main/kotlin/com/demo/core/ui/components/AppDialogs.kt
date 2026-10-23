package com.demo.core.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog

import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.ReaderShapes

/**
 * 通用玻璃对话框外壳：标题 + 可选副标题 + 内容 + 底部操作按钮行。
 *
 * 统一了 ImportDialog / CreateGroupDialog / 各类确认对话框的布局与视觉，
 * 新对话框直接传 [content] 和 [actions] 即可，避免重复写 Dialog + GlassSurface + Row。
 */
@Composable
fun AppDialog(
    title: String,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    content: @Composable ColumnScope.() -> Unit,
    actions: @Composable RowScope.() -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        GlassSurface(
            shape = ReaderShapes.large,
            modifier = modifier.fillMaxWidth()
        ) {
            Column(Modifier.padding(20.dp)) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                if (subtitle != null) {
                    Text(
                        subtitle,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
                content()
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp),
                    horizontalArrangement = Arrangement.End,
                    content = actions
                )
            }
        }
    }
}