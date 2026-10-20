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
     */
    @Synchronized
    fun trim() {
        val entries = dir.listFiles()?.toMutableList() ?: return
        var total = entries.sumOf { sizeOf(it) }
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
    }

    @Synchronized
    fun clear() {
        dir.listFiles()?.forEach { deleteOf(it) }
        accessMap.clear()
    }

    fun size(): Long = dir.listFiles()?.sumOf { sizeOf(it) } ?: 0L

    private fun sizeOf(f: File): Long =
        if (f.isDirectory) FileUtil.dirSize(f) else runCatching { f.length() }.getOrDefault(0L)

    private fun deleteOf(f: File): Boolean =
        runCatching { if (f.isDirectory) f.deleteRecursively() else f.delete() }.getOrDefault(false)
}
