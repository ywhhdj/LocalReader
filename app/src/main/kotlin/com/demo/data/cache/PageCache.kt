package com.demo.data.cache

import android.graphics.Bitmap

import com.demo.core.common.util.Constants
import com.demo.core.common.util.FileUtil
import com.demo.data.cache.DiskLruCache

import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap

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

    /** 记住每页实际落地的扩展名，避免命中缓存时逐个后缀去试 */
    private val extByKey = ConcurrentHashMap<String, String>()

    private fun bookDir(bookId: Long): File = File(cache.dir(), bookId.toString())

    private fun slot(bookId: Long, index: Int): String = "$bookId/$index"

    fun pageKey(bookId: Long, index: Int): String = "${bookId}/${FileUtil.md5(index.toString())}.webp"

    fun pageKey(bookId: Long, index: Int, ext: String): String =
        "${bookId}/${FileUtil.md5(index.toString())}.${ext.lowercase()}"

    fun cached(bookId: Long, index: Int): String? {
        val remembered = extByKey[slot(bookId, index)]
        if (remembered != null) {
            val key = pageKey(bookId, index, remembered)
            if (cache.exists(key)) {
                cache.touch(key)
                return cache.file(key).absolutePath
            }
        }
        for (ext in CANDIDATE_EXTS) {
            val key = pageKey(bookId, index, ext)
            if (cache.exists(key)) {
                extByKey[slot(bookId, index)] = ext
                cache.touch(key)
                return cache.file(key).absolutePath
            }
        }
        return null
    }

    fun put(bookId: Long, index: Int, bitmap: Bitmap): String? {
        val key = pageKey(bookId, index)
        cache.file(key).parentFile?.mkdirs()
        return ImageTools.compressToFile(bitmap, cache.file(key), 82)?.also {
            extByKey[slot(bookId, index)] = "webp"
            cache.touch(key)
            cache.trim()
        }
    }

    /**
     * 先解码再重编码为 WebP。
     * 只在必须降采样时使用（超大图 / 原图格式无法直接交给加载器时）——
     * 解码 + WebP 压缩都很贵，漫画翻页时是主要卡顿来源。
     */
    fun putBytes(bookId: Long, index: Int, bytes: ByteArray, maxEdge: Int = 2048): String? {
        cached(bookId, index)?.let { return it }
        val bitmap = ImageTools.decodeSampled(bytes, maxEdge) ?: return null
        val result = put(bookId, index, bitmap)
        if (!bitmap.isRecycled) bitmap.recycle()
        return result
    }

    /**
     * 原样落盘：压缩包里的图片本来就是 jpg/png/webp，直接写文件即可，
     * 省掉一次全尺寸解码 + 一次 WebP 重编码（页面显示前的采样交给图片加载器按控件尺寸做）。
     *
     * @return 缓存文件路径；写入失败返回 null（调用方回退到 [putBytes]）
     */
    fun putRaw(bookId: Long, index: Int, bytes: ByteArray, ext: String): String? {
        if (bytes.isEmpty()) return null
        val normalized = ext.lowercase().ifBlank { "jpg" }
        val key = pageKey(bookId, index, normalized)
        return runCatching {
            val file = cache.file(key)
            file.parentFile?.mkdirs()
            FileOutputStream(file).use { it.write(bytes) }
            extByKey[slot(bookId, index)] = normalized
            cache.touch(key)
            cache.trim()
            file.absolutePath
        }.getOrNull()
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

    fun clear() = cache.clear().also { extByKey.clear() }

    fun size(): Long = cache.size()

    companion object {
        /** 命中缓存时的后缀尝试顺序（webp 为压缩后写入的默认格式） */
        val CANDIDATE_EXTS = listOf("webp", "jpg", "jpeg", "png")

        /** 可直接原样落盘的格式（无需转码） */
        private val RAW_EXTS = setOf("jpg", "jpeg", "png", "webp")
        /** 原样落盘的大小上限：更大的图仍走"解码 + 重编码"，避免缓存被几张巨图占满 */
        private const val RAW_MAX_BYTES = 6 * 1024 * 1024

        /** 该条目是否可以跳过转码直接落盘 */
        fun canStoreRaw(ext: String, sizeBytes: Int): Boolean =
            ext.lowercase() in RAW_EXTS && sizeBytes in 1..RAW_MAX_BYTES
    }
}
