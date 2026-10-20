package com.demo.feature.profile

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DeleteSweep
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.foundation.layout.RowScope

import com.demo.core.common.util.FormatUtil
import com.demo.core.model.DayStat
import com.demo.core.model.ReadingStats
import com.demo.core.ui.components.AppBackdrop
import com.demo.core.ui.components.BookCoverCard
import com.demo.core.ui.components.SectionHeader
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.glass.GlassTopBar
import com.demo.core.ui.theme.PrimaryLight
import com.demo.core.ui.theme.CardShape
import com.demo.core.ui.theme.ReaderShapes

@Composable
fun ProfileScreen(
    viewModel: ProfileViewModel,
    onBookClick: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var showRename by remember { mutableStateOf(false) }
    var showClearConfirm by remember { mutableStateOf(false) }

    LaunchedEffect(state.message) {
        if (state.message != null) viewModel.consumeMessage()
    }

    AppBackdrop {
        Column(modifier = modifier.fillMaxSize()) {
            GlassTopBar(
                title = { Text("我的", style = MaterialTheme.typography.titleMedium) },
                actions = {
                    IconButton(onClick = { showRename = true }) {
                        Icon(Icons.Default.Edit, contentDescription = "修改昵称")
                    }
                }
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                item { ProfileHeader(state.settings.nickname, state.stats) }
                item { TodayCard(state.stats) }
                item { WeekBarCard(state.stats.last7Days) }
                item { TypeRatioCard(state.stats) }
                if (state.recentFinished.isNotEmpty()) {
                    item { SectionHeader(title = "最近读完") }
                    item {
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            items(state.recentFinished, key = { it.id }) { book ->
                                BookCoverCard(
                                    book = book,
                                    modifier = Modifier.width(104.dp),
                                    onClick = { onBookClick(book.id) }
                                )
                            }
                        }
                    }
                }
                item {
                    GlassSurface(shape = CardShape, modifier = Modifier.fillMaxWidth()) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { showClearConfirm = true }
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.DeleteSweep, contentDescription = null)
                            Spacer(Modifier.width(10.dp))
                            Text("清空阅读记录", style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }

    if (showRename) {
        var text by remember { mutableStateOf(state.settings.nickname) }
        AlertDialog(
            onDismissRequest = { showRename = false },
            title = { Text("修改昵称") },
            text = {
                OutlinedTextField(value = text, onValueChange = { text = it }, singleLine = true)
            },
            confirmButton = {
                TextButton(onClick = {
                    showRename = false
                    viewModel.rename(text.trim())
                }) { Text("保存") }
            },
            dismissButton = { TextButton(onClick = { showRename = false }) { Text("取消") } }
        )
    }

    if (showClearConfirm) {
        AlertDialog(
            onDismissRequest = { showClearConfirm = false },
            title = { Text("清空阅读记录？") },
            text = { Text("将删除全部阅读时长统计，书籍与进度不受影响。") },
            confirmButton = {
                TextButton(onClick = {
                    showClearConfirm = false
                    viewModel.clearHistory()
                }) { Text("清空") }
            },
            dismissButton = { TextButton(onClick = { showClearConfirm = false }) { Text("取消") } }
        )
    }
}

@Composable
private fun ProfileHeader(nickname: String, stats: ReadingStats) {
    GlassSurface(shape = ReaderShapes.large, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(18.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(54.dp)
                        .background(
                            Brush.linearGradient(listOf(PrimaryLight, MaterialTheme.colorScheme.secondary)),
                            CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.Person, contentDescription = null, tint = Color.White)
                }
                Spacer(Modifier.width(14.dp))
                Column {
                    Text(nickname, style = MaterialTheme.typography.titleLarge)
                    Text(
                        "已连续阅读 ${stats.streakDays} 天",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f)
                    )
                }
            }
            Spacer(Modifier.height(18.dp))
            Row(Modifier.fillMaxWidth()) {
                StatBlock("总时长", FormatUtil.formatDuration(stats.totalMillis))
                StatBlock("藏书", "${stats.totalBooks} 本")
                StatBlock("读完", "${stats.finishedCount} 本")
            }
        }
    }
}

