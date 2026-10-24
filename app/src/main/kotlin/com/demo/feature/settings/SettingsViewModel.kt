package com.demo.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

import com.demo.core.model.AppSettings
import com.demo.core.model.FrameRateMode
import com.demo.core.model.ThemeMode
import com.demo.core.model.TtsTimbre
import com.demo.core.model.TtsVoice
import com.demo.core.model.SyncResult
import com.demo.core.model.RemoteBackup

import com.demo.domain.codec.BookSourceCodec


import com.demo.domain.usecase.BackupNowUseCase
import com.demo.domain.usecase.ExportSnapshotUseCase
import com.demo.domain.usecase.ImportSnapshotUseCase
import com.demo.domain.usecase.ListBackupsUseCase
import com.demo.domain.usecase.ObserveSettingsUseCase
import com.demo.domain.usecase.OnlineSourcesUseCase
import com.demo.domain.usecase.RestoreBackupUseCase
import com.demo.domain.usecase.TestSyncConnectionUseCase
import com.demo.domain.usecase.UpdateSettingsUseCase
import com.demo.domain.usecase.syncConfig
import com.demo.domain.repository.TtsRepository
import com.demo.domain.repository.StorageRepository


data class SettingsUiState(
  val settings: AppSettings = AppSettings(),
  val coverBytes: Long = 0L,
  val pageBytes: Long = 0L,
  val safBytes: Long = 0L,
  val backups: List<RemoteBackup> = emptyList(),
  val syncBusy: Boolean = false,
  val message: String? = null,
  val ttsVoices: List<TtsVoice> = emptyList(),
  /** 正在检测系统语音：引擎初始化需要时间，用于 UI 显示"检测中"而不是直接跳走 */
  val ttsVoicesLoading: Boolean = false
)

