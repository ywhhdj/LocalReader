package com.demo.feature.shelf

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.dp

import com.demo.core.model.Book
import com.demo.core.model.BookGroup
import com.demo.core.model.BuiltInGroup
import com.demo.core.model.ThemeMode

import com.demo.core.ui.components.BookCoverCard
import com.demo.core.ui.components.CoverSkeleton
import com.demo.core.ui.components.SectionHeader
import com.demo.core.ui.glass.GlassIconButton
import com.demo.core.ui.theme.PrimaryLight

/** 顶部 Logo 位（预留：替换 drawable 即可） */
@Composable
fun BrandLogo(modifier: Modifier = Modifier) {
    Row(modifier = modifier, verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp))
                .background(Brush.linearGradient(listOf(PrimaryLight, MaterialTheme.colorScheme.secondary)))
        )
        androidx.compose.foundation.layout.Spacer(Modifier.width(8.dp))
        Column {
            Text("Liquid", style = MaterialTheme.typography.labelLarge)
            Text("Reader", style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
        }
    }
}

/**
 * 分组筛选 chips（末尾固定"新建"与"筛选"）：
 * 筛选入口独立于分组滚动区之外，点击弹出类型/排序面板。
 */
@Composable
fun GroupChips(
    groups: List<BookGroup>,
    selectedId: Long,
    onSelect: (Long) -> Unit,
    onCreate: () -> Unit,
    onFilter: () -> Unit,
    filterActive: Boolean = false,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(groups, key = { it.id }) { group ->
            FilterChip(
                selected = group.id == selectedId,
                onClick = { onSelect(group.id) },
                label = { Text(group.name) },
                shape = CircleShape,
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                    selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            )
        }
        item {
            FilterChip(
                selected = false,
                onClick = onCreate,
                label = { Text("新建") },
                shape = CircleShape,
                leadingIcon = {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                }
            )
        }
    }
}

/** 分组行右侧的筛选入口 */
@Composable
fun FilterIconButton(
    active: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    GlassIconButton(onClick = onClick, modifier = modifier.size(36.dp)) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = if (active) Icons.Default.Tune else Icons.Default.FilterList,
                contentDescription = "筛选",
                tint = if (active) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

/** 横向书籍区块（继续阅读 / 最近添加） */
@Composable
fun BookRow(
    title: String,
    books: List<Book>,
    onBookClick: (Book) -> Unit,
    onBookLongClick: ((Book) -> Unit)? = null,
    actionText: String? = null,
    onAction: (() -> Unit)? = null
) {
    if (books.isEmpty()) return
    Column(modifier = Modifier.fillMaxWidth()) {
        SectionHeader(title = title, actionText = actionText, onAction = onAction)
        LazyRow(
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(books, key = { it.id }) { book ->
                BookCoverCard(
                    book = book,
                    modifier = Modifier.width(112.dp),
                    onClick = { onBookClick(book) },
                    onLongClick = onBookLongClick?.let { { it(book) } }
                )
            }
        }
    }
}

/** 加载中的骨架行 */
@Composable
fun SkeletonRow(count: Int = 4) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(count) { CoverSkeleton(modifier = Modifier.width(112.dp)) }
    }
}

/** 顶部操作区：主题切换 + 设置 */
@Composable
fun TopBarActions(
    themeMode: ThemeMode,
    onToggleTheme: () -> Unit,
    onSettings: () -> Unit
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        GlassIconButton(onClick = onToggleTheme, modifier = Modifier.size(36.dp)) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = when (themeMode) {
                        ThemeMode.DARK -> Icons.Default.DarkMode
                        ThemeMode.LIGHT -> Icons.Default.LightMode
                        ThemeMode.SYSTEM -> Icons.Default.DarkMode
                    },
                    contentDescription = "切换主题",
                    modifier = Modifier.size(18.dp)
                )
            }
        }
        androidx.compose.foundation.layout.Spacer(Modifier.width(8.dp))
        GlassIconButton(onClick = onSettings, modifier = Modifier.size(36.dp)) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = Icons.Default.Settings,
                    contentDescription = "设置",
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

/** 空书架引导 */
@Composable
fun ShelfEmptyGuide(onImport: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.MenuBook,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(56.dp)
        )
        androidx.compose.foundation.layout.Spacer(Modifier.height(12.dp))
        Text("书架还是空的", style = MaterialTheme.typography.titleMedium)
        androidx.compose.foundation.layout.Spacer(Modifier.height(6.dp))
        Text(
            "导入本地 EPUB / TXT / CBZ / PDF / 图片文件夹即可开始阅读",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        androidx.compose.foundation.layout.Spacer(Modifier.height(20.dp))
        androidx.compose.material3.Button(onClick = onImport) { Text("导入书籍") }
    }
}
