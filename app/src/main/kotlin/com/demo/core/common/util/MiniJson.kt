package com.demo.core.common.util

/**
 * 极简 JSON 读写（零第三方依赖）。
 * 仅用于：WebDAV 备份快照、在线书源规则配置这类小体量数据。
 */
sealed interface Json {

    data object Null : Json
    data class Bool(val value: Boolean) : Json
    data class Num(val value: Double) : Json
    data class Str(val value: String) : Json
    data class Arr(val items: List<Json>) : Json
    data class Obj(val fields: Map<String, Json>) : Json

    // ---------- 便捷读取 ----------
    fun obj(key: String): Json.Obj? = (this as? Obj)?.fields?.get(key) as? Obj
    fun arr(key: String): Json.Arr? = (this as? Obj)?.fields?.get(key) as? Arr
    fun str(key: String): String? = ((this as? Obj)?.fields?.get(key) as? Str)?.value
    fun str(key: String, fallback: String): String = str(key) ?: fallback
    fun num(key: String): Double? = ((this as? Obj)?.fields?.get(key) as? Num)?.value
    fun bool(key: String, fallback: Boolean = false): Boolean =
        ((this as? Obj)?.fields?.get(key) as? Bool)?.value ?: fallback
    fun any(key: String): Json? = (this as? Obj)?.fields?.get(key)

    fun has(key: String):Boolean = (this as? Obj)?.fields?.containsKey(key) ?: false
}

object MiniJson {

    /** 最大嵌套深度：超过即抛错，避免深度嵌套把解析栈打爆 */
    private const val MAX_DEPTH = 64

    fun parse(text: String): Json {
        val src = text.trim()
        if (src.isEmpty()) return Json.Null
        val parser = Parser(src)
        val value = parser.parseValue()
        return value
    }

    fun parseOrNull(text: String?): Json? = runCatching { parse(text ?: return null) }.getOrNull()

    fun stringify(value: Json, pretty: Boolean = false): String {
        val sb = StringBuilder()
        write(value, sb, pretty, 0)
        return sb.toString()
    }

    // ---------- 构建 ----------
    fun objOf(vararg pairs: Pair<String, Json>): Json.Obj = Json.Obj(linkedMapOf(*pairs))

    fun arrOf(items: List<Json>): Json.Arr = Json.Arr(items)

    fun of(value: String?): Json = if (value == null) Json.Null else Json.Str(value)
    fun of(value: Boolean): Json = Json.Bool(value)
    fun of(value: Int): Json = Json.Num(value.toDouble())
    fun of(value: Long): Json = Json.Num(value.toDouble())
    fun of(value: Float): Json = Json.Num(value.toDouble())
    fun of(value: Double): Json = Json.Num(value)

    // ---------- 序列化 ----------
    private fun write(value: Json, sb: StringBuilder, pretty: Boolean, depth: Int) {
        when (value) {
            Json.Null -> sb.append("null")
            is Json.Bool -> sb.append(if (value.value) "true" else "false")
            is Json.Num -> {
                val d = value.value
                if (d == Math.floor(d) && !d.isInfinite() && Math.abs(d) < 1e15) {
                    sb.append(d.toLong())
                } else sb.append(d)
            }
            is Json.Str -> writeString(value.value, sb)
            is Json.Arr -> {
                sb.append('[')
                value.items.forEachIndexed { i, item ->
                    if (i > 0) sb.append(',')
                    if (pretty) newLine(sb, depth + 1)
                    write(item, sb, pretty, depth + 1)
                }
                if (pretty && value.items.isNotEmpty()) newLine(sb, depth)
                sb.append(']')
            }
            is Json.Obj -> {
                sb.append('{')
                var first = true
                value.fields.forEach { (k, v) ->
                    if (v is Json.Null) return@forEach
                    if (!first) sb.append(',')
                    first = false
                    if (pretty) newLine(sb, depth + 1)
                    writeString(k, sb)
                    sb.append(':')
                    if (pretty) sb.append(' ')
                    write(v, sb, pretty, depth + 1)
                }
                if (pretty && !first) newLine(sb, depth)
                sb.append('}')
            }
        }
    }

    private fun newLine(sb: StringBuilder, depth: Int) {
        sb.append('\n')
        repeat(depth) { sb.append("  ") }
    }

