package com.demo.data.cache

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

import kotlin.math.max
import kotlin.math.min

import com.demo.core.common.util.Constants

/** 图片解码与压缩：统一采样策略，控制内存峰值 */
object ImageTools {

    fun decodeBounds(bytes: ByteArray): Pair<Int, Int> {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
        return opts.outWidth to opts.outHeight
    }

    fun decodeSampled(bytes: ByteArray, maxEdge: Int): Bitmap? {
        val (w, h) = decodeBounds(bytes)
        if (w <= 0 || h <= 0) return null
        val sample = calculateInSampleSize(w, h, maxEdge)
        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.RGB_565
        }
        return try {
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
        } catch (e: Throwable) {
            Log.w("ImageTools", "decode failed", e)
            null
        }
    }

    /** 按目标长边计算 2 的幂采样率 */
    fun calculateInSampleSize(width: Int, height: Int, maxEdge: Int): Int {
        var sample = 1
        val longEdge = max(width, height)
        while (longEdge / (sample * 2) >= maxEdge) sample *= 2
        return min(sample, 8)
    }

    fun scaleIfNeeded(bitmap: Bitmap, maxEdge: Int): Bitmap {
        val longEdge = max(bitmap.width, bitmap.height)
        if (longEdge <= maxEdge) return bitmap
        val ratio = maxEdge.toFloat() / longEdge
        val targetW = (bitmap.width * ratio).toInt().coerceAtLeast(1)
        val targetH = (bitmap.height * ratio).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, targetW, targetH, true)
    }

    fun compressToFile(bitmap: Bitmap, file: File, quality: Int = 80): String? = try {
        file.parentFile?.mkdirs()
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.WEBP, quality, out)
        }
        file.absolutePath
    } catch (e: Exception) {
        Log.w("ImageTools", "compress failed", e)
        null
    }

    fun toBytes(bitmap: Bitmap): ByteArray = ByteArrayOutputStream().use {
        bitmap.compress(Bitmap.CompressFormat.WEBP, 80, it)
        it.toByteArray()
    }

    fun isImageExtension(ext: String): Boolean = Constants.IMAGE_EXTENSIONS.contains(ext.lowercase())
}
