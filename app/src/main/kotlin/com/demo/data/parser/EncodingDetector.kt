package com.demo.data.parser

import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.CharBuffer
import java.nio.charset.Charset
import java.nio.charset.CharsetDecoder
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

/**
 * 文本编码探测：BOM → UTF-8 严格校验 → 多候选打分（GBK/Big5/EUC-KR/Shift_JIS）。
 * 中文场景兜底 GBK，避免整本乱码。
 */
object EncodingDetector {

    private val CANDIDATES = listOf("GBK", "BIG5", "EUC-KR", "Shift_JIS", "ISO-8859-1")

    fun detect(file: File, sample: Int = 96 * 1024): Charset {
        val bytes = readSample(file, sample)
        if (bytes.isEmpty()) return StandardCharsets.UTF_8

        detectByBom(bytes)?.let { return it }
        if (isStrictUtf8(bytes)) return StandardCharsets.UTF_8

        var best: Charset = charsetOrNull("GBK") ?: StandardCharsets.UTF_8
        var bestScore = Int.MIN_VALUE
        for (name in CANDIDATES) {
            val cs = charsetOrNull(name) ?: continue
            val score = score(bytes, cs)
            if (score > bestScore) {
                bestScore = score
                best = cs
            }
        }
        return best
    }

    private fun readSample(file: File, sample: Int): ByteArray = try {
        FileInputStream(file).use { input ->
            val size = minOf(file.length(), sample.toLong()).toInt()
            val buf = ByteArray(size)
            val read = input.read(buf)
            if (read <= 0) ByteArray(0) else buf.copyOf(read)
        }
    } catch (e: Exception) {
        ByteArray(0)
    }

    private fun detectByBom(bytes: ByteArray): Charset? = when {
        bytes.size >= 3 && bytes[0] == 0xEF.toByte() && bytes[1] == 0xBB.toByte() && bytes[2] == 0xBF.toByte() ->
            StandardCharsets.UTF_8
        bytes.size >= 2 && bytes[0] == 0xFF.toByte() && bytes[1] == 0xFE.toByte() ->
            StandardCharsets.UTF_16LE
        bytes.size >= 2 && bytes[0] == 0xFE.toByte() && bytes[1] == 0xFF.toByte() ->
            StandardCharsets.UTF_16BE
        else -> null
    }

    private fun isStrictUtf8(bytes: ByteArray): Boolean = try {
        val decoder = StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        decoder.decode(ByteBuffer.wrap(bytes))
        true
    } catch (e: Exception) {
        false
    }

    /** 打分：中文字符 + 常见标点为正向，替换字符为大幅负向 */
    private fun score(bytes: ByteArray, charset: Charset): Int = try {
        val decoder: CharsetDecoder = charset.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        val cb: CharBuffer = decoder.decode(ByteBuffer.wrap(bytes))
        var score = 0
        var replacement = 0
        for (i in 0 until minOf(cb.length, 8192)) {
            val c = cb[i]
            when {
                c == '�' -> replacement++
                c in '一'..'龥' -> score += 2
                c == '，' || c == '。' || c == '、' || c == '；' || c == '：' ||
                    c == '？' || c == '！' || c == '“' || c == '”' -> score += 3
                c == ' ' || c == '\n' || c == '\r' -> score += 1
            }
        }
        score - replacement * 20
    } catch (e: Exception) {
        Int.MIN_VALUE / 2
    }

    private fun charsetOrNull(name: String): Charset? = try {
        Charset.forName(name)
    } catch (e: Exception) {
        null
    }
}
