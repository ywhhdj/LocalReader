package com.demo.feature.shelf

import android.os.Environment
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
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material3.Icon
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog

import com.demo.core.ui.glass.GlassSurface
import com.demo.core.ui.theme.ReaderShapes

import java.io.File

/** 常用扫描目录（真机测试用，可在设置页扩展） */
fun defaultScanDirs(): List<File> {
    val root = Environment.getExternalStorageDirectory()
    val candidates = listOf("Books", "Download", "Documents", "Comics", " novels", "Ebook")
    val dirs = mutableListOf(root)
    candidates.forEach { name ->
        val dir = File(root, name.trim())
        if (dir.exists() && dir.isDirectory) dirs.add(dir)
    }
    return dirs.distinctBy { it.absolutePath }
}

@Composable
fun ImportDialog(
    onDismiss: () -> Unit,
    onImport: (List<String>) -> Unit
) {
    var customPath by remember { mutableStateOf("") }
    val dirs = remember { defaultScanDirs() }

    Dialog(onDismissRequest = onDismiss) {
        GlassSurface(shape = ReaderShapes.large, modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(20.dp)) {
                Text("导入本地书籍", style = MaterialTheme.typography.titleMedium)
                Text(
                    "选择目录开始扫描（支持 EPUB / TXT / PDF / CBZ / ZIP / 图片文件夹）",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier.padding(top = 4.dp, bottom = 12.dp)
                )
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f, fill = false),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    items(dirs) { dir ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onImport(listOf(dir.absolutePath)) }
                                .padding(vertical = 10.dp, horizontal = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Folder, contentDescription = null, modifier = Modifier.size(20.dp))
                            Text(
                                dir.absolutePath,
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.padding(start = 10.dp)
                            )
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
