package com.demo.core.common.util

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.content.ContextCompat
import java.io.File

/**
 * 存储访问与权限处理。
 */
object StorageAccess {

    /** 是否需要"所有文件访问权限"才能直接以 File 方式遍历公共目录 */
    fun needsAllFilesAccess(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R

    fun hasAllFilesAccess(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Environment.isExternalStorageManager()
        else true

    fun hasReadExternalStorage(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return true // 33+ 该权限不再授予给第三方
        return ContextCompat.checkSelfPermission(context, Manifest.permission.READ_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED
    }

    /** Android 13+ 媒体权限（仅影响媒体库，不覆盖文档类文件，仅作辅助） */
    fun hasReadMedia(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        val images = ContextCompat.checkSelfPermission(context, Manifest.permission.READ_MEDIA_IMAGES)
        val video = ContextCompat.checkSelfPermission(context, Manifest.permission.READ_MEDIA_VIDEO)
        val audio = ContextCompat.checkSelfPermission(context, Manifest.permission.READ_MEDIA_AUDIO)
        return images == PackageManager.PERMISSION_GRANTED ||
            video == PackageManager.PERMISSION_GRANTED ||
            audio == PackageManager.PERMISSION_GRANTED
    }

    /** 是否可以直接用文件路径扫描（无需 SAF） */
    fun canScanByPath(context: Context): Boolean =
        hasAllFilesAccess() || (!needsAllFilesAccess() && hasReadExternalStorage(context))

    /** 缺失的运行时权限清单 */
    fun missingPermissions(context: Context): List<String> {
        val result = ArrayList<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_MEDIA_IMAGES)
                != PackageManager.PERMISSION_GRANTED
            ) result.add(Manifest.permission.READ_MEDIA_IMAGES)
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_MEDIA_VIDEO)
                != PackageManager.PERMISSION_GRANTED
            ) result.add(Manifest.permission.READ_MEDIA_VIDEO)
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_MEDIA_AUDIO)
                != PackageManager.PERMISSION_GRANTED
            ) result.add(Manifest.permission.READ_MEDIA_AUDIO)
        } else if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_EXTERNAL_STORAGE)
            != PackageManager.PERMISSION_GRANTED
        ) {
            result.add(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        return result
    }

    /** 跳转系统"所有文件访问权限"设置页 */
    fun openAllFilesAccessSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        if (intent.resolveActivity(context.packageManager) != null) {
            context.startActivity(intent)
        } else {
            context.startActivity(
                Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    /** App 专属目录（一定可读写，作为兜底扫描目录） */
    fun appSpecificDirs(context: Context): List<File> {
        val dirs = ArrayList<File>()
        context.getExternalFilesDir(null)?.let { dirs.add(it) }
        context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)?.let { dirs.add(it) }
        context.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS)?.let { dirs.add(it) }
        return dirs.distinctBy { it.absolutePath }
    }

    /**
     * 常见公共目录候选（仅当拥有所有文件访问权限时才有意义）。
     * 无权限时 UI 应引导授权或改用 SAF。
     */
    fun publicDirCandidates(): List<File> {
        val root = runCatching { Environment.getExternalStorageDirectory() }.getOrNull() ?: return emptyList()
        val names = listOf(
            "Books", "books", "Download", "Downloads", "Documents", "Comics", "comics",
            "Ebook", "ebooks", "Novels", "小说", "书籍", "漫画"
        )
        val dirs = ArrayList<File>()
        dirs.add(root)
        names.forEach { n ->
            val d = File(root, n)
            if (d.isDirectory) dirs.add(d)
        }
        return dirs.distinctBy { it.absolutePath }
    }

    /** 目录是否可读（无权限时返回 false，用于 UI 灰置提示） */
    fun isReadable(dir: File): Boolean = runCatching {
        dir.exists() && dir.isDirectory && (dir.listFiles() != null)
    }.getOrDefault(false)

    fun requestPermissions(activity: Activity, requestCode: Int): Boolean {
        val missing = missingPermissions(activity)
        if (missing.isEmpty()) return false
        androidx.core.app.ActivityCompat.requestPermissions(activity, missing.toTypedArray(), requestCode)
        return true
    }
}
