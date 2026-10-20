package com.demo.feature.shelf

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog

import com.demo.core.common.util.StorageAccess
import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.ReaderShapes

import java.io.File

/** 常用扫描目录候选：有全部文件权限时列公共目录，否则列 App 专属目录（必定可读） */
fun defaultScanDirs(context: android.content.Context): List<File> {
    val dirs = ArrayList<File>()
    if (StorageAccess.hasAllFilesAccess()) {
        dirs.addAll(StorageAccess.publicDirCandidates())
    }
    dirs.addAll(StorageAccess.appSpecificDirs(context))
    return dirs.distinctBy { it.absolutePath }
}

/**
 * 导入对话框。
 */
@Composable
fun ImportDialog(
    savedDirs: List<String>,
    onDismiss: () -> Unit,
    onImport: (List<String>) -> Unit,
    onPickDirectory: () -> Unit,
    onRequestPermission: () -> Unit,
    onRemoveDir: (String) -> Unit
) {
    val context = LocalContext.current
    var customPath by remember { mutableStateOf("") }
    val hasAllFiles = remember { StorageAccess.hasAllFilesAccess() }
    val candidates = remember { defaultScanDirs(context) }

    Dialog(onDismissRequest = onDismiss) {
        GlassSurface(
            shape = ReaderShapes.small,
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(Modifier.padding(20.dp)) {
                Text("导入本地书籍", style = MaterialTheme.typography.titleMedium)
                Text(
                    "支持 EPUB / TXT / PDF / CBZ / ZIP / 图片文件夹",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier.padding(top = 4.dp, bottom = 12.dp)
                )

                // 权限状态
                GlassSurface(
                    shape = RoundedCornerShape(16.dp),
                    tintAlpha = if (hasAllFiles) 0.10f else 0.18f,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(Modifier.padding(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                if (hasAllFiles) Icons.Default.FolderOpen else Icons.Default.Lock,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp),
                                tint = if (hasAllFiles) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.error
                            )
                            Text(
                                text = if (hasAllFiles) "已获得文件访问权限" else "未获得文件访问权限",
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.padding(start = 8.dp)
                            )
                        }
                        if (!hasAllFiles) {
                            Text(
                                text = "Android 11+ 分区存储下，直接扫描 /sdcard 需要授权。\n" +
                                    "方式一：授予「所有文件访问权限」；\n" +
                                    "方式二：用系统目录选择器授权单个目录（推荐，无需全盘权限）。",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f),
                                modifier = Modifier.padding(top = 6.dp)
                            )
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 8.dp),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                TextButton(onClick = onRequestPermission) { Text("去授权") }
                                TextButton(onClick = onPickDirectory) { Text("选择目录…") }
                            }
                        } else {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 8.dp),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                TextButton(onClick = onPickDirectory) { Text("选择目录…") }
                            }
                        }
                    }
                }

                // 已保存目录
                if (savedDirs.isNotEmpty()) {
                    Text(
                        "已保存的目录",
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.padding(top = 14.dp, bottom = 4.dp)
                    )
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f, fill = false),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        items(savedDirs) { raw ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { onImport(listOf(raw)) }
                                    .padding(vertical = 8.dp, horizontal = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Default.Folder,
                                    contentDescription = null,
                                    modifier = Modifier.size(20.dp)
                                )
                                Text(
                                    text = displayPath(raw),
                                    style = MaterialTheme.typography.bodyMedium,
                                    modifier = Modifier
                                        .weight(1f)
                                        .padding(start = 10.dp),
                                    maxLines = 2
                                )
                                IconButton(onClick = { onRemoveDir(raw) }) {
                                    Icon(Icons.Default.Close, contentDescription = "移除")
                                }
                            }
                        }
                    }
                } else {
                    Text(
                        "常用目录",
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.padding(top = 14.dp, bottom = 4.dp)
                    )
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f, fill = false),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        items(candidates) { dir ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { onImport(listOf(dir.absolutePath)) }
                                    .padding(vertical = 8.dp, horizontal = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Default.Folder,
                                    contentDescription = null,
                                    modifier = Modifier.size(20.dp)
                                )
                                Text(
                                    dir.absolutePath,
                                    style = MaterialTheme.typography.bodyMedium,
                                    modifier = Modifier.padding(start = 10.dp),
                                    maxLines = 2
                                )
                            }
                        }
                    }
                }

                OutlinedTextField(
                    value = customPath,
                    onValueChange = { customPath = it },
                    label = { Text("自定义路径") },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp)
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) { Text("取消") }
                    TextButton(
                        onClick = {
                            val path = customPath.trim()
                            if (path.isNotEmpty()) onImport(listOf(path))
                        }
                    ) { Text("扫描此路径") }
                }
            }
        }
    }
}

private fun displayPath(raw: String): String = if (raw.startsWith("content://")) {
    val decoded = runCatching { android.net.Uri.decode(raw) }.getOrDefault(raw)
    "SAF · " + decoded.substringAfter("tree/").substringAfter(':')
} else raw

@Composable
fun CreateGroupDialog(
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var name by remember { mutableStateOf("") }
    Dialog(onDismissRequest = onDismiss) {
        GlassSurface(shape = ReaderShapes.large, modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(20.dp)) {
                Text("新建分组", style = MaterialTheme.typography.titleMedium)
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("分组名称") },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp)
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) { Text("取消") }
                    TextButton(onClick = { onConfirm(name.trim()) }) { Text("创建") }
                }
            }
        }
    }
}
