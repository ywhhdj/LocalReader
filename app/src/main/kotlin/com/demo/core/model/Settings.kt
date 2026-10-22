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

/**
 * 朗读音色（预设）。
 *
 * 说明：系统 TextToSpeech 不提供音色包下载能力，这里的"音色"是通过
 * **音调 + 语速**组合模拟的听感差异，不产生任何网络请求、不下载语音包。
 * 真正换发声人需使用系统已安装语音（见 [AppSettings.ttsVoiceName]），
 * 缺失时由用户自行到系统「文字转语音」设置里下载。
 */
enum class TtsTimbre(val value: String, val label: String, val pitch: Float, val rate: Float) {
    DEFAULT("DEFAULT", "默认", 1.0f, 1.0f),
    GIRL("GIRL", "少女音", 1.35f, 1.0f),
    LOLI("LOLI", "萝莉音", 1.7f, 1.08f),
    WOMAN("WOMAN", "成熟女声", 1.1f, 0.98f),
    MAN("MAN", "成熟男声", 0.75f, 0.95f);

    companion object {
        fun from(value: String?): TtsTimbre =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: DEFAULT
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
 * 全局设置（DataStore 持久化）
 */
data class AppSettings(
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val dynamicColor: Boolean = false,
    val glassLevel: String = "OFF",
    val nickname: String = "阅读者",
    // 小说
    val fontSize: Int = 14,
    val lineHeightMultiplier: Float = 4.2f,
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
    // 翻页动画
    val pageTurnMode: PageTurnMode = PageTurnMode.SLIDE,
    // 朗读（TTS）
    val ttsRate: Float = 1.0f,
    val ttsPitch: Float = 1.0f,
    /** 朗读完当前章节自动继续下一章 */
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
