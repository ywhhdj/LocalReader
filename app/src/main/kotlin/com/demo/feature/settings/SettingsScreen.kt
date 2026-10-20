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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import com.demo.core.common.util.FormatUtil
import com.demo.core.common.util.StorageAccess
import com.demo.core.model.ThemeMode
import com.demo.domain.codec.BookSourceCodec
import com.demo.core.ui.components.AppBackdrop
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.glass.GlassTopBar
import com.demo.core.ui.theme.CardShape
import com.demo.core.common.util.Constants

@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var nickname by remember(state.settings.nickname) { mutableStateOf(state.settings.nickname) }
    var newDir by remember { mutableStateOf("") }
    var onlineJson by remember(state.settings.onlineSourceJson) {
        mutableStateOf(state.settings.onlineSourceJson)
    }
    val hasAllFiles = remember { StorageAccess.hasAllFilesAccess() }

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
                title = { Text("设置", 
                    style = MaterialTheme.typography.titleMedium
                ) }
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                item {
                    SettingsCard("外观") {
                        Text(
                            "主题",
                            style = MaterialTheme.typography.bodyMedium
                        )
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
                            modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("动态取色 (Android 12+)", 
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f)
                            )
                            Switch(checked = state.settings.dynamicColor, onCheckedChange = viewModel::setDynamicColor)
                        }
                        Text("液态玻璃强度", 
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
                        Button(onClick = { viewModel.setNickname(nickname) }, modifier = Modifier.padding(top = 8.dp)) {
                            Text("保存昵称")
                        }
                    }
                }

                item {
                    SettingsCard("朗读 (TTS)") {
                        Text("语速：${"%.1f".format(state.settings.ttsRate)}x", style = MaterialTheme.typography.bodyMedium)
                        Slider(
                            value = state.settings.ttsRate,
                            onValueChange = viewModel::setTtsRate,
                            valueRange = 0.5f..2.0f,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Text("音调：${"%.1f".format(state.settings.ttsPitch)}", style = MaterialTheme.typography.bodyMedium)
                        Slider(
                            value = state.settings.ttsPitch,
                            onValueChange = viewModel::setTtsPitch,
                            valueRange = 0.5f..2.0f,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Text("读完自动进入下一章", style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f))
                            Switch(checked = state.settings.ttsAutoNext, onCheckedChange = viewModel::setTtsAutoNext)
                        }
                        Text(
                            "朗读使用系统 TTS 引擎，可在小说阅读器顶部「朗读」按钮启动。",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                }

                item {
                    SettingsCard("扫描与目录") {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                if (hasAllFiles) "已获得文件访问权限" else "未获得文件访问权限（Android 11+ 需授权）",
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f)
                            )
                            TextButton(onClick = { StorageAccess.openAllFilesAccessSettings(context) }) {
                                Text("去授权")
                            }
                        }
                        Text("扫描深度：${state.settings.scanMaxDepth}", style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.padding(top = 8.dp))
                        Slider(
                            value = state.settings.scanMaxDepth.toFloat(),
                            onValueChange = { viewModel.setScanDepth(it.toInt()) },
                            valueRange = 1f..8f,
                            steps = 6,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Text("跳过隐藏目录", style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f))
                            Switch(checked = state.settings.skipHidden, onCheckedChange = viewModel::setSkipHidden)
                        }
                        if (state.settings.scanDirs.isNotEmpty()) {
                            Text("已保存目录", style = MaterialTheme.typography.labelLarge,
                                modifier = Modifier.padding(top = 10.dp))
                            state.settings.scanDirs.forEach { dir ->
                                Row(
                                    Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        dir,
                                        style = MaterialTheme.typography.labelSmall,
                                        modifier = Modifier.weight(1f),
                                        maxLines = 2
                                    )
                                    TextButton(onClick = { viewModel.removeScanDir(dir) }) { Text("移除") }
                                }
                            }
                        }
                        OutlinedTextField(
                            value = newDir,
                            onValueChange = { newDir = it },
                            label = { Text("添加目录（绝对路径）") },
                            singleLine = true,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 8.dp)
                        )
                        Button(
                            onClick = {
                                viewModel.addScanDir(newDir.trim())
                                newDir = ""
                            },
                            modifier = Modifier.padding(top = 8.dp)
                        ) { Text("添加") }
                    }
                }

                item {
                    SettingsCard("备份与同步 (WebDAV)") {
                        Text(
                            "备份书库元数据、进度与阅读统计；不含书籍文件。默认关闭。",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                        OutlinedTextField(
                            value = state.settings.webdavUrl,
                            onValueChange = viewModel::setWebdav,
                            label = { Text("WebDAV 地址") },
                            placeholder = { Text("https://dav.example.com/") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                        )
                        OutlinedTextField(
                            value = state.settings.webdavUser,
                            onValueChange = viewModel::setWebdavUser,
                            label = { Text("用户名") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                        )
                        OutlinedTextField(
                            value = state.settings.webdavPassword,
                            onValueChange = viewModel::setWebdavPassword,
                            label = { Text("密码") },
                            singleLine = true,
                            visualTransformation = PasswordVisualTransformation(),
                            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                        )
                        OutlinedTextField(
                            value = state.settings.webdavDir,
                            onValueChange = viewModel::setWebdavDir,
                            label = { Text("远程目录") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
                        )
                        Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text("自动备份（进入阅读器时）",
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f)
                            )
                            Switch(checked = state.settings.webdavAutoBackup, onCheckedChange = viewModel::setWebdavAutoBackup)
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                            Button(onClick = viewModel::testConnection, enabled = !state.syncBusy) { Text("测试连接") }
                            Button(onClick = viewModel::backupNow, enabled = !state.syncBusy) { Text("立即备份") }
                            TextButton(onClick = viewModel::refreshBackups) { Text("刷新列表") }
                        }
                        if (state.settings.lastBackupAt > 0L) {
                            Text(
                                "上次备份：${FormatUtil.formatDateTime(state.settings.lastBackupAt)}",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                modifier = Modifier.padding(top = 6.dp)
                            )
                        }
                        if (state.backups.isNotEmpty()) {
                            Text("远端备份", style = MaterialTheme.typography.labelLarge,
                                modifier = Modifier.padding(top = 10.dp))
                            state.backups.take(5).forEach { item ->
                                Row(
                                    Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(Modifier.weight(1f)) {
                                        Text(item.name, style = MaterialTheme.typography.bodySmall, maxLines = 1)
                                        Text(
                                            "${FormatUtil.formatBytes(item.sizeBytes)} · ${FormatUtil.formatDateTime(item.modifiedAt)}",
                                            style = MaterialTheme.typography.labelSmall,
                                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
                                        )
                                    }
                                    TextButton(onClick = { viewModel.restore(item.path) }) { Text("恢复") }
                                }
                            }
                        }
                        Row(modifier = Modifier.padding(top = 8.dp)) {
                            TextButton(onClick = viewModel::exportSnapshotToFile) { 
                                Text("导出到本地文件")
                            }
                        }
                    }
                }

                item {
                    SettingsCard("在线书源（默认关闭）") {
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Text("启用在线书源", style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f))
                            Switch(checked = state.settings.onlineSourceEnabled,
                                onCheckedChange = viewModel::setOnlineEnabled)
                        }
                        Text(
                            "关闭时不产生任何网络请求。开启后请自行配置书源规则（仅用于搜索并另存为 TXT 到本地书库）。",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                            modifier = Modifier.padding(top = 6.dp)
                        )
                        if (state.settings.onlineSourceEnabled) {
                            OutlinedTextField(
                                value = onlineJson,
                                onValueChange = { onlineJson = it },
                                label = { Text("书源配置 JSON") },
                                minLines = 6,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 8.dp)
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                                Button(onClick = { viewModel.setOnlineSourceJson(onlineJson) }) { Text("保存书源") }
                                TextButton(onClick = { onlineJson = BookSourceCodec.template() }) { Text("填入模板") }
                            }
                        }
                    }
                }

                item {
                    SettingsCard("漫画") {
                        Text("预加载页数：${state.settings.comicPreload}", style = MaterialTheme.typography.bodyMedium)
                        Slider(
                            value = state.settings.comicPreload.toFloat(),
                            onValueChange = { viewModel.setComicPreload(it.toInt()) },
                            valueRange = 3f..5f,
                            steps = 1,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }

                item {
                    SettingsCard("存储") {
                        CacheRow("封面缓存", state.coverBytes) { viewModel.clearCovers() }
                        CacheRow("页面缓存", state.pageBytes) { viewModel.clearPages() }
                        CacheRow("目录缓存(SAF)", state.safBytes) { viewModel.clearSafCache() }
                    }
                }

                item {
                    SettingsCard("关于") {
                        Text("Liquid Reader v${Constants.APP_VERSION}", style = MaterialTheme.typography.bodyMedium)
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
private fun CacheRow(label: String, bytes: Long, onClear: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text("$label ${FormatUtil.formatBytes(bytes)}",
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(1f))
        TextButton(onClick = onClear) { Text("清理") }
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
