package com.demo.data.cover

import android.graphics.Bitmap

import java.io.File
import java.io.InputStream

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.data.cache.ImageTools
import com.demo.data.cache.DiskLruCache

/**
 * 封面存储：统一缩放至 ≤450px 的 WebP，按 filePath 哈希命名，LRU 上限 300。
 */
class CoverStore(filesDir: File) {

    private val cache = DiskLruCache(
        dir = File(filesDir, Constants.COVER_DIR),
        maxCount = Constants.COVER_CACHE_MAX_COUNT,
        maxBytes = 60L * 1024 * 1024
    )

    fun keyFor(path: String): String = FileUtil.md5(path) + ".webp"

    fun existingCover(path: String): String? {
        val key = keyFor(path)
        return if (cache.exists(key)) {
            cache.touch(key)
            cache.file(key).absolutePath
        } else null
    }

    /** 从字节数组生成封面 */
    fun save(bytes: ByteArray, sourceKey: String): String? {
        val bitmap = ImageTools.decodeSampled(bytes, Constants.COVER_MAX_EDGE) ?: return null
        val scaled = ImageTools.scaleIfNeeded(bitmap, Constants.COVER_MAX_EDGE)
        return write(scaled, sourceKey, recycled = bitmap !== scaled)
    }

    fun save(stream: InputStream, sourceKey: String): String? =
        save(stream.readBytes(), sourceKey)

    fun save(bitmap: Bitmap, sourceKey: String): String? {
        val scaled = ImageTools.scaleIfNeeded(bitmap, Constants.COVER_MAX_EDGE)
        return write(scaled, sourceKey, recycled = bitmap !== scaled)
    }

    private fun write(bitmap: Bitmap, sourceKey: String, recycled: Boolean): String? {
        val key = keyFor(sourceKey)
        val path = ImageTools.compressToFile(bitmap, cache.file(key), 80)
        if (recycled && !bitmap.isRecycled) bitmap.recycle()
        cache.touch(key)
        cache.trim()
        return path
    }

    fun delete(sourceKey: String) {
        val f = cache.file(keyFor(sourceKey))
        if (f.exists()) f.delete()
        cache.invalidateSize()
    }

    fun clear() = cache.clear()

    fun size(): Long = cache.size()
}
