package com.demo.core.common.util

import android.Manifest
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
        // 阅读器只需要图片（漫画页 / 封面）。视频与音频权限与业务无关，已移除声明。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(context, Manifest.permission.READ_MEDIA_IMAGES) ==
            PackageManager.PERMISSION_GRANTED
    }

    /** 是否可以直接用文件路径扫描（无需 SAF） */
    fun canScanByPath(context: Context): Boolean =
        hasAllFilesAccess() || (!needsAllFilesAccess() && hasReadExternalStorage(context))

    /**
     * 缺失的运行时权限清单。
     * Android 13+ 只申请 READ_MEDIA_IMAGES：音视频权限与阅读无关，
     * 申请既无法通过商店审核，也拿不到文档类书籍（后者仍需 SAF / 所有文件访问权限）。
     */
    fun missingPermissions(context: Context): List<String> {
        val result = ArrayList<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_MEDIA_IMAGES)
                != PackageManager.PERMISSION_GRANTED
            ) result.add(Manifest.permission.READ_MEDIA_IMAGES)
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
}
