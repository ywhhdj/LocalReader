package com.demo.feature.settings

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.RecordVoiceOver
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.Button
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.material.icons.filled.Settings

import kotlinx.coroutines.launch

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FormatUtil
import com.demo.core.common.util.StorageAccess
import com.demo.core.common.util.DeviceTierDetector
import com.demo.core.model.FrameRateMode
import com.demo.core.model.ThemeMode
import com.demo.core.model.TtsTimbre
import com.demo.core.ui.components.AppBackdrop
import com.demo.core.ui.components.settings.SettingActionRow
import com.demo.core.ui.components.settings.SettingChipGroup
import com.demo.core.ui.components.settings.SettingChipLazyRow
import com.demo.core.ui.components.settings.SettingHint
import com.demo.core.ui.components.settings.SettingSliderRow
import com.demo.core.ui.components.settings.SettingSwitchRow
import com.demo.core.ui.components.settings.SettingsSection
import com.demo.core.ui.components.settings.SettingTextField
import com.demo.core.ui.components.settings.VoiceRow
import com.demo.core.ui.glass.GlassTopBar
import com.demo.domain.codec.BookSourceCodec

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
    val deviceTier = remember(context) { DeviceTierDetector.detect(context) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) { viewModel.refreshTtsVoices() }
    LaunchedEffect(state.message) { if (state.message != null) viewModel.consumeMessage() }

    AppBackdrop {
        Column(modifier = modifier.fillMaxSize()) {
            GlassTopBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
                title = {
                    Text("设置", style = MaterialTheme.typography.titleMedium)
                }
            )
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // ---------- 外观 ----------
                item {
                    SettingsSection("外观", icon = Icons.Default.Palette) {
                        SettingChipGroup(
                            sectionLabel = "主题",
                            options = ThemeMode.entries,
                            selected = state.settings.themeMode,
                            label = ::labelOf,
                            onSelect = viewModel::setTheme
                        )
                        SettingSwitchRow(
                            title = "动态取色 (Android 12+)",
                            checked = state.settings.dynamicColor,
                            onCheckedChange = viewModel::setDynamicColor
                        )
                        SettingChipGroup(
                            sectionLabel = "液态玻璃强度",
                            options = listOf("OFF", "LOW", "MEDIUM", "HIGH"),
                            selected = state.settings.glassLevel,
                            label = ::glassLabelOf,
                            onSelect = viewModel::setGlassLevel
                        )
                    }
                }

                // ---------- 动效与流畅度 ----------
                item {
                    SettingsSection("动效与流畅度", icon = Icons.Default.Settings) {
                        SettingSwitchRow(
                            title = "界面动效",
                            hint = "关闭后：背景光斑静止、翻页直接切换、面板瞬时显示",
                            checked = state.settings.animationsEnabled,
                            onCheckedChange = viewModel::setAnimationsEnabled
                        )
                        SettingChipGroup(
                            sectionLabel = "动画帧率上限",
                            options = FrameRateMode.entries,
                            selected = state.settings.frameRateMode,
                            label = { it.label },
                            onSelect = viewModel::setFrameRateMode
                        )
                        SettingHint(
                            "当前设备分级：$deviceTier。帧率上限约束的是背景光斑、翻页等持续动画的" +
                                "刷新频率（Android 不允许 App 直接改写屏幕刷新率）；" +
                                "「自动」按设备内存与核心数取 30 / 60fps。"
                        )
                    }
                }

                // ---------- 个人 ----------
                item {
                    SettingsSection("个人", icon = Icons.Default.Person) {
                        OutlinedTextField(
                            value = nickname,
                            onValueChange = { nickname = it },
                            label = { Text("昵称") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Button(onClick = { viewModel.setNickname(nickname) }) {
                            Text("保存昵称")
                        }
                    }
                }

                // ---------- 朗读 (TTS) ----------
                item {
                    SettingsSection("朗读 (TTS)", icon = Icons.Default.RecordVoiceOver) {
                        // —— 音色：横向懒加载，固定 56dp ——
                        SettingChipLazyRow(
                            sectionLabel = "音色",
                            options = TtsTimbre.entries.toList(),
                            selected = state.settings.ttsTimbre,
                            label = { it.label },
                            onSelect = viewModel::setTtsTimbre,
                            rowHeight = 56.dp
                        )
                        SettingHint("音色为音调/语速组合，不下载语音包；真正的发声人请在系统「文字转语音」中安装后选择。")

                        // —— 语速 / 音调 ——
                        SettingSliderRow(
                            label = "语速",
                            value = state.settings.ttsRate,
                            valueRange = 0.5f..2.0f,
                            onValueChange = viewModel::setTtsRate
                        ) { "%.1fx".format(it) }

                        SettingSliderRow(
                            label = "音调",
                            value = state.settings.ttsPitch,
                            valueRange = 0.5f..2.0f,
                            onValueChange = viewModel::setTtsPitch
                        ) { "%.1f".format(it) }

                        // —— 自动下一章 ——
                        SettingSwitchRow(
                            title = "读完自动进入下一章",
                            checked = state.settings.ttsAutoNext,
                            onCheckedChange = viewModel::setTtsAutoNext
                        )

                        // —— 发声人：展开后用竖向滚动区（固定高度），避免嵌套 LazyColumn 抢滚动 ——
                        val voices = state.ttsVoices
                        val voicesLoading = state.ttsVoicesLoading
                        var voicesExpanded by rememberSaveable { mutableStateOf(false) }
                        val currentVoiceLabel = voices
                            .firstOrNull { it.name == state.settings.ttsVoiceName }
                            ?.displayName
                            ?: "系统默认"

                        SettingActionRow(
                            title = "发声人（系统语音）",
                            subtitle = "当前：$currentVoiceLabel",
                            actionText = when {
                                voicesLoading -> "检测中…"
                                voices.isEmpty() -> "去安装"
                                voicesExpanded -> "收起"
                                else -> "选择"
                            },
                            onAction = {
                                when {
                                    // 引擎还没就绪：再等一轮，别直接把用户扔到系统设置首页
                                    voicesLoading -> Unit
                                    voices.isEmpty() -> {
                                        viewModel.refreshTtsVoices()
                                        viewModel.launchTtsSettings()
                                    }
                                    else -> voicesExpanded = !voicesExpanded
                                }
                            }
                        )

                        if (voicesLoading) {
                            SettingHint("正在检测系统语音（引擎初始化中）…")
                        } else if (voices.isEmpty()) {
                            SettingHint(
                                "未检测到已安装语音。可点「去安装」前往系统「文字转语音」页面安装语音包，" +
                                    "也可先使用默认语音朗读。"
                            )
                        } else if (voicesExpanded) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(160.dp)
                                    .verticalScroll(rememberScrollState())
                            ) {
                                VoiceRow(
                                    label = "系统默认",
                                    selected = state.settings.ttsVoiceName.isBlank(),
                                    onClick = {
                                        viewModel.setTtsVoice("")
                                        voicesExpanded = false
                                    }
                                )
                                voices.forEach { v ->
                                    VoiceRow(
                                        label = v.displayName,
                                        selected = v.name == state.settings.ttsVoiceName,
                                        onClick = {
                                            viewModel.setTtsVoice(v.name)
                                            voicesExpanded = false
                                        }
                                    )
                                }
                            }
                        }

                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            TextButton(onClick = viewModel::refreshTtsVoices) {
                                Text("刷新语音列表")
                            }
                            TextButton(onClick = viewModel::launchTtsSettings) {
                                Text("系统「文字转语音」设置")
                            }
                        }
                        SettingHint("朗读使用系统 TTS 引擎，可在小说阅读器顶部「朗读」按钮启动。")
                    }
                }

                // ---------- 扫描与目录 ----------
                item {
                    SettingsSection("扫描与目录", icon = Icons.Default.Folder) {
                        SettingActionRow(
                            title = if (hasAllFiles) "已获得文件访问权限"
                            else "未获得文件访问权限（Android 11+ 需授权）",
                            actionText = "去授权",
                            onAction = { StorageAccess.openAllFilesAccessSettings(context) },
                            titleMaxLines = 2
                        )
                        SettingSliderRow(
                            label = "扫描深度",
                            value = state.settings.scanMaxDepth.toFloat(),
                            valueRange = 1f..8f,
                            onValueChange = { viewModel.setScanDepth(it.toInt()) },
                            steps = 6
                        ) { it.toInt().toString() }
                        SettingSwitchRow(
                            title = "跳过隐藏目录",
                            checked = state.settings.skipHidden,
                            onCheckedChange = viewModel::setSkipHidden
                        )
                        if (state.settings.scanDirs.isNotEmpty()) {
                            Text(
                                "已保存目录",
                                style = MaterialTheme.typography.labelLarge,
                                modifier = Modifier.padding(top = 4.dp)
                            )
                            state.settings.scanDirs.forEach { dir ->
                                SettingActionRow(
                                    title = dir,
                                    actionText = "移除",
                                    onAction = { viewModel.removeScanDir(dir) },
                                    titleStyle = MaterialTheme.typography.labelSmall,
                                    titleMaxLines = 2
                                )
                            }
                        }
                        OutlinedTextField(
                            value = newDir,
                            onValueChange = { newDir = it },
                            label = { Text("添加目录（绝对路径）") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Button(onClick = {
                            viewModel.addScanDir(newDir.trim())
                            newDir = ""
                        }) { Text("添加") }
                    }
                }

                // ---------- WebDAV ----------
                item {
                    SettingsSection("备份与同步 (WebDAV)", icon = Icons.Default.Cloud) {
                        SettingHint("备份书库元数据、进度与阅读统计；不含书籍文件。默认关闭。")
                        SettingTextField(
                            value = state.settings.webdavUrl,
                            onValueChange = viewModel::setWebdav,
                            label = "WebDAV 地址",
                            placeholder = "https://dav.example.com/"
                        )
                        SettingTextField(
                            value = state.settings.webdavUser,
                            onValueChange = viewModel::setWebdavUser,
                            label = "用户名"
                        )
                        SettingTextField(
                            value = state.settings.webdavPassword,
                            onValueChange = viewModel::setWebdavPassword,
                            label = "密码",
                            isPassword = true
                        )
                        SettingTextField(
                            value = state.settings.webdavDir,
                            onValueChange = viewModel::setWebdavDir,
                            label = "远程目录"
                        )
                        SettingSwitchRow(
                            title = "自动备份（进入阅读器时）",
                            checked = state.settings.webdavAutoBackup,
                            onCheckedChange = viewModel::setWebdavAutoBackup
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(
                                onClick = viewModel::testConnection,
                                enabled = !state.syncBusy
                            ) { Text("测试连接") }
                            Button(
                                onClick = viewModel::backupNow,
                                enabled = !state.syncBusy
                            ) { Text("立即备份") }
                            TextButton(onClick = viewModel::refreshBackups) {
                                Text("刷新列表")
                            }
                        }
                        if (state.settings.lastBackupAt > 0L) {
                            SettingHint(
                                "上次备份：${FormatUtil.formatDateTime(state.settings.lastBackupAt)}"
                            )
                        }
                        if (state.backups.isNotEmpty()) {
                            Text(
                                "远端备份",
                                style = MaterialTheme.typography.labelLarge,
                                modifier = Modifier.padding(top = 4.dp)
                            )
                            state.backups.take(5).forEach { item ->
                                SettingActionRow(
                                    title = item.name,
                                    subtitle = "${FormatUtil.formatBytes(item.sizeBytes)} · " +
                                        FormatUtil.formatDateTime(item.modifiedAt),
                                    actionText = "恢复",
                                    onAction = { viewModel.restore(item.path) }
                                )
                            }
                        }
                        Row {
                            TextButton(onClick = viewModel::exportSnapshotToFile) {
                                Text("导出到本地文件")
                            }
                        }
                    }
                }

                // ---------- 在线书源 ----------
                item {
                    SettingsSection("在线书源（默认关闭）", icon = Icons.Default.Public) {
                        SettingSwitchRow(
                            title = "启用在线书源",
                            checked = state.settings.onlineSourceEnabled,
                            onCheckedChange = viewModel::setOnlineEnabled
                        )
                        SettingHint(
                            "关闭时不产生任何网络请求。开启后请自行配置书源规则" +
                                "（仅用于搜索并另存为 TXT 到本地书库）。"
                        )
                        if (state.settings.onlineSourceEnabled) {
                            OutlinedTextField(
                                value = onlineJson,
                                onValueChange = { onlineJson = it },
                                label = { Text("书源配置 JSON") },
                                minLines = 6,
                                modifier = Modifier.fillMaxWidth()
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Button(onClick = {
                                    viewModel.setOnlineSourceJson(onlineJson)
                                }) { Text("保存书源") }
                                TextButton(onClick = {
                                    scope.launch {
                                        onlineJson = BookSourceCodec
                                            .templateText(context).orEmpty()
                                    }
                                }) { Text("填入模板") }
                            }
                        }
                    }
                }

                // ---------- 漫画 ----------
                item {
                    SettingsSection("漫画", icon = Icons.Default.AutoStories) {
                        SettingSliderRow(
                            label = "预加载页数",
                            value = state.settings.comicPreload.toFloat(),
                            valueRange = 4f..6f,
                            onValueChange = { viewModel.setComicPreload(it.toInt()) },
                            steps = 1
                        ) { it.toInt().toString() }
                    }
                }

                // ---------- 存储 ----------
                item {
                    SettingsSection("存储", icon = Icons.Default.Storage) {
                        SettingActionRow(
                            title = "封面缓存 ${FormatUtil.formatBytes(state.coverBytes)}",
                            actionText = "清理",
                            onAction = { viewModel.clearCovers() }
                        )
                        SettingActionRow(
                            title = "页面缓存 ${FormatUtil.formatBytes(state.pageBytes)}",
                            actionText = "清理",
                            onAction = { viewModel.clearPages() }
                        )
                        SettingActionRow(
                            title = "目录缓存(SAF) ${FormatUtil.formatBytes(state.safBytes)}",
                            actionText = "清理",
                            onAction = { viewModel.clearSafCache() }
                        )
                    }
                }

                // ---------- 关于 ----------
                item {
                    SettingsSection("关于", icon = Icons.Default.Info) {
                        Text(
                            "Liquid Reader v${Constants.APP_VERSION}",
                            style = MaterialTheme.typography.bodyMedium
                        )
                        SettingHint(
                            "本地小说 / 漫画阅读器 · 支持 EPUB / TXT / PDF / CBZ / ZIP / 图片文件夹"
                        )
                    }
                }
            }
        }
    }
}

private fun labelOf(mode: ThemeMode): String = when (mode) {
    ThemeMode.SYSTEM -> "跟随系统"
    ThemeMode.LIGHT -> "浅色"
    ThemeMode.DARK -> "深色"
}

private fun glassLabelOf(level: String): String = when (level) {
    "OFF" -> "关闭"
    "LOW" -> "弱"
    "MEDIUM" -> "中"
    "HIGH" -> "强"
    else -> level
}
