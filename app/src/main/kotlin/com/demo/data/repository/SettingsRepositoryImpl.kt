package com.demo.data.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore

import com.demo.core.common.util.DeviceTierDetector
import com.demo.core.model.AppSettings
import com.demo.core.model.ComicDirection
import com.demo.core.model.FrameRateMode
import com.demo.core.model.PageFitMode
import com.demo.core.model.PageTurnMode
import com.demo.core.model.TtsTimbre
import com.demo.core.model.ReaderBackground
import com.demo.core.model.ThemeMode

import com.demo.domain.repository.SettingsRepository

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

import java.io.IOException

private val Context.settingsDataStore: DataStore<Preferences> by preferencesDataStore(name = "reader_settings")

class SettingsRepositoryImpl(private val context: Context) : SettingsRepository {

    /** 设备分级：首次读取设置时用于给「动效 / 帧率」兜底默认值 */
    private val deviceTier by lazy { DeviceTierDetector.detect(context) }

    private object Keys {
        val THEME = stringPreferencesKey("theme")
        val DYNAMIC = booleanPreferencesKey("dynamic_color")
        val GLASS = stringPreferencesKey("glass_level")
        val NICKNAME = stringPreferencesKey("nickname")
        val FONT_SIZE = intPreferencesKey("font_size")
        val LINE_HEIGHT = floatPreferencesKey("line_height")
        val LETTER_SPACING = floatPreferencesKey("letter_spacing")
        val BG = stringPreferencesKey("reader_bg")
        val KEEP_SCREEN_ON = booleanPreferencesKey("keep_screen_on")
        val VOLUME_TURN = booleanPreferencesKey("volume_turn")
        val COMIC_DIR = stringPreferencesKey("comic_direction")
        val COMIC_DOUBLE = booleanPreferencesKey("comic_double")
        val COMIC_PRELOAD = intPreferencesKey("comic_preload")
        val PAGE_FIT = stringPreferencesKey("page_fit")
        val SCAN_DEPTH = intPreferencesKey("scan_depth")
        val SCAN_FILES = intPreferencesKey("scan_files")
        val SKIP_HIDDEN = booleanPreferencesKey("skip_hidden")
        val SCAN_DIRS = stringSetPreferencesKey("scan_dirs")
        // 翻页动画
        val PAGE_TURN = stringPreferencesKey("page_turn_mode")
        // TTS
        val TTS_RATE = floatPreferencesKey("tts_rate")
        val TTS_PITCH = floatPreferencesKey("tts_pitch")
        val TTS_AUTO_NEXT = booleanPreferencesKey("tts_auto_next")
        val TTS_TIMBRE = stringPreferencesKey("tts_timbre")
        val TTS_VOICE = stringPreferencesKey("tts_voice")
        // WebDAV
        val WEBDAV_URL = stringPreferencesKey("webdav_url")
        val WEBDAV_USER = stringPreferencesKey("webdav_user")
        val WEBDAV_PASSWORD = stringPreferencesKey("webdav_password")
        val WEBDAV_DIR = stringPreferencesKey("webdav_dir")
        val WEBDAV_AUTO = booleanPreferencesKey("webdav_auto")
        val LAST_BACKUP = longPreferencesKey("last_backup_at")
        // 动效
        val ANIMATIONS = booleanPreferencesKey("animations_enabled")
        val FRAME_RATE = stringPreferencesKey("frame_rate_mode")
        // 沉浸阅读
        val IMMERSIVE = booleanPreferencesKey("immersive_mode")
        // 在线书源
        val ONLINE_ENABLED = booleanPreferencesKey("online_enabled")
        val ONLINE_JSON = stringPreferencesKey("online_json")
    }

    override fun observe(): Flow<AppSettings> = context.settingsDataStore.data
        .catch { if (it is IOException) emit(emptyPreferences()) else throw it }
        .map { p -> p.toSettings() }

    override suspend fun current(): AppSettings = observe().first()

