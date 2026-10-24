package com.demo.assembly.di

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider

import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.Logger

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

import java.io.File

import com.demo.data.di.RepositoryFactory
import com.demo.data.di.Repositories

import com.demo.domain.usecase.BackupNowUseCase
import com.demo.domain.usecase.CreateGroupUseCase
import com.demo.domain.usecase.DeleteBooksUseCase
import com.demo.domain.usecase.ExportSnapshotUseCase
import com.demo.domain.usecase.GetBookUseCase
import com.demo.domain.usecase.GetStatsUseCase
import com.demo.domain.usecase.ImportBooksUseCase
import com.demo.domain.usecase.ImportSnapshotUseCase
import com.demo.domain.usecase.ListBackupsUseCase
import com.demo.domain.usecase.LoadHomeSectionsUseCase
import com.demo.domain.usecase.LoadShelfPageUseCase
import com.demo.domain.usecase.MoveToGroupUseCase
import com.demo.domain.usecase.ObserveGroupsUseCase
import com.demo.domain.usecase.ObserveSettingsUseCase
import com.demo.domain.usecase.OnlineChaptersUseCase
import com.demo.domain.usecase.OnlineContentUseCase
import com.demo.domain.usecase.OnlineSearchUseCase
import com.demo.domain.usecase.OnlineSourcesUseCase
import com.demo.domain.usecase.OpenComicUseCase
import com.demo.domain.usecase.OpenNovelUseCase
import com.demo.domain.usecase.ReadingSessionUseCase
import com.demo.domain.usecase.RestoreBackupUseCase
import com.demo.domain.usecase.SearchBooksUseCase
import com.demo.domain.usecase.TestSyncConnectionUseCase
import com.demo.domain.usecase.ToggleFavoriteUseCase
import com.demo.domain.usecase.UpdateProgressUseCase
import com.demo.domain.usecase.UpdateSettingsUseCase

import com.demo.feature.detail.DetailViewModel
import com.demo.feature.profile.ProfileViewModel
import com.demo.feature.reader.comic.ComicReaderViewModel
import com.demo.feature.reader.novel.NovelReaderViewModel
import com.demo.feature.settings.SettingsViewModel
import com.demo.feature.shelf.FavoritesViewModel
import com.demo.feature.shelf.OnlineSearchViewModel
import com.demo.feature.shelf.ShelfViewModel

/**
 * DI 容器：创建顺序 数据库 → 仓储 → 用例 → ViewModel。
 */
class AppContainer(context: Context) : ViewModelProvider.Factory {

    private val repos: Repositories = RepositoryFactory.create(context)

    // 用例
    private val loadHomeSections = LoadHomeSectionsUseCase(repos.bookRepository)
    private val loadShelfPage = LoadShelfPageUseCase(repos.bookRepository)
    private val observeGroups = ObserveGroupsUseCase(repos.groupRepository)
    private val observeSettings = ObserveSettingsUseCase(repos.settingsRepository)
    private val updateSettings = UpdateSettingsUseCase(repos.settingsRepository)
    private val searchBooks = SearchBooksUseCase(repos.bookRepository)
    private val importBooks = ImportBooksUseCase(repos.scannerRepository)
    private val createGroup = CreateGroupUseCase(repos.groupRepository)
    private val toggleFavorite = ToggleFavoriteUseCase(repos.bookRepository)
    private val moveToGroup = MoveToGroupUseCase(repos.bookRepository)
    private val deleteBooks = DeleteBooksUseCase(repos.bookRepository)
    private val getBook = GetBookUseCase(repos.bookRepository)
    private val updateProgress = UpdateProgressUseCase(repos.bookRepository)
    private val openNovel = OpenNovelUseCase(repos.readerRepository)
    private val openComic = OpenComicUseCase(repos.readerRepository)
    private val session = ReadingSessionUseCase(repos.statsRepository)
    private val getStats = GetStatsUseCase(repos.statsRepository)

