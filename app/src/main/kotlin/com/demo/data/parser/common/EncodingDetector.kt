package com.demo.data.parser.common

import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.CharBuffer
import java.nio.charset.Charset
import java.nio.charset.CharsetDecoder
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

/**
 * 文本编码探测：BOM → 严格 UTF-8（容忍采样截断）→ 多候选打分。
 * 中文场景兜底 GB18030（GBK 超集），避免"UTF-8 被当成 GBK"的整本乱码。
 */
object EncodingDetector {

    /** GB18030 放首位：它是全字节覆盖且兼容 GBK，普通 GBK 文本打分不会低于 GBK */
    private val CANDIDATES = listOf("GB18030", "GBK", "BIG5", "EUC-KR", "Shift_JIS")
    /** 尾部允许的最大不完整多字节字符数（UTF-8 最长 4 字节，采样截断最多残留 3） */
    private const val MAX_TRAILING_BAD = 3
    

    fun detect(file: File, sample: Int = 96 * 1024): Charset {
        var bytes = readAt(file, 0L, sample)
        if (bytes.isEmpty()) return StandardCharsets.UTF_8

        detectByBom(bytes)?.let { return it }

        // 头段几乎是 ASCII（版权/目录/空行）时，补采中段，避免"前段英文后面中文"误判
        if (isMostlyAscii(bytes) && file.length() > sample * 2) {
            val mid = readAt(file, file.length() / 2, sample / 2)
            if (mid.isNotEmpty()) bytes = bytes + mid
        }

        // 严格 UTF-8 校验：容忍采样截断的多字节尾部
        if (isStrictUtf8(bytes)) return StandardCharsets.UTF_8

        // 非 UTF-8 → 候选打分
        var best: Charset = charsetOrNull("GB18030") ?: StandardCharsets.UTF_8
        var bestScore = Int.MIN_VALUE
        for (name in CANDIDATES) {
            val cs = charsetOrNull(name) ?: continue
            val s = score(bytes, cs)
            if (s > bestScore) {
                bestScore = s
                best = cs
            }
        }
        return best
    }

    /** 按偏移读取，循环读满 */
    private fun readAt(file: File, offset: Long, size: Int): ByteArray = try {
        RandomAccessFile(file, "r").use { raf ->
            val len = minOf(file.length() - offset, size.toLong()).coerceAtLeast(0L).toInt()
            if (len <= 0) return ByteArray(0)
            raf.seek(offset)
            val buf = ByteArray(len)
            var read = 0
            while (read < len) {
                val n = raf.read(buf, read, len - read)
                if (n <= 0) break
                read += n
            }
            if (read <= 0) ByteArray(0) else buf.copyOf(read)
        }
    } catch (e: Exception) {
        ByteArray(0)
    }

    private fun isMostlyAscii(bytes: ByteArray): Boolean {
        if (bytes.isEmpty()) return true
        var nonAscii = 0
        for (b in bytes) if ((b.toInt() and 0xFF) > 0x7F) nonAscii++
        return nonAscii.toDouble() / bytes.size < 0.01
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

    /**
     * 严格 UTF-8：允许末尾最多 3 字节的"不完整多字节序列"。
     * 采样是按字节截断的，很可能正好切在一个 3 字节汉字的中间。
     * 若不放宽，UTF-8 文件会被误判为非 UTF-8，然后被当成 GBK 解码 → 整本乱码。
     */
    private fun isStrictUtf8(bytes: ByteArray): Boolean {
        if (bytes.isEmpty()) return true
        // 只解码一次（旧实现最多解码 4 次、每次新建 decoder，每个 TXT 入库前都要跑一遍）。
        // 用 REPLACE 统计替换符 U+FFFD 的数量与位置：
        //  0 个 → 合法 UTF-8；
        //  仅出现在输出末尾 ≤3 个 → 采样正好切在多字节汉字中间，仍按 UTF-8 处理
        //    （不放宽的话 UTF-8 会被误判成 GBK，整本乱码）。
        val decoder = StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPLACE)
            .onUnmappableCharacter(CodingErrorAction.REPLACE)
        val cb = runCatching { decoder.decode(ByteBuffer.wrap(bytes)) }
            .getOrNull() ?: return false
        var count = 0
        var firstBadFromEnd = -1
        for (i in cb.length - 1 downTo 0) {
            if (cb[i] == '�') {
                count++
                if (firstBadFromEnd < 0) firstBadFromEnd = i
            }
        }
        if (count == 0) return true
        return count <= MAX_TRAILING_BAD && firstBadFromEnd >= cb.length - MAX_TRAILING_BAD
    }

    /** 打分：CJK/中文标点正向，替换符/控制符负向；无 CJK 的候选重罚 */
    private fun score(bytes: ByteArray, charset: Charset): Int = try {
        val decoder: CharsetDecoder = charset.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        val cb: CharBuffer = decoder.decode(ByteBuffer.wrap(bytes))
        var score = 0
        var replacement = 0
        var cjk = 0
        for (i in 0 until minOf(cb.length, 8192)) {
            val c = cb[i]
            when {
                c == '\uFFFD' -> replacement++
                c in '\u4E00'..'\u9FFF' -> { score += 2; cjk++ }
                c in '\u3040'..'\u30FF' -> { score += 1; cjk++ }  // 日文假名
                c in '\uAC00'..'\uD7AF' -> { score += 1; cjk++ }  // 韩文
                c == '，' || c == '。' || c == '、' || c == '；' || c == '：' ||
                    c == '？' || c == '！' || c == '“' || c == '”' ||
                    c == '《' || c == '》' || c == '（' || c == '）' -> score += 3
                c == ' ' || c == '\n' || c == '\r' || c == '\t' -> score += 1
                c.code < 0x20 -> score -= 5  // 控制字符
            }
        }
        // 中文小说解码后应该出现 CJK；一个 CJK 都没有的候选（如把中文误判成 ISO-8859-1）重罚
        if (cjk == 0 && bytes.size > 256) score -= 200
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