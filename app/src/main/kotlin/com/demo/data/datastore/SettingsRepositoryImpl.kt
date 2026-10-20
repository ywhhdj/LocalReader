package com.demo.data.datastore

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.demo.core.model.AppSettings
import com.demo.core.model.ComicDirection
import com.demo.core.model.PageFitMode
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
        }
    }

    private fun Preferences.toSettings(): AppSettings = AppSettings(
        themeMode = ThemeMode.from(this[Keys.THEME]),
        dynamicColor = this[Keys.DYNAMIC] ?: false,
        glassLevel = this[Keys.GLASS] ?: "OFF",
        nickname = this[Keys.NICKNAME] ?: "阅读者",
        fontSize = this[Keys.FONT_SIZE] ?: 17,
        lineHeightMultiplier = this[Keys.LINE_HEIGHT] ?: 1.6f,
        letterSpacing = this[Keys.LETTER_SPACING] ?: 0f,
        readerBackground = ReaderBackground.from(this[Keys.BG]),
        keepScreenOn = this[Keys.KEEP_SCREEN_ON] ?: false,
        volumeKeyTurnPage = this[Keys.VOLUME_TURN] ?: false,
        comicDirection = runCatching { ComicDirection.valueOf(this[Keys.COMIC_DIR] ?: "LTR") }.getOrDefault(ComicDirection.LTR),
        comicDoublePage = this[Keys.COMIC_DOUBLE] ?: false,
        comicPreload = this[Keys.COMIC_PRELOAD] ?: 2,
        pageFitMode = runCatching { PageFitMode.valueOf(this[Keys.PAGE_FIT] ?: "WIDTH") }.getOrDefault(PageFitMode.WIDTH),
        scanMaxDepth = this[Keys.SCAN_DEPTH] ?: 4,
        scanMaxFiles = this[Keys.SCAN_FILES] ?: 20_000,
        skipHidden = this[Keys.SKIP_HIDDEN] ?: true
    )
}
