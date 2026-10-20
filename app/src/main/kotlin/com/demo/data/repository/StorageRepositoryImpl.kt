package com.demo.data.repository

import com.demo.data.cover.CoverStore
import com.demo.data.cache.PageCache
import com.demo.data.scanner.SafScanner
import com.demo.domain.repository.StorageRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class StorageRepositoryImpl(
    private val coverStore: CoverStore,
    private val pageCache: PageCache,
    private val safScanner: SafScanner
) : StorageRepository {

    override suspend fun cacheSizeBytes(): Long = withContext(Dispatchers.IO) {
        coverStore.size() + pageCache.size() + safScanner.cacheSize()
    }

    override suspend fun coverCacheBytes(): Long = withContext(Dispatchers.IO) { coverStore.size() }

    override suspend fun pageCacheBytes(): Long = withContext(Dispatchers.IO) { pageCache.size() }

    override suspend fun safCacheBytes(): Long = withContext(Dispatchers.IO) { safScanner.cacheSize() }

    override suspend fun clearCovers() { 
        withContext(Dispatchers.IO) { coverStore.clear() }
    }

    override suspend fun clearPages() {
        withContext(Dispatchers.IO) { pageCache.clear() }
    }

    override suspend fun clearSafCache() {
        withContext(Dispatchers.IO) { safScanner.clearCache() }
    }

    override suspend fun clearAll() {
        withContext(Dispatchers.IO) {
            coverStore.clear()
            pageCache.clear()
            safScanner.clearCache()
        }
    }
}
