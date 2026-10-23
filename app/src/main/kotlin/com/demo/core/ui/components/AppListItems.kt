// core/ui/components/AppListItems.kt
package com.demo.core.ui.components

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

import coil.compose.AsyncImage
import coil.request.ImageRequest

import com.demo.core.model.Book
import com.demo.core.ui.theme.CoverPlaceholderA
import com.demo.core.ui.theme.CoverPlaceholderB

/**
 * 通用行项目：图标 + 标题 + 副标题 + 尾部自定义。覆盖导入对话框、设置卡内多行的相似结构。
 */
@Composable
fun AppListItem(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    icon: ImageVector? = null,
    iconTint: Color = LocalContentColor.current,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    onClick: (() -> Unit)? = null,
    titleStyle: TextStyle = MaterialTheme.typography.bodyMedium,
    subtitleStyle: TextStyle = MaterialTheme.typography.labelSmall,
    titleMaxLines: Int = 1,
    subtitleMaxLines: Int = 1,
    verticalPadding: Dp = 8.dp,
    horizontalPadding: Dp = 4.dp
) {
    val base = modifier
        .fillMaxWidth()
        .then(
            if (onClick != null) {
                Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .clickable(onClick = onClick)
            } else Modifier
        )
        .padding(vertical = verticalPadding, horizontal = horizontalPadding)
    Row(base, verticalAlignment = Alignment.CenterVertically) {
        when {
            leading != null -> leading()
            icon != null -> Icon(icon, contentDescription = null, tint = iconTint)
            else -> {}
        }
        if (leading != null || icon != null) Spacer(Modifier.width(8.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = titleStyle, maxLines = titleMaxLines, overflow = TextOverflow.Ellipsis)
            if (subtitle != null) {
                Text(
                    subtitle,
                    style = subtitleStyle,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    maxLines = subtitleMaxLines,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        trailing?.invoke()
    }
}

/**
 * 详细列表模式的书籍横向行卡片（原 ShelfScreen.BookListCard 抽到 core）。
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AppBookListCard(
    book: Book,
    selected: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    // 请求对象缓存：避免每次重组都让 Coil 重新走一遍加载流程
    val coverRequest = remember(book.coverPath, context) {
        if (book.coverPath.isNullOrBlank()) {
            null
        } else {
            ImageRequest.Builder(context)
                .data(book.coverPath)
                .size(112, 152)
                .crossfade(false)
                .build()
        }
    }
    val shape = RoundedCornerShape(12.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f))
            .then(
                if (selected) Modifier.border(2.dp, MaterialTheme.colorScheme.primary, shape)
                else Modifier
            )
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(width = 56.dp, height = 76.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(Brush.linearGradient(listOf(CoverPlaceholderA, CoverPlaceholderB))),
            contentAlignment = Alignment.Center
        ) {
            if (coverRequest != null) {
                AsyncImage(
                    model = coverRequest,
                    contentDescription = book.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                Text(
                    book.title.trim().firstOrNull()?.toString() ?: "书",
                    style = MaterialTheme.typography.titleMedium,
                    color = Color.White
                )
            }
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                book.title,
                style = MaterialTheme.typography.titleSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(Modifier.height(4.dp))
            Text(
                book.author.ifBlank { book.displayMeta() },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (book.progress > 0f) {
                Spacer(Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { book.progress.coerceIn(0f, 1f) },
                    modifier = Modifier.fillMaxWidth().height(2.dp).clip(RoundedCornerShape(50))
                )
            }
        }
    }
}

/** 居中加载占位（供列表空载 / 初次加载使用） */
@Composable
fun AppLoading(
    modifier: Modifier = Modifier,
    message: String? = null,
    size: Dp = 32.dp
) {
    Box(
        modifier.fillMaxWidth().padding(32.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(modifier = Modifier.size(size))
            if (message != null) {
                Spacer(Modifier.height(8.dp))
                Text(
                    message,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
            }
        }
    }
}