@file:OptIn(ExperimentalFoundationApi::class)

package com.demo.core.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.Collections
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.aspectRatio

import coil.compose.AsyncImage
import coil.request.ImageRequest

import com.demo.core.model.Book
import com.demo.core.model.BookType
import com.demo.core.ui.theme.CoverPlaceholderA
import com.demo.core.ui.theme.CoverPlaceholderB
import com.demo.core.ui.theme.CoverShape

/**
 * 统一封面卡片：小说 / 漫画共用。
 * - 固定采样尺寸，控制内存
 * - 底部进度条（>0 显示）
 * - 右上角类型角标
 * - 无封面时用书名首字母生成渐变占位
 */
@Composable
fun BookCoverCard(
    book: Book,
    modifier: Modifier = Modifier,
    selected: Boolean = false,
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null
) {
    val context = LocalContext.current
    Column(modifier = modifier.widthAdaptive()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(0.7f)
                .clip(CoverShape)
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .then(if (selected) Modifier.border(2.dp, MaterialTheme.colorScheme.primary, CoverShape) else Modifier)
                .bookClickable(onClick = onClick, onLongClick = onLongClick)
        ) {
            if (!book.coverPath.isNullOrBlank()) {
                AsyncImage(
                    model = ImageRequest.Builder(context)
                        .data(book.coverPath)
                        .size(150, 220)          // 按视图尺寸采样，降低内存
                        .crossfade(true)
                        .build(),
                    contentDescription = book.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                PlaceholderCover(book.title)
            }
            TypeBadge(book.type, Modifier.align(Alignment.TopEnd))
            if (book.progress > 0f) {
                LinearProgressIndicator(
                    progress = { book.progress.coerceIn(0f, 1f) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.BottomCenter)
                        .padding(horizontal = 8.dp, vertical = 6.dp)
                        .height(3.dp)
                        .clip(RoundedCornerShape(50))
                )
            }
        }
        Text(
            text = book.title,
            style = MaterialTheme.typography.labelLarge,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 6.dp, start = 2.dp, end = 2.dp)
        )
        Text(
            text = book.author.ifBlank { book.displayMeta() },
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(start = 2.dp, end = 2.dp, bottom = 2.dp)
        )
    }
}

@Composable
private fun PlaceholderCover(title: String) {
    val initial = title.trim().firstOrNull()?.toString() ?: "书"
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.linearGradient(listOf(CoverPlaceholderA, CoverPlaceholderB))),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = initial,
            style = MaterialTheme.typography.headlineMedium,
            color = Color.White
        )
    }
}

@Composable
private fun BoxScope.TypeBadge(type: BookType, modifier: Modifier = Modifier) {
    val (icon, tint) = if (type == BookType.NOVEL) {
        Icons.Default.AutoStories to Color.White
    } else {
        Icons.Default.Collections to Color.White
    }
    Box(
        modifier = modifier
            .padding(6.dp)
            .size(22.dp)
            .clip(RoundedCornerShape(11.dp))
            .background(Color.Black.copy(alpha = 0.35f)),
        contentAlignment = Alignment.Center
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = tint, modifier = Modifier.size(14.dp))
    }
}

private fun Modifier.widthAdaptive(): Modifier = this.fillMaxWidth()

private fun Modifier.bookClickable(
    onClick: () -> Unit,
    onLongClick: (() -> Unit)?
): Modifier = if (onLongClick != null) {
    combinedClickable(onClick = onClick, onLongClick = onLongClick)
} else {
    clickable(onClick = onClick)
}
