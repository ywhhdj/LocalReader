package com.demo.data.cover

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Shader

import com.demo.core.common.util.Constants

import kotlin.math.abs

/**
 * 文字占位封面：EPUB/TXT 无内嵌封面时生成渐变卡片（书名首字 + 副标题），
 * 避免书架出现空洞，且不依赖任何第三方库。
 */
class TextCoverFactory {

    private val palette = listOf(
        0xFF4F6BFF.toInt() to 0xFF7A5CFF.toInt(),
        0xFF2FA98C.toInt() to 0xFF1F7A6B.toInt(),
        0xFFE2734B.toInt() to 0xFFB8433A.toInt(),
        0xFF5C6BC0.toInt() to 0xFF3949AB.toInt(),
        0xFF8E7CFF.toInt() to 0xFF5B45D6.toInt(),
        0xFF3FA7A0.toInt() to 0xFF225B60.toInt(),
        0xFFD86A8A.toInt() to 0xFF8E3B5C.toInt(),
        0xFF6D8B3F.toInt() to 0xFF3E5622.toInt()
    )

    fun create(title: String, subtitle: String = ""): Bitmap {
        val w = 300
        val h = 450
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val seed = abs(title.hashCode())
        val (startColor, endColor) = palette[seed % palette.size]

        val bg = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f, 0f, w.toFloat(), h.toFloat(),
                startColor, endColor, Shader.TileMode.CLAMP
            )
        }
        canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), bg)

        // 顶部柔光
        val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f, 0f, 0f, h * 0.6f,
                0x55FFFFFF, 0x00000000, Shader.TileMode.CLAMP
            )
        }
        canvas.drawRect(0f, 0f, w.toFloat(), h * 0.6f, glow)

        val initial = firstChar(title)
        val bigText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            textSize = 150f
            textAlign = Paint.Align.CENTER
            alpha = 235
        }
        val bounds = Rect()
        bigText.getTextBounds(initial, 0, initial.length, bounds)
        canvas.drawText(initial, w / 2f, h / 2f - bounds.top / 2f + 60f, bigText)

        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            textSize = 26f
            textAlign = Paint.Align.CENTER
            alpha = 220
        }
        canvas.drawText(title.take(8), w / 2f, h - 92f, label)
        if (subtitle.isNotBlank()) {
            val sub = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xFFFFFFFF.toInt()
                textSize = 18f
                textAlign = Paint.Align.CENTER
                alpha = 170
            }
            canvas.drawText(subtitle.take(14), w / 2f, h - 58f, sub)
        }
        return bitmap
    }

    private fun firstChar(title: String): String {
        val cleaned = title.trim()
        if (cleaned.isEmpty()) return "书"
        val c = cleaned.first()
        return if (c.isLetterOrDigit()) c.uppercaseChar().toString() else c.toString()
    }

    companion object {
        val WIDTH = 300
        val HEIGHT = Constants.COVER_MAX_EDGE
    }
}
