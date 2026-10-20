package com.demo.domain.repository

interface StorageRepository {
    suspend fun cacheSizeBytes(): Long
    suspend fun coverCacheBytes(): Long
    suspend fun pageCacheBytes(): Long
    suspend fun clearCovers()
    suspend fun clearPages()
    suspend fun clearAll()
}
