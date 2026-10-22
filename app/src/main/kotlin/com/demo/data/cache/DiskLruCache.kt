package com.demo.data.cache

import com.demo.core.common.util.FileUtil
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * 极简磁盘 LRU：按最后访问时间淘汰最旧文件。
 * 用于封面缓存与漫画页缓存，避免目录无限增长。
 */
class DiskLruCache(
    private val dir: File,
    private val maxCount: Int,
    private val maxBytes: Long = Long.MAX_VALUE
) {

    private val accessMap = ConcurrentHashMap<String, Long>()

    /** 容量统计结果缓存：目录递归统计很贵，不能每次写入都算一遍 */
    @Volatile
    private var sizeCache: Long = -1L
    @Volatile
    private var sizeAt: Long = 0L
    @Volatile
    private var lastTrimAt: Long = 0L

    init { dir.mkdirs() }

    fun dir(): File = dir

    fun touch(key: String) { accessMap[key] = System.nanoTime() }

    fun file(key: String): File = File(dir, key)

    fun exists(key: String): Boolean {
        val f = file(key)
        return f.exists() && f.length() > 0
    }

    /**
     * 容量超限时淘汰最旧的条目。
     *
     * 扫描整个缓存目录（还要递归统计子目录）代价很高：漫画每渲染一页、扫描每生成一个封面
     * 都会触发一次写入，因此这里做两层优化：
     * 1. 节流：距上次整理不足 [TRIM_INTERVAL_MS] 直接返回（[force] = true 强制整理）；
     * 2. 容量：不直接 listFiles 全量统计，优先用缓存值快速判断是否超限。
     */
    @Synchronized
    fun trim(force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (!force && now - lastTrimAt < TRIM_INTERVAL_MS) return
        lastTrimAt = now
        val entries = dir.listFiles()?.toMutableList() ?: return
        var total = entries.sumOf { sizeOf(it) }
        sizeCache = total
        sizeAt = now
        if (entries.size <= maxCount && total <= maxBytes) return

        val targetCount = (maxCount * 0.8).toInt().coerceAtLeast(1)
        val sorted = entries.sortedBy { accessMap[it.name] ?: it.lastModified().toLong() * 1_000_000L }
        var remaining = entries.size
        for (f in sorted) {
            if (remaining <= targetCount && total <= maxBytes * 0.8) break
            val len = sizeOf(f)
            if (deleteOf(f)) {
                accessMap.remove(f.name)
                total -= len
                remaining--
            }
        }
        sizeCache = total
    }

    @Synchronized
    fun clear() {
        dir.listFiles()?.forEach { deleteOf(it) }
        accessMap.clear()
        sizeCache = 0L
        sizeAt = System.currentTimeMillis()
    }

    /** 让下一次 [size] 重新统计（外部直接改了目录时使用） */
    fun invalidateSize() { sizeCache = -1L }

    /**
     * 缓存目录当前占用。结果缓存 [SIZE_TTL_MS]，避免设置页 / 删除书籍时反复递归统计。
     */
    fun size(force: Boolean = false): Long {
        if (force) {
            val v = dir.listFiles()?.sumOf { sizeOf(it) } ?: 0L
            sizeCache = v
            sizeAt = System.currentTimeMillis()
            return v
        }
        val cached = sizeCache
        if (cached >= 0 && System.currentTimeMillis() - sizeAt < SIZE_TTL_MS) return cached
        return size(force = true)
    }

    private companion object {
        /** 整理节流间隔 */
        const val TRIM_INTERVAL_MS = 5_000L
        /** 容量统计缓存有效期 */
        const val SIZE_TTL_MS = 10_000L
    }

    private fun sizeOf(f: File): Long =
        if (f.isDirectory) FileUtil.dirSize(f) else runCatching { f.length() }.getOrDefault(0L)

    private fun deleteOf(f: File): Boolean =
        runCatching { if (f.isDirectory) f.deleteRecursively() else f.delete() }.getOrDefault(false)
}
