package com.demo.data.cache

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

    /** 容量超限时淘汰最旧的一半多余文件 */
    fun trim() {
        val files = dir.listFiles()?.toMutableList() ?: return
        var total = files.sumOf { it.length() }
        if (files.size <= maxCount && total <= maxBytes) return

        files.sortBy { accessMap[it.name] ?: it.lastModified().toLong() * 1_000_000L }
        val targetCount = (maxCount * 0.8).toInt().coerceAtLeast(1)
        for (f in files) {
            if (files.size <= targetCount && total <= maxBytes * 0.8) break
            val len = f.length()
            if (f.delete()) {
                files.remove(f)
                accessMap.remove(f.name)
                total -= len
            }
        }
    }

    fun clear() {
        dir.listFiles()?.forEach { it.delete() }
        accessMap.clear()
    }

    fun size(): Long = dir.listFiles()?.sumOf { it.length() } ?: 0L
}
