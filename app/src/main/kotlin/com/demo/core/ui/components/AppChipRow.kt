// core/ui/components/AppChipRow.kt
package com.demo.core.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * 通用 FilterChip 行。
 *
 * 用于：收藏页类型筛选、在线书源切换、漫画章节切换、分组标签、FilterSheet 内类型筛选。
 *
 * @param options 选项列表；T 可为 nullable（如 `List<BookType?>` 表示"全部 + 两类"）
 * @param selected 当前选中项
 * @param sectionLabel 若不为空，在 chips 上方渲染小标题
 * @param equalWeight true 时每项均分宽度（外层是 Row）；false 时自适应宽度
 * @param lazy true 时使用 LazyRow（大量选项 / 需要横向滚动）
 * @param trailing 附在末尾的 chip（如"新建"按钮）——仅非 lazy 时使用
 */
@Composable
fun <T> AppChipRow(
    options: List<T>,
    selected: T,
    label: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    sectionLabel: String? = null,
    equalWeight: Boolean = false,
    lazy: Boolean = false,
    shape: Shape = CircleShape,
    rowHeight: Dp = 48.dp,
    horizontalArrangement: Arrangement.Horizontal = Arrangement.spacedBy(8.dp),
    contentPadding: PaddingValues = PaddingValues(horizontal = 0.dp),
    trailing: (@Composable () -> Unit)? = null
) {
    Column(modifier.fillMaxWidth()) {
        if (sectionLabel != null) {
            Text(sectionLabel, style = MaterialTheme.typography.labelLarge)
            Spacer(Modifier.height(6.dp))
        }
        if (lazy) {
            LazyRow(
                modifier = Modifier.fillMaxWidth().height(rowHeight),
                contentPadding = contentPadding,
                horizontalArrangement = horizontalArrangement,
                verticalAlignment = Alignment.CenterVertically
            ) {
                items(options.size) { i ->
                    val option = options[i]
                    FilterChip(
                        selected = option == selected,
                        onClick = { onSelect(option) },
                        label = { Text(label(option)) },
                        shape = shape
                    )
                }
                if (trailing != null) item { trailing() }
            }
        } else {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = horizontalArrangement,
                verticalAlignment = Alignment.CenterVertically
            ) {
                options.forEach { option ->
                    FilterChip(
                        selected = option == selected,
                        onClick = { onSelect(option) },
                        label = { Text(label(option)) },
                        shape = shape,
                        modifier = if (equalWeight) Modifier.weight(1f) else Modifier
                    )
                }
                trailing?.invoke()
            }
        }
    }
}