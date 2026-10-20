package com.demo.domain.repository

interface StorageRepository {
    suspend fun cacheSizeBytes(): Long
    suspend fun coverCacheBytes(): Long
    suspend fun pageCacheBytes(): Long
    /** SAF 物化缓存（Android 11+ 无所有文件权限时生成） */
    suspend fun safCacheBytes(): Long
    suspend fun clearCovers()
    suspend fun clearPages()
    suspend fun clearSafCache()
    suspend fun clearAll()
}
