package com.demo.core.model

import com.demo.core.common.util.Constants

/** 主题模式（core-model 定义，供 domain/data/UI 共用） */
enum class ThemeMode(val value: String) {
    SYSTEM("SYSTEM"),
    LIGHT("LIGHT"), 
    DARK("DARK");

    companion object {
        fun from(value: String?): ThemeMode =
            entries.firstOrNull { 
                it.value.equals(value, ignoreCase = true)
            } ?: SYSTEM
    }
}

/** 小说翻页动画 */
enum class PageTurnMode(val value: String, val label: String) {
    /** 左右平移（原有行为） */
    SLIDE("SLIDE", "平移"),

    /** 仿真翻页：伪 3D 绕书脊翻转（低成本实现，非逐像素卷曲） */
    SIMULATION("SIMULATION", "仿真"),

    /** 无动画：直接切换，最省性能 */
    NONE("NONE", "无");

    companion object {
        fun from(value: String?): PageTurnMode =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: SLIDE
    }
}

/** 小说阅读背景 */
enum class ReaderBackground(val value: String) {
    PAPER("PAPER"),
    CREAM("CREAM"), // 奶油
    NIGHT("NIGHT"),
    GREEN("GREEN");

    companion object {
        fun from(value: String?): ReaderBackground =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: PAPER
    }
}

/**
 * 帧率上限模式。
 * 作用对象是"持续型动画"（背景光斑、翻页帧循环）的更新频率，
 * 而不是强行改写屏幕刷新率（Android 未提供该能力）。
 */
enum class FrameRateMode(val value: String, val label: String, val fps: Int) {
    /** 按设备分级自动决定 */
    AUTO("AUTO", "自动", 0),
    HIGH("HIGH", "60fps", 60),
    BALANCED("BALANCED", "30fps", 30);

    companion object {
        fun from(value: String?): FrameRateMode =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: AUTO
    }
}

/**
 * 全局设置（DataStore 持久化）
 */
data class AppSettings(
    // 外观
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val dynamicColor: Boolean = false,
    val glassLevel: String = "OFF",
    /** 界面动效总开关：关闭后翻页/面板/背景光斑全部退化为瞬时切换 */
    val animationsEnabled: Boolean = true,
    /** 持续型动画的帧率上限 */
    val frameRateMode: FrameRateMode = FrameRateMode.AUTO,
    /** 沉浸阅读：隐藏状态栏 */
    val immersiveMode: Boolean = false,

    // 用户
    val nickname: String = "阅读者",

    // 小说
    val fontSize: Int = 14,
    /** 行距倍数：与阅读设置面板滑杆区间（1.6~3.2）保持一致 */
    val lineHeightMultiplier: Float = 1.8f,
    val letterSpacing: Float = 0.0f,
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
    val pageTurnMode: PageTurnMode = PageTurnMode.SLIDE,

    // 朗读（TTS）
    val ttsRate: Float = 1.0f,
    val ttsPitch: Float = 1.0f,
    val ttsAutoNext: Boolean = true,
    /** 音色预设（音调/语速组合，不下载任何语音包） */
    val ttsTimbre: TtsTimbre = TtsTimbre.DEFAULT,
    /** 系统语音名（空 = 系统默认）；语音需用户在系统设置中下载后才会出现在列表里 */
    val ttsVoiceName: String = "",

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
