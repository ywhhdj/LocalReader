package com.demo.data.cache

import android.graphics.Bitmap

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.data.cache.DiskLruCache

import java.io.File

/**
 * 漫画页缓存：zip 解压结果 / PDF 渲染结果落地为文件，供图片加载器按尺寸二次采样。
 * 使用 LRU 控制容量，阅读器窗口外的页面由调用方决定是否清理。
 */
class PageCache(filesDir: File) {

    // 页缓存按 "bookId/xxx.webp" 存放（便于按书清理），因此必须递归统计：
    // 否则顶层只看到书目录，条目上限形同虚设，且淘汰时会整本书一起删掉。
    private val cache = DiskLruCache(
        dir = File(filesDir, Constants.PAGE_CACHE_DIR),
        maxCount = Constants.PAGE_CACHE_MAX_COUNT,
        maxBytes = 256L * 1024 * 1024,
        recursive = true
    )

    private fun bookDir(bookId: Long): File = File(cache.dir(), bookId.toString())

    fun pageKey(bookId: Long, index: Int): String = "${bookId}/${FileUtil.md5(index.toString())}.webp"

    fun cached(bookId: Long, index: Int): String? {
        val key = pageKey(bookId, index)
        return if (cache.exists(key)) {
            cache.touch(key)
            cache.file(key).absolutePath
        } else null
    }

    fun put(bookId: Long, index: Int, bitmap: Bitmap): String? {
        val key = pageKey(bookId, index)
        cache.file(key).parentFile?.mkdirs()
        return ImageTools.compressToFile(bitmap, cache.file(key), 82)?.also {
            cache.touch(key)
            cache.trim()
        }
    }

    fun putBytes(bookId: Long, index: Int, bytes: ByteArray, maxEdge: Int = 2048): String? {
        val cached = cached(bookId, index)
        if (cached != null) return cached
        val bitmap = ImageTools.decodeSampled(bytes, maxEdge) ?: return null
        val result = put(bookId, index, bitmap)
        if (!bitmap.isRecycled) bitmap.recycle()
        return result
    }

    /**
     * 删除指定漫画的缓存
     */
    fun clear(bookId: Long) {
        val bookDir = bookDir(bookId)
        if (bookDir.exists()) {
            FileUtil.deleteRecursively(bookDir)
        }
        cache.invalidateSize()
    }

    fun trim() = cache.trim()

    fun clear() = cache.clear()

    fun size(): Long = cache.size()
}
