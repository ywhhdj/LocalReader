package com.demo.data.repository

import com.demo.data.cache.CoverStore
import com.demo.data.cache.PageCache
import com.demo.domain.repository.StorageRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class StorageRepositoryImpl(
    private val coverStore: CoverStore,
    private val pageCache: PageCache
) : StorageRepository {

    override suspend fun cacheSizeBytes(): Long = withContext(Dispatchers.IO) {
        coverStore.size() + pageCache.size()
    }

    override suspend fun coverCacheBytes(): Long = withContext(Dispatchers.IO) { coverStore.size() }

    override suspend fun pageCacheBytes(): Long = withContext(Dispatchers.IO) { pageCache.size() }

    override suspend fun clearCovers() = withContext(Dispatchers.IO) { coverStore.clear() }

    override suspend fun clearPages() = withContext(Dispatchers.IO) { pageCache.clear() }

    override suspend fun clearAll() = withContext(Dispatchers.IO) {
        coverStore.clear()
        pageCache.clear()
    }
}
