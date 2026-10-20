package com.demo.core.model

import com.demo.core.common.util.Constants

/** 主题模式（core-model 定义，供 domain/data/UI 共用） */
enum class ThemeMode(val value: String) {
    SYSTEM("SYSTEM"), LIGHT("LIGHT"), DARK("DARK");

    companion object {
        fun from(value: String?): ThemeMode =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: SYSTEM
    }
}

/** 小说阅读背景 */
enum class ReaderBackground(val value: String) {
    PAPER("PAPER"), CREAM("CREAM"), NIGHT("NIGHT"), GREEN("GREEN");

    companion object {
        fun from(value: String?): ReaderBackground =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: PAPER
    }
}

/**
 * 全局设置（DataStore 持久化）
 */
data class AppSettings(
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val dynamicColor: Boolean = false,
    val glassLevel: String = "OFF",
    val nickname: String = "阅读者",
    // 小说
    val fontSize: Int = 14,
    val lineHeightMultiplier: Float = 2.2f,
    val letterSpacing: Float = 1.0f,
    val readerBackground: ReaderBackground = ReaderBackground.PAPER,
    val keepScreenOn: Boolean = false,
    val volumeKeyTurnPage: Boolean = false,
    // 漫画
    val comicDirection: ComicDirection = ComicDirection.LTR,
    val comicDoublePage: Boolean = false,
    val comicPreload: Int = 4,
    val pageFitMode: PageFitMode = PageFitMode.WIDTH,
    // 扫描
    val scanMaxDepth: Int = 4,
    val scanMaxFiles: Int = 20_000,
    val skipHidden: Boolean = true,
    /** 已保存的扫描目录：本地绝对路径或 SAF 树 URI（content://...） */
    val scanDirs: List<String> = emptyList(),
    // 朗读（TTS）
    val ttsRate: Float = 1.0f,
    val ttsPitch: Float = 1.0f,
    /** 朗读完当前章节自动继续下一章 */
    val ttsAutoNext: Boolean = true,
    // WebDAV 备份（默认关闭）
    val webdavUrl: String = "",
    val webdavUser: String = "",
    val webdavPassword: String = "",
    val webdavDir: String = Constants.APP_NAME,
    val webdavAutoBackup: Boolean = false,
    val lastBackupAt: Long = 0L,
    // 在线书源（默认关闭，关闭时不产生任何网络请求）
    val onlineSourceEnabled: Boolean = false,
    val onlineSourceJson: String = ""
)
