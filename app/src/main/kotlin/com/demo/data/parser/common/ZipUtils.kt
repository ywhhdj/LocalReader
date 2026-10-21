package com.demo.data.parser.common

import com.demo.core.common.util.Logger
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipFile

internal object ZipUtils {

    fun readEntryBytes(zip: ZipFile, path: String): ByteArray? =
        runCatching {
            zip.getInputStream(zip.getEntry(path) ?: return null).use { it.readBytes() }
        }.getOrNull()

    fun readEntryBytes(zip: ZipFile, entry: ZipEntry): ByteArray? =
        runCatching { zip.getInputStream(entry).use { it.readBytes() } }.getOrNull()

    fun readEntryBytes(zip: ZipFile, entry: ZipEntry, limit: Int): ByteArray? =
        runCatching {
            zip.getInputStream(entry).use { input ->
                val buffer = ByteArrayOutputStream(64 * 1024)
                val chunk = ByteArray(64 * 1024)
                var total = 0
                while (total < limit) {
                    val n = input.read(chunk, 0, minOf(chunk.size, limit - total))
                    if (n <= 0) break
                    buffer.write(chunk, 0, n)
                    total += n
                }
                buffer.toByteArray()
            }
        }.onFailure { Logger.w("读取条目失败：${entry.name} ${it.message}", "ZipUtils") }
            .getOrNull()
}