    // 备份同步
    private val testSync = TestSyncConnectionUseCase(repos.syncRepository)
    private val backupNow = BackupNowUseCase(repos.syncRepository)
    private val listBackups = ListBackupsUseCase(repos.syncRepository)
    private val restoreBackup = RestoreBackupUseCase(repos.syncRepository)
    private val exportSnapshot = ExportSnapshotUseCase(repos.syncRepository)
    private val importSnapshot = ImportSnapshotUseCase(repos.syncRepository)

    // 在线书源（默认关闭）
    private val onlineSources = OnlineSourcesUseCase(repos.bookSourceRepository)
    private val onlineSearch = OnlineSearchUseCase(repos.bookSourceRepository)
    private val onlineChapters = OnlineChaptersUseCase(repos.bookSourceRepository)
    private val onlineContent = OnlineContentUseCase(repos.bookSourceRepository)

    val settingsRepository = repos.settingsRepository
    val bookCacheDir = repos.bookCacheDir
    val ttsRepository = repos.ttsRepository
    val bookSourceRepository = repos.bookSourceRepository
    val safScanner = repos.safScanner

    /** 清理用的独立作用域：不随任何页面生命周期，进程内长期存活 */
    private val cleanupScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * 清理解压类临时文件（退出时 / 冷启动时各调一次）。
     *
     * 范围：
     * - 页缓存：CBZ/ZIP/RAR 解压出的图片、PDF 渲染结果（可再生，重开时按需再解）；
     * - 书籍缓存目录：EPUB 正文图片解压产物。
     *
     * 不动：封面缓存（书架要用，重建成本高且体积小）、SAF 物化目录（书籍源文件，删了书就读不了）。
     */
    fun cleanupExtracted() {
        cleanupScope.launch {
            runCatching { repos.pageCache.clear() }
                .onFailure { Logger.w("清理页缓存失败：${it.message}", "AppContainer") }
            runCatching { clearDirChildren(repos.bookCacheDir) }
                .onFailure { Logger.w("清理书籍缓存失败：${it.message}", "AppContainer") }
        }
    }

    private fun clearDirChildren(dir: File) {
        val children = dir.listFiles() ?: return
        for (child in children) FileUtil.deleteRecursively(child)
    }

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T = when (modelClass) {
        ShelfViewModel::class.java -> ShelfViewModel(
            loadHomeSections,
            loadShelfPage,
            observeGroups,
            observeSettings,
            updateSettings,
            searchBooks,
            importBooks,
            createGroup,
            toggleFavorite,
            moveToGroup,
            deleteBooks
        ) as T

        FavoritesViewModel::class.java -> FavoritesViewModel(
            loadHomeSections,
            loadShelfPage,
            observeSettings,
            toggleFavorite,
            deleteBooks
        ) as T

        OnlineSearchViewModel::class.java -> OnlineSearchViewModel(
            onlineSources,
            onlineSearch,
            onlineChapters,
            repos.bookSourceRepository,
            importBooks,
            observeSettings
        ) as T

        DetailViewModel::class.java -> DetailViewModel(
            getBook,
            observeGroups,
            toggleFavorite,
            moveToGroup,
            deleteBooks,
            updateProgress,
            repos.readerRepository
        ) as T

        NovelReaderViewModel::class.java -> NovelReaderViewModel(
            getBook,
            openNovel,
            repos.readerRepository,
            repos.progressRepository,
            repos.settingsRepository,
            session,
            repos.ttsRepository,
        ) as T

        ComicReaderViewModel::class.java -> ComicReaderViewModel(
            getBook,
            openComic,
            repos.progressRepository,
            repos.settingsRepository,
            session,
        ) as T

        ProfileViewModel::class.java -> ProfileViewModel(
            getStats,
            repos.statsRepository,
            observeSettings,
            updateSettings,
        ) as T

        SettingsViewModel::class.java -> SettingsViewModel(
            observeSettings,
            updateSettings,
            repos.storageRepository,
            testSync,
            backupNow,
            listBackups,
            restoreBackup,
            exportSnapshot,
            importSnapshot,
            onlineSources,
            repos.ttsRepository
        ) as T

        else -> throw IllegalArgumentException("未知 ViewModel：$modelClass")
    }
}