@Composable
private fun RowScope.StatBlock(label: String, value: String) {
    Column(
        modifier = Modifier.weight(1f),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(value, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
        Spacer(Modifier.height(4.dp))
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
    }
}

@Composable
private fun TodayCard(stats: ReadingStats) {
    GlassSurface(
        shape = CardShape, 
        modifier = Modifier.fillMaxWidth(),
        alignment = Alignment.CenterStart
    ) {
        Column(Modifier.padding(16.dp)) {
            Text("今日阅读", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(8.dp))
            Text(
                FormatUtil.formatDuration(stats.todayMillis),
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.primary
            )
            Spacer(Modifier.height(6.dp))
            Text(
                "本周 ${FormatUtil.formatDuration(stats.weekMillis)} · 在读 ${stats.readingCount} 本",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
            )
        }
    }
}

/** 近 7 天柱状图（Canvas 自绘，无第三方图表库） */
@Composable
private fun WeekBarCard(days: List<DayStat>) {
    if (days.isEmpty()) return
    val primary = MaterialTheme.colorScheme.primary
    val track = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.10f)
    GlassSurface(shape = CardShape, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text("近 7 天", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(12.dp))
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(110.dp)
            ) {
                val max = days.maxOf { it.millis }.coerceAtLeast(60_000L).toFloat()
                val slot = size.width / days.size
                val barWidth = slot * 0.42f
                days.forEachIndexed { index, day ->
                    val ratio = (day.millis / max).coerceIn(0f, 1f)
                    val barHeight = (size.height - 24f) * ratio
                    val left = index * slot + (slot - barWidth) / 2
                    val top = size.height - 20f - barHeight
                    drawRoundRect(
                        color = track,
                        topLeft = Offset(left, 0f),
                        size = Size(barWidth, size.height - 20f),
                        cornerRadius = CornerRadius(barWidth / 2, barWidth / 2)
                    )
                    if (barHeight > 0f) {
                        drawRoundRect(
                            brush = Brush.verticalGradient(
                                listOf(primary, primary.copy(alpha = 0.55f)),
                                startY = top,
                                endY = size.height
                            ),
                            topLeft = Offset(left, top),
                            size = Size(barWidth, barHeight),
                            cornerRadius = CornerRadius(barWidth / 2, barWidth / 2)
                        )
                    }
                }
            }
            Row(Modifier.fillMaxWidth()) {
                days.forEach { day ->
                    Text(
                        text = day.label,
                        style = MaterialTheme.typography.labelSmall,
                        textAlign = TextAlign.Center,
                        color = if (day.isToday) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

/** 分类占比环形图 */
@Composable
private fun TypeRatioCard(stats: ReadingStats) {
    val total = (stats.novelMillis + stats.comicMillis).coerceAtLeast(1L)
    val novelRatio = stats.novelMillis.toFloat() / total
    val primary = MaterialTheme.colorScheme.primary
    val secondary = MaterialTheme.colorScheme.secondary
    val track = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.10f)
    GlassSurface(shape = CardShape, modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Canvas(modifier = Modifier.size(96.dp)) {
                val stroke = Stroke(width = 14f)
                drawArc(
                    color = track,
                    startAngle = -90f,
                    sweepAngle = 360f,
                    useCenter = false,
                    style = stroke
                )
                drawArc(
                    brush = Brush.linearGradient(listOf(primary, primary.copy(alpha = 0.6f))),
                    startAngle = -90f,
                    sweepAngle = 360f * novelRatio,
                    useCenter = false,
                    style = stroke
                )
                if (novelRatio < 1f) {
                    drawArc(
                        brush = Brush.linearGradient(listOf(secondary, secondary.copy(alpha = 0.6f))),
                        startAngle = -90f + 360f * novelRatio,
                        sweepAngle = 360f * (1f - novelRatio),
                        useCenter = false,
                        style = stroke
                    )
                }
            }
            Spacer(Modifier.width(18.dp))
            Column {
                Text(
                    "阅读时长占比",
                    style = MaterialTheme.typography.titleMedium
                )
                Spacer(Modifier.height(8.dp))
                RatioRow("小说", stats.novelMillis, total, primary)
                Spacer(Modifier.height(6.dp))
                RatioRow("漫画", stats.comicMillis, total, secondary)
                Spacer(Modifier.height(8.dp))
                Text(
                    "小说 ${stats.novelCount} 本 · 漫画 ${stats.comicCount} 本",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
            }
        }
    }
}

@Composable
private fun RatioRow(label: String, millis: Long, total: Long, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .background(color, CircleShape)
        )
        Spacer(Modifier.width(8.dp))
        Text(label, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.width(40.dp))
        Text(
            "${(millis * 100 / total).toInt()}%",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f)
        )
        Spacer(Modifier.width(8.dp))
        Text(
            FormatUtil.formatDuration(millis),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
    }
}
