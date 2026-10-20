package com.demo.core.common.util

import java.io.File
import java.math.BigInteger
import java.security.MessageDigest
import java.util.Locale

object FileUtil {

    fun extension(name: String): String {
        val i = name.lastIndexOf('.')
        return if (i < 0 || i == name.lastIndex) "" else name.substring(i + 1).lowercase(Locale.getDefault())
    }

    fun nameWithoutExtension(name: String): String {
        val i = name.lastIndexOf('.')
        return if (i <= 0) name else name.substring(0, i)
    }

    fun md5(input: String): String = try {
        val md = MessageDigest.getInstance("MD5")
        BigInteger(1, md.digest(input.toByteArray())).toString(16).padStart(32, '0')
    } catch (e: Exception) {
        input.hashCode().toString(16)
    }

    fun safeFileName(name: String): String =
        name.replace(Regex("[/\\\\:*?\"<>|]"), "_").take(80)

    fun isHidden(file: File): Boolean = file.name.startsWith(".")

    /** 是否包含 .nomedia 标记（用于跳过整个目录） */
    fun hasNoMedia(dir: File): Boolean = File(dir, ".nomedia").exists()

    fun humanTitle(fileName: String): String = nameWithoutExtension(fileName)
        .replace('_', ' ')
        .replace(Regex("\\s+"), " ")
        .trim()

    /** 删除目录及其内容 */
    fun deleteRecursively(file: File?): Boolean {
        if (file == null) return false
        return try {
            if (file.isDirectory) file.listFiles()?.forEach { deleteRecursively(it) }
            file.deleteRecursively()
        } catch (e: Exception) {
            false
        }
    }

    fun dirSize(file: File?): Long {
        if (file == null || !file.exists()) return 0L
        if (file.isFile) return file.length()
        var sum = 0L
        file.listFiles()?.forEach { sum += dirSize(it) }
        return sum
    }
}