    private fun writeString(s: String, sb: StringBuilder) {
        sb.append('"')
        for (c in s) {
            when {
                c == '"' -> sb.append("\\\"")
                c == '\\' -> sb.append("\\\\")
                c == '\n' -> sb.append("\\n")
                c == '\r' -> sb.append("\\r")
                c == '\t' -> sb.append("\\t")
                c == '\b' -> sb.append("\\b")
                c == '\u000C' -> sb.append("\\f")
                c < ' ' -> sb.append("\\u").append(c.code.toString(16).padStart(4, '0'))
                else -> sb.append(c)
            }
        }
        sb.append('"')
    }

    // ---------- 解析 ----------
    private class Parser(private val s: String) {
        private var pos = 0
        /** 嵌套深度：恶意/损坏的深度嵌套会直接把解析栈打爆 */
        private var depth = 0

        private inline fun <T> withDepth(block: () -> T): T {
            if (++depth > MAX_DEPTH) throw IllegalArgumentException("JSON 嵌套过深（> $MAX_DEPTH）")
            return try {
                block()
            } finally {
                depth--
            }
        }

        fun parseValue(): Json {
            skipWs()
            if (pos >= s.length) return Json.Null
            return when (s[pos]) {
                '{' -> parseObject()
                '[' -> parseArray()
                '"' -> Json.Str(parseString())
                't' -> { expect("true"); Json.Bool(true) }
                'f' -> { expect("false"); Json.Bool(false) }
                'n' -> { expect("null"); Json.Null }
                else -> parseNumber()
            }.also { skipWs() }
        }

        private fun parseObject(): Json.Obj = withDepth {
            pos++ // {
            val map = LinkedHashMap<String, Json>()
            skipWs()
            if (peek() == '}') { pos++; return Json.Obj(map) }
            while (pos < s.length) {
                skipWs()
                val key = parseString()
                skipWs()
                if (peek() == ':') pos++
                skipWs()
                val value = parseValue()
                map[key] = value
                skipWs()
                when (peek()) {
                    ',' -> pos++
                    '}' -> { pos++; break }
                    else -> pos++
                }
            }
            return Json.Obj(map)
        }

        private fun parseArray(): Json.Arr = withDepth {
            pos++ // [
            val items = ArrayList<Json>()
            skipWs()
            if (peek() == ']') { pos++; return Json.Arr(items) }
            while (pos < s.length) {
                items.add(parseValue())
                skipWs()
                when (peek()) {
                    ',' -> pos++
                    ']' -> { pos++; break }
                    else -> pos++
                }
            }
            return Json.Arr(items)
        }

        private fun parseString(): String {
            if (peek() != '"') {
                // 容错：未加引号的值读到分隔符
                val start = pos
                while (pos < s.length && s[pos] !in setOf(',', '}', ']', ':')) pos++
                return s.substring(start, pos).trim()
            }
            pos++
            val sb = StringBuilder()
            while (pos < s.length) {
                val c = s[pos++]
                if (c == '"') break
                if (c != '\\') { sb.append(c); continue }
                if (pos >= s.length) break
                when (val e = s[pos++]) {
                    'n' -> sb.append('\n')
                    'r' -> sb.append('\r')
                    't' -> sb.append('\t')
                    'b' -> sb.append('\b')
                    'f' -> sb.append('\u000C')
                    'u' -> {
                        if (pos + 4 <= s.length) {
                            val hex = s.substring(pos, pos + 4)
                            pos += 4
                            sb.append(hex.toIntOrNull(16)?.toChar() ?: '?')
                        }
                    }
                    else -> sb.append(e)
                }
            }
            return sb.toString()
        }

        private fun parseNumber(): Json {
            val start = pos
            while (pos < s.length && (s[pos].isDigit() || s[pos] in "+-.eE")) pos++
            val raw = s.substring(start, pos)
            return Json.Num(raw.toDoubleOrNull() ?: 0.0)
        }

        private fun expect(word: String) {
            repeat(word.length) { if (pos < s.length) pos++ }
        }

        private fun peek(): Char = if (pos < s.length) s[pos] else '\u0000'

        private fun skipWs() {
            while (pos < s.length && s[pos].isWhitespace()) pos++
        }
    }
}
