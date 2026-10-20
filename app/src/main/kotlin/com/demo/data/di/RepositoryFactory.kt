package com.demo.data.di

import android.content.Context
import com.demo.core.common.util.Constants
import com.demo.core.database.AppDatabase
import com.demo.core.database.DatabaseProvider
import com.demo.data.cache.CoverStore
import com.demo.data.cache.PageCache
import com.demo.data.datastore.SettingsRepositoryImpl
import com.demo.data.parser.ParserFactory
import com.demo.data.parser.ParserFactoryImpl
import com.demo.data.repository.BookRepositoryImpl
import com.demo.data.repository.GroupRepositoryImpl
import com.demo.data.repository.ProgressRepositoryImpl
import com.demo.data.repository.ReaderRepositoryImpl
import com.demo.data.repository.StatsRepositoryImpl
import com.demo.data.repository.StorageRepositoryImpl
import com.demo.data.scanner.FileScanner
import com.demo.domain.repository.BookRepository
import com.demo.domain.repository.GroupRepository
import com.demo.domain.repository.ProgressRepository
import com.demo.domain.repository.ReaderRepository
import com.demo.domain.repository.ScannerRepository
import com.demo.domain.repository.SettingsRepository
import com.demo.domain.repository.StatsRepository
import com.demo.domain.repository.StorageRepository
import java.io.File

/** 数据层全部依赖（供 app 层容器装配） */
data class Repositories(
    val bookRepository: BookRepository,
    val groupRepository: GroupRepository,
    val progressRepository: ProgressRepository,
    val statsRepository: StatsRepository,
    val settingsRepository: SettingsRepository,
    val storageRepository: StorageRepository,
    val scannerRepository: ScannerRepository,
    val readerRepository: ReaderRepository,
    val coverStore: CoverStore,
    val pageCache: PageCache,
    val bookCacheDir: File,
    val database: AppDatabase
)

object RepositoryFactory {

    fun create(context: Context): Repositories {
        val appContext = context.applicationContext
        val database = DatabaseProvider.get(appContext)
        val coverStore = CoverStore(appContext.filesDir)
        val pageCache = PageCache(appContext.filesDir)
        val bookCacheDir = File(appContext.filesDir, Constants.BOOK_CACHE_DIR).apply { mkdirs() }
        val parserFactory: ParserFactory = ParserFactoryImpl(coverStore, pageCache, bookCacheDir)

        val bookRepository = BookRepositoryImpl(database.bookDao(), coverStore)
        return Repositories(
            bookRepository = bookRepository,
            groupRepository = GroupRepositoryImpl(database.groupDao(), database.bookDao()),
            progressRepository = ProgressRepositoryImpl(database.progressDao(), database.bookDao()),
            statsRepository = StatsRepositoryImpl(database.sessionDao(), database.bookDao()),
            settingsRepository = SettingsRepositoryImpl(appContext),
            storageRepository = StorageRepositoryImpl(coverStore, pageCache),
            scannerRepository = FileScanner(parserFactory, database.bookDao()),
            readerRepository = ReaderRepositoryImpl(parserFactory),
            coverStore = coverStore,
            pageCache = pageCache,
            bookCacheDir = bookCacheDir,
            database = database
        )
    }
}