class SettingsViewModel(
  private val observeSettings: ObserveSettingsUseCase,
  private val updateSettings: UpdateSettingsUseCase,
  private val storage: StorageRepository,
  private val testSync: TestSyncConnectionUseCase,
  private val backupNow: BackupNowUseCase,
  private val listBackups: ListBackupsUseCase,
  private val restoreBackup: RestoreBackupUseCase,
  private val exportSnapshot: ExportSnapshotUseCase,
  private val importSnapshot: ImportSnapshotUseCase,
  private val onlineSources: OnlineSourcesUseCase,
  private val ttsRepository: TtsRepository,
) : ViewModel() {

  private val _uiState = MutableStateFlow(SettingsUiState())
  val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

  init {
    viewModelScope.launch {
      observeSettings().collectLatest { settings ->
        _uiState.update { it.copy(settings = settings) }
      }
    }
    refreshCache()
  }

  fun refreshCache() {
    viewModelScope.launch {
      _uiState.update {
        it.copy(
          coverBytes = storage.coverCacheBytes(),
          pageBytes = storage.pageCacheBytes(),
          safBytes = storage.safCacheBytes()
        )
      }
    }
  }

  fun setTheme(mode: ThemeMode) = update { it.copy(themeMode = mode) }
  fun setDynamicColor(enabled: Boolean) = update { it.copy(dynamicColor = enabled) }
  fun setGlassLevel(level: String) = update { it.copy(glassLevel = level) }
  /** 界面动效总开关（关闭后翻页/面板/背景光斑全部退化为瞬时切换） */
  fun setAnimationsEnabled(enabled: Boolean) = update { it.copy(animationsEnabled = enabled) }
  /** 持续型动画帧率上限 */
  fun setFrameRateMode(mode: FrameRateMode) = update { it.copy(frameRateMode = mode) }

  /** 沉浸阅读 */
  fun setImmersiveMode(enabled: Boolean) = update { it.copy(immersiveMode = enabled) }

  fun setNickname(name: String) = update { it.copy(nickname = name.ifBlank { "阅读者" }) }
  fun setComicPreload(count: Int) = update { it.copy(comicPreload = count.coerceIn(4, 6)) }
  fun setScanDepth(depth: Int) = update { it.copy(scanMaxDepth = depth.coerceIn(1, 8)) }
  fun setSkipHidden(skip: Boolean) = update { it.copy(skipHidden = skip) }

  // ---------- 扫描目录 ----------
  fun addScanDir(raw: String) {
    if (raw.isBlank()) return
    update { s ->
      if (raw in s.scanDirs) s else s.copy(scanDirs = (s.scanDirs + raw).distinct().take(20))
    }
  }

  fun removeScanDir(raw: String) = update { s -> s.copy(scanDirs = s.scanDirs - raw) }

  // ---------- 朗读 ----------
  fun setTtsRate(value: Float) = update { it.copy(ttsRate = value.coerceIn(0.5f, 2.0f)) }
  fun setTtsPitch(value: Float) = viewModelScope.launch {
    update { it.copy(ttsPitch = value.coerceIn(0.5f, 2.0f)) }
  }
  fun setTtsAutoNext(enabled: Boolean) = update { it.copy(ttsAutoNext = enabled) }
  /**
   * 读取系统语音列表。
   *
   * 引擎初始化是异步的（独立 HandlerThread 上绑定服务 + 校验语音数据），
   * 进入设置页时往往还没就绪：这里等待就绪（内部有超时）后再读，
   * 期间 UI 显示"检测中"，避免"点选择没有列表、点去下载直接跳走"。
   */
  fun refreshTtsVoices() {
    viewModelScope.launch {
      _uiState.update { it.copy(ttsVoicesLoading = true) }
      val list = runCatching {
        ttsRepository.availableVoices()
      }.getOrDefault(emptyList())
      _uiState.update { it.copy(ttsVoices = list, ttsVoicesLoading = false) }
    }
  }
    fun setTtsTimbre(timbre: TtsTimbre) = viewModelScope.launch {
    ttsRepository.setPitch(timbre.pitch)
    ttsRepository.setRate(timbre.rate)
    update { it.copy(ttsTimbre = timbre) }
  }
  fun setTtsVoice(name: String) = viewModelScope.launch {
    ttsRepository.setVoice(name)
    update { it.copy(ttsVoiceName = name) }
  }
  fun openSystemTtsSettings() = ttsRepository.openSystemSettings()
  fun launchTtsSettings()= ttsRepository.launchTtsSettings()

  // ---------- WebDAV ----------
  fun setWebdav(url: String) = update { it.copy(webdavUrl = url.trim()) }
  fun setWebdavUser(user: String) = update { it.copy(webdavUser = user.trim()) }
  fun setWebdavPassword(password: String) = update { it.copy(webdavPassword = password) }
  fun setWebdavDir(dir: String) = update { it.copy(webdavDir = dir.trim()) }
  fun setWebdavAutoBackup(enabled: Boolean) = update { it.copy(webdavAutoBackup = enabled) }

  fun testConnection() = syncAction("连接") {settings -> 
    testSync(settings.syncConfig())
  }

  fun backupNow() = syncAction("备份") { settings ->
    val result = backupNow(settings.syncConfig())
    if (result.success) refreshBackups()
    result
  }

  fun refreshBackups() {
    viewModelScope.launch {
      val items = runCatching { 
        listBackups(_uiState.value.settings.syncConfig())
      }.getOrDefault(emptyList())
      _uiState.update { it.copy(backups = items) }
    }
  }

  fun restore(path: String) =
    syncAction("恢复") { settings -> restoreBackup(settings.syncConfig(), path) }

  fun exportSnapshotToFile() {
    viewModelScope.launch {
      val path = this@SettingsViewModel.exportSnapshot.invoke()
      _uiState.update { it.copy(message = if (path == null) "导出失败" else "已导出到：$path") }
    }
  }

  fun importSnapshot(content: String) = syncAction("导入") { this.importSnapshot.invoke(content) }

  private fun syncAction(label: String, block: suspend (AppSettings) -> SyncResult) {
    viewModelScope.launch {
      _uiState.update { it.copy(syncBusy = true) }
      val result =
        runCatching { block(_uiState.value.settings) }.getOrElse { e ->
          SyncResult(false, "${label}失败：${e.message ?: "未知错误"}")
        }
      _uiState.update {
        it.copy(
          syncBusy = false,
          message = result.message,
          settings =
            if (result.success && label == "备份") {
              it.settings.copy(lastBackupAt = System.currentTimeMillis())
            } else it.settings
        )
      }
      if (result.success && label == "备份") {
        update { s -> s.copy(lastBackupAt = System.currentTimeMillis()) }
      }
    }
  }

  // ---------- 在线书源（默认关闭） ----------
  fun setOnlineEnabled(enabled: Boolean) = update { it.copy(onlineSourceEnabled = enabled) }

  fun setOnlineSourceJson(json: String) {
    update { it.copy(onlineSourceJson = json) }
    viewModelScope.launch { onlineSources.update(BookSourceCodec.decode(json)) }
  }

  // ---------- 缓存 ----------
  fun clearCovers() {
    viewModelScope.launch {
      storage.clearCovers()
      _uiState.update { it.copy(message = "封面缓存已清理", coverBytes = 0L) }
    }
  }

  fun clearPages() {
    viewModelScope.launch {
      storage.clearPages()
      _uiState.update { it.copy(message = "页面缓存已清理", pageBytes = 0L) }
    }
  }

  fun clearSafCache() {
    viewModelScope.launch {
      storage.clearSafCache()
      _uiState.update { it.copy(message = "目录缓存已清理", safBytes = 0L) }
    }
  }

  fun consumeMessage() = _uiState.update { it.copy(message = null) }

  private fun update(transform: (AppSettings) -> AppSettings) {
    viewModelScope.launch { updateSettings(transform) }
  }
}
