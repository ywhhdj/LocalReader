package com.demo.assembly.di

import android.content.Context
import android.graphics.Bitmap

import coil.ImageLoader
import coil.disk.DiskCache
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
        .diskCache {
            DiskCache.Builder()
                .directory(java.io.File(context.cacheDir, "image_cache"))
                // 封面缩略图很小，磁盘缓存按可用空间的 2% 封顶，避免缓存无限增长
                .maxSizePercent(0.02)
                .build()
        }
        // 列表滚动时逐张淡入会持续触发重绘（快滑掉帧的元凶之一）：
        // 默认关闭，需要淡入的场景在单次请求里显式开启。
        .crossfade(false)
        .respectCacheHeaders(false)
        .build()
}
