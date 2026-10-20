package com.demo.feature.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import com.demo.core.common.util.FormatUtil
import com.demo.core.model.ThemeMode
import com.demo.core.ui.components.AppBackdrop
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.glass.GlassTopBar
import com.demo.core.ui.theme.CardShape

@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var nickname by remember(state.settings.nickname) { mutableStateOf(state.settings.nickname) }

    LaunchedEffect(state.message) {
        if (state.message != null) viewModel.consumeMessage()
    }

    AppBackdrop {
        Column(modifier = modifier.fillMaxSize()) {
            GlassTopBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
                title = { Text("设置", style = MaterialTheme.typography.titleMedium) }
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                item {
                    SettingsCard("外观") {
                        Text("主题", style = MaterialTheme.typography.bodyMedium)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            ThemeMode.entries.forEach { mode ->
                                FilterChip(
                                    selected = state.settings.themeMode == mode,
                                    onClick = { viewModel.setTheme(mode) },
                                    label = { Text(labelOf(mode)) }
                                )
                            }
                        }
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("动态取色 (Android 12+)", style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f))
                            Switch(
                                checked = state.settings.dynamicColor,
                                onCheckedChange = viewModel::setDynamicColor
                            )
                        }
                        Text(
                            "液态玻璃强度",
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.padding(top = 12.dp)
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            listOf("OFF" to "关闭", "LOW" to "弱", "MEDIUM" to "中", "HIGH" to "强").forEach { (value, label) ->
                                FilterChip(
                                    selected = state.settings.glassLevel == value,
                                    onClick = { viewModel.setGlassLevel(value) },
                                    label = { Text(label) }
                                )
                            }
                        }
                    }
                }

                item {
                    SettingsCard("个人") {
                        OutlinedTextField(
                            value = nickname,
                            onValueChange = { nickname = it },
                            label = { Text("昵称") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                        androidx.compose.foundation.layout.Spacer(Modifier.padding(4.dp))
                        androidx.compose.material3.Button(onClick = { viewModel.setNickname(nickname) }) {
                            Text("保存昵称")
                        }
                    }
                }

                item {
                    SettingsCard("漫画") {
                        Text("预加载页数：${state.settings.comicPreload}", style = MaterialTheme.typography.bodyMedium)
                        Slider(
                            value = state.settings.comicPreload.toFloat(),
                            onValueChange = { viewModel.setComicPreload(it.toInt()) },
                            valueRange = 1f..3f,
                            steps = 1,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }

                item {
                    SettingsCard("扫描") {
                        Text("扫描深度：${state.settings.scanMaxDepth}", style = MaterialTheme.typography.bodyMedium)
                        Slider(
                            value = state.settings.scanMaxDepth.toFloat(),
                            onValueChange = { viewModel.setScanDepth(it.toInt()) },
                            valueRange = 1f..8f,
                            steps = 6,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("跳过隐藏目录", style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f))
                            Switch(checked = state.settings.skipHidden, onCheckedChange = viewModel::setSkipHidden)
                        }
                    }
                }

                item {
                    SettingsCard("存储") {
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Text("封面缓存 ${FormatUtil.formatBytes(state.coverBytes)}",
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f)
                            )
                            androidx.compose.material3.TextButton(onClick = viewModel::clearCovers) { Text("清理") }
                        }
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Text("页面缓存 ${FormatUtil.formatBytes(state.pageBytes)}",
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f)
                            )
                            androidx.compose.material3.TextButton(onClick = viewModel::clearPages) { Text("清理") }
                        }
                    }
                }

                item {
                    SettingsCard("关于") {
                        Text("Liquid Reader v1.0.0", style = MaterialTheme.typography.bodyMedium)
                        Text(
                            "本地小说 / 漫画阅读器 · 支持 EPUB / TXT / PDF / CBZ / ZIP / 图片文件夹",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                            modifier = Modifier.padding(top = 6.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsCard(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    GlassSurface(shape = CardShape, modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            content = {
                Text(title, style = MaterialTheme.typography.titleMedium)
                androidx.compose.foundation.layout.Spacer(Modifier.padding(6.dp))
                content()
            }
        )
    }
}

private fun labelOf(mode: ThemeMode): String = when (mode) {
    ThemeMode.SYSTEM -> "跟随系统"
    ThemeMode.LIGHT -> "浅色"
    ThemeMode.DARK -> "深色"
}