    override suspend fun update(transform: (AppSettings) -> AppSettings) {
        val next = transform(current())
        context.settingsDataStore.edit { p ->
            p[Keys.THEME] = next.themeMode.value
            p[Keys.DYNAMIC] = next.dynamicColor
            p[Keys.GLASS] = next.glassLevel
            p[Keys.NICKNAME] = next.nickname
            p[Keys.FONT_SIZE] = next.fontSize
            p[Keys.LINE_HEIGHT] = next.lineHeightMultiplier
            p[Keys.LETTER_SPACING] = next.letterSpacing
            p[Keys.BG] = next.readerBackground.value
            p[Keys.KEEP_SCREEN_ON] = next.keepScreenOn
            p[Keys.VOLUME_TURN] = next.volumeKeyTurnPage
            p[Keys.COMIC_DIR] = next.comicDirection.name
            p[Keys.COMIC_DOUBLE] = next.comicDoublePage
            p[Keys.COMIC_PRELOAD] = next.comicPreload
            p[Keys.PAGE_FIT] = next.pageFitMode.name
            p[Keys.SCAN_DEPTH] = next.scanMaxDepth
            p[Keys.SCAN_FILES] = next.scanMaxFiles
            p[Keys.SKIP_HIDDEN] = next.skipHidden
            p[Keys.SCAN_DIRS] = next.scanDirs.toSet()
            p[Keys.PAGE_TURN] = next.pageTurnMode.value
            p[Keys.TTS_RATE] = next.ttsRate
            p[Keys.TTS_PITCH] = next.ttsPitch
            p[Keys.TTS_AUTO_NEXT] = next.ttsAutoNext
            p[Keys.TTS_TIMBRE] = next.ttsTimbre.value
            p[Keys.TTS_VOICE] = next.ttsVoiceName
            p[Keys.WEBDAV_URL] = next.webdavUrl
            p[Keys.WEBDAV_USER] = next.webdavUser
            p[Keys.WEBDAV_PASSWORD] = next.webdavPassword
            p[Keys.WEBDAV_DIR] = next.webdavDir
            p[Keys.WEBDAV_AUTO] = next.webdavAutoBackup
            p[Keys.LAST_BACKUP] = next.lastBackupAt
            p[Keys.ANIMATIONS] = next.animationsEnabled
            p[Keys.FRAME_RATE] = next.frameRateMode.value
            p[Keys.IMMERSIVE] = next.immersiveMode
            p[Keys.ONLINE_ENABLED] = next.onlineSourceEnabled
            p[Keys.ONLINE_JSON] = next.onlineSourceJson
        }
    }

    private fun Preferences.toSettings(): AppSettings = AppSettings(
        themeMode = ThemeMode.from(this[Keys.THEME]),
        dynamicColor = this[Keys.DYNAMIC] ?: false,
        glassLevel = this[Keys.GLASS] ?: "OFF",
        animationsEnabled = this[Keys.ANIMATIONS]
            ?: DeviceTierDetector.suggestAnimations(this@SettingsRepositoryImpl.deviceTier),
        frameRateMode = FrameRateMode.from(this[Keys.FRAME_RATE]),
        immersiveMode = this[Keys.IMMERSIVE] ?: false,
        nickname = this[Keys.NICKNAME] ?: "阅读者",
        fontSize = this[Keys.FONT_SIZE] ?: 14,
        // 旧版本存过 4.2f，已超出面板滑杆区间（1.6~3.2），这里统一夹回合法范围
        lineHeightMultiplier = (this[Keys.LINE_HEIGHT] ?: 1.8f).coerceIn(1.2f, 3.2f),
        letterSpacing = this[Keys.LETTER_SPACING] ?: 0.0f,
        readerBackground = ReaderBackground.from(this[Keys.BG]),
        keepScreenOn = this[Keys.KEEP_SCREEN_ON] ?: false,
        volumeKeyTurnPage = this[Keys.VOLUME_TURN] ?: false,
        comicDirection = runCatching { ComicDirection.valueOf(this[Keys.COMIC_DIR] ?: "LTR") }.getOrDefault(ComicDirection.LTR),
        comicDoublePage = this[Keys.COMIC_DOUBLE] ?: false,
        comicPreload = this[Keys.COMIC_PRELOAD] ?: 4,
        pageFitMode = runCatching { PageFitMode.valueOf(this[Keys.PAGE_FIT] ?: "WIDTH") }.getOrDefault(PageFitMode.WIDTH),
        scanMaxDepth = this[Keys.SCAN_DEPTH] ?: 4,
        scanMaxFiles = this[Keys.SCAN_FILES] ?: 20_000,
        skipHidden = this[Keys.SKIP_HIDDEN] ?: true,
        scanDirs = (this[Keys.SCAN_DIRS] ?: emptySet()).toList(),
        pageTurnMode = PageTurnMode.from(this[Keys.PAGE_TURN]),
        ttsRate = this[Keys.TTS_RATE] ?: 1.0f,
        ttsPitch = this[Keys.TTS_PITCH] ?: 1.0f,
        ttsAutoNext = this[Keys.TTS_AUTO_NEXT] ?: true,
        ttsTimbre = TtsTimbre.from(this[Keys.TTS_TIMBRE]),
        ttsVoiceName = this[Keys.TTS_VOICE] ?: "",
        webdavUrl = this[Keys.WEBDAV_URL] ?: "",
        webdavUser = this[Keys.WEBDAV_USER] ?: "",
        webdavPassword = this[Keys.WEBDAV_PASSWORD] ?: "",
        webdavDir = this[Keys.WEBDAV_DIR] ?: "LiquidReader",
        webdavAutoBackup = this[Keys.WEBDAV_AUTO] ?: false,
        lastBackupAt = this[Keys.LAST_BACKUP] ?: 0L,
        onlineSourceEnabled = this[Keys.ONLINE_ENABLED] ?: false,
        onlineSourceJson = this[Keys.ONLINE_JSON] ?: ""
    )
}
