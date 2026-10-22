package com.demo.core.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

import com.demo.core.common.util.VolumeSplitter
import com.demo.core.model.ComicChapter

/**
 * 漫画话集列表（阅读器目录抽屉 / 详情页话集共用）。
 *
 * 与小说目录保持一致的交互：整话一行，点击即跳到该话首页；
 * 当前话高亮并显示话内页数，便于在长篇里定位。
 */
@Composable
fun ComicTocList(
    chapters: List<ComicChapter>,
    currentIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
    textColor: Color = Color.Unspecified,
    highlightColor: Color = MaterialTheme.colorScheme.primary,
    header: (@Composable () -> Unit)? = null
) {
    // 未指定颜色时回落到 onSurface：Color.Unspecified 做 copy(alpha) 会得到不可预期的透明色
    val bodyColor = if (textColor == Color.Unspecified) MaterialTheme.colorScheme.onSurface else textColor

    Column(modifier.fillMaxSize()) {
        header?.invoke()
        if (chapters.isEmpty()) {
            Text(
                text = "暂无话集",
                style = MaterialTheme.typography.bodyMedium,
                color = bodyColor,
                modifier = Modifier.padding(16.dp)
            )
        }
        LazyColumn(modifier = Modifier.weight(1f)) {
            itemsIndexed(chapters, key = { _, chapter -> chapter.index }) { _, chapter ->
                val selected = chapter.index == currentIndex
                val pageCount = chapter.pageCount.coerceAtLeast(chapter.endIndex - chapter.startIndex + 1)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            if (selected) highlightColor.copy(alpha = 0.10f) else Color.Transparent
                        )
                        .clickable { onSelect(chapter.index) }
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = chapter.title,
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (selected) highlightColor else bodyColor,
                        maxLines = 2,
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = "${pageCountSafe(pageCount)}页",
                        style = MaterialTheme.typography.labelSmall,
                        color = if (selected) highlightColor else bodyColor.copy(alpha = 0.6f)
                    )
                }
            }
        }
    }
}

private fun pageCountSafe(count: Int): Int = count.coerceAtLeast(1)

/**
 * 分卷目录列表（小说阅读器目录抽屉 / 书籍详情页目录抽屉共用）。
 *
 * - 有分卷时：卷名单独一行（加粗），卷内章节缩进显示且已去掉卷名前缀；
 * - 无分卷时：退化为平铺章节列表；
 * - [currentIndex] 命中的章节高亮，便于定位当前阅读位置。
 */
@Composable
fun VolumeTocList(
    entries: List<VolumeSplitter.TocEntry>,
    currentIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
    textColor: Color = Color.Unspecified,
    highlightColor: Color = MaterialTheme.colorScheme.primary,
    header: (@Composable () -> Unit)? = null
) {
    if (entries.isEmpty()) {
        Column(modifier = modifier.fillMaxSize()) {
            header?.invoke()
            Text(
                text = "暂无目录",
                style = MaterialTheme.typography.bodyMedium,
                color = textColor,
                modifier = Modifier.padding(16.dp)
            )
        }
        return
    }
    Column(modifier.fillMaxSize()) {
        header?.invoke()
        LazyColumn(modifier = Modifier.weight(1f)) {
            itemsIndexed(entries, key = { index, _ -> index }) { _, entry ->
                when (entry) {
                    is VolumeSplitter.TocEntry.Volume -> Text(
                        text = entry.title,
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                        color = textColor,
                        maxLines = 2,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 10.dp)
                    )
                    is VolumeSplitter.TocEntry.Item -> {
                        val selected = entry.chapter.index == currentIndex
                        Text(
                            text = VolumeSplitter.displayTitle(entry.chapter),
                            style = MaterialTheme.typography.bodyMedium,
                            color = if (selected) highlightColor else textColor,
                            maxLines = 2,
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    if (selected) highlightColor.copy(alpha = 0.10f)
                                    else Color.Transparent
                                )
                                .clickable { onSelect(entry.chapter.index) }
                                .padding(horizontal = 16.dp, vertical = 10.dp)
                                .padding(start = 16.dp)
                        )
                    }
                }
            }
        }
    }
}
