package com.demo.assembly.di

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider

import com.demo.data.di.RepositoryFactory
import com.demo.data.di.Repositories

import com.demo.domain.usecase.CreateGroupUseCase
import com.demo.domain.usecase.DeleteBooksUseCase
import com.demo.domain.usecase.GetBookUseCase
import com.demo.domain.usecase.GetStatsUseCase
import com.demo.domain.usecase.ImportBooksUseCase
import com.demo.domain.usecase.LoadHomeSectionsUseCase
import com.demo.domain.usecase.LoadShelfPageUseCase
import com.demo.domain.usecase.MoveToGroupUseCase
import com.demo.domain.usecase.ObserveGroupsUseCase
import com.demo.domain.usecase.ObserveSettingsUseCase
import com.demo.domain.usecase.OpenComicUseCase
import com.demo.domain.usecase.OpenNovelUseCase
import com.demo.domain.usecase.ReadingSessionUseCase
import com.demo.domain.usecase.SearchBooksUseCase
import com.demo.domain.usecase.ToggleFavoriteUseCase
import com.demo.domain.usecase.UpdateProgressUseCase
import com.demo.domain.usecase.UpdateSettingsUseCase

import com.demo.feature.detail.DetailViewModel
import com.demo.feature.profile.ProfileViewModel
import com.demo.feature.reader.comic.ComicReaderViewModel
import com.demo.feature.reader.novel.NovelReaderViewModel
import com.demo.feature.settings.SettingsViewModel
import com.demo.feature.shelf.ShelfViewModel

/**
 * 手写 DI 容器：创建顺序 数据库 → 仓储 → 用例 → ViewModel。
 * 不引入 Hilt/Koin，减少依赖与编译复杂度，同时保持分层清晰。
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

    val settingsRepository = repos.settingsRepository
    val bookCacheDir = repos.bookCacheDir

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T = when (modelClass) {
        ShelfViewModel::class.java -> ShelfViewModel(
            loadHomeSections, loadShelfPage, observeGroups, observeSettings, updateSettings,
            searchBooks, importBooks, createGroup, toggleFavorite, moveToGroup, deleteBooks
        ) as T

        DetailViewModel::class.java -> DetailViewModel(
            getBook, observeGroups, toggleFavorite, moveToGroup, deleteBooks,
            updateProgress, repos.readerRepository
        ) as T

        NovelReaderViewModel::class.java -> NovelReaderViewModel(
            getBook, openNovel, repos.readerRepository, repos.progressRepository,
            repos.settingsRepository, session
        ) as T

        ComicReaderViewModel::class.java -> ComicReaderViewModel(
            getBook, openComic, repos.progressRepository, repos.settingsRepository, session
        ) as T

        ProfileViewModel::class.java -> ProfileViewModel(
            getStats, repos.statsRepository, observeSettings, updateSettings
        ) as T

        SettingsViewModel::class.java -> SettingsViewModel(
            observeSettings, updateSettings, repos.storageRepository
        ) as T

        else -> throw IllegalArgumentException("未知 ViewModel：$modelClass")
    }
}
