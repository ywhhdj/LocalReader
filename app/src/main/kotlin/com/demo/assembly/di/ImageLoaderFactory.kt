package com.demo.assembly.di

import android.content.Context
import android.graphics.Bitmap

import coil.ImageLoader
import coil.memory.MemoryCache

/**
 * 全局图片加载器：限制内存缓存为进程可用内存的 15%，统一 RGB_565，
 * 列表滚动时可暂停加载，降低 OOM 风险。
 */
object ImageLoaderFactory {

    fun create(context: Context): ImageLoader = ImageLoader.Builder(context)
        .bitmapConfig(Bitmap.Config.RGB_565)
        .memoryCache {
            MemoryCache.Builder(context)
                .maxSizePercent(0.15)
                .build()
        }
        .crossfade(true)
        .respectCacheHeaders(false)
        .build()
}
