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
    private val maxBytes: Long = Long.MAX_VALUE,
    /**
     * 条目是否递归统计。
     * 漫画页缓存的 key 形如 "bookId/xxx.webp"（按书分目录），
     * 非递归时顶层只看到"书目录"：既永远数不到条目上限，淘汰时又会整本书一起删掉。
     */
    private val recursive: Boolean = false
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
        val entries = listEntries()
        var total = entries.sumOf { sizeOf(it) }
        sizeCache = total
        sizeAt = now
        if (entries.size <= maxCount && total <= maxBytes) return

        val targetCount = (maxCount * 0.8).toInt().coerceAtLeast(1)
        // 用与 touch 一致的相对路径 key 排序，否则永远回退到 lastModified，
        // LRU 名存实亡（访问过的页面也会被当成最旧的删掉）
        val sorted = entries.sortedBy { accessMap[relativeKey(it)] ?: it.lastModified().toLong() * 1_000_000L }
        var remaining = entries.size
        for (f in sorted) {
            if (remaining <= targetCount && total <= maxBytes * 0.8) break
            val len = sizeOf(f)
            if (deleteOf(f)) {
                accessMap.remove(relativeKey(f))
                total -= len
                remaining--
            }
        }
        sizeCache = total
    }

    @Synchronized
    fun clear() {
        listEntries().forEach { deleteOf(it) }
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
            val v = listEntries().sumOf { sizeOf(it) }
            sizeCache = v
            sizeAt = System.currentTimeMillis()
            return v
        }
        val cached = sizeCache
        if (cached >= 0 && System.currentTimeMillis() - sizeAt < SIZE_TTL_MS) return cached
        return size(force = true)
    }

    /**
     * 参与统计/淘汰的条目列表。
     * [recursive] = true 时按实际缓存文件为单位（漫画页：bookId/xxx.webp），
     * 否则按顶层条目（封面：xxx.webp）。
     */
    private fun listEntries(): MutableList<File> {
        val top = dir.listFiles() ?: return mutableListOf()
        if (!recursive) return top.toMutableList()
        val out = ArrayList<File>(top.size * 8)
        for (f in top) {
            if (f.isDirectory) f.listFiles()?.forEach { out.add(it) }
            else out.add(f)
        }
        return out
    }

    /** 与 [touch] 使用的 key 对齐：相对缓存根目录的路径 */
    private fun relativeKey(f: File): String =
        f.absolutePath.removePrefix(dir.absolutePath).trimStart('/')

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
