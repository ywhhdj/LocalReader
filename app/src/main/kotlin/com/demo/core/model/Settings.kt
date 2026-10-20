package com.demo.core.model

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

/** 全局设置（DataStore 持久化） */
data class AppSettings(
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val dynamicColor: Boolean = false,
    val glassLevel: String = "OFF",
    val nickname: String = "阅读者",
    // 小说
    val fontSize: Int = 17,
    val lineHeightMultiplier: Float = 1.6f,
    val letterSpacing: Float = 0f,
    val readerBackground: ReaderBackground = ReaderBackground.PAPER,
    val keepScreenOn: Boolean = false,
    val volumeKeyTurnPage: Boolean = false,
    // 漫画
    val comicDirection: ComicDirection = ComicDirection.LTR,
    val comicDoublePage: Boolean = false,
    val comicPreload: Int = 2,
    val pageFitMode: PageFitMode = PageFitMode.WIDTH,
    // 扫描
    val scanMaxDepth: Int = 4,
    val scanMaxFiles: Int = 20_000,
    val skipHidden: Boolean = true
)
