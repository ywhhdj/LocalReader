package com.demo.data.source

object RuleEngine {

    /** 旧入口保留，内部自动分流 */
    fun list(html: String, rule: String): List<String> =
        if (isLegado(rule)) LegadoRuleEngine.list(html, rule) else regexList(html, rule)

    fun first(block: String, rule: String): String? =
        if (isLegado(rule)) LegadoRuleEngine.first(block, rule) else regexFirst(block, rule)

    fun content(html: String, rule: String): List<String> =
        if (isLegado(rule)) LegadoRuleEngine.content(html, rule) else regexContent(html, rule)

    // ---------- 自动识别 ----------

    /**
     * 判定规则是否属于 Legado 语法：
     * - 含 @ 操作（@text/@href/@html/@attr(...)）
     * - 以 class./id./css: 开头
     * - 是纯 tag 名（不含正则元字符）
     */
    fun isLegado(rule: String): Boolean {
        val t = rule.trim()
        if (t.isEmpty()) return false
        if (t.contains("@")) return true
        if (t.startsWith("class.", true) || t.startsWith("id.", true)) return true
        if (t.startsWith("css:", true)) return true
        // 纯 tag 名（字母开头，且不含正则元字符）
        if (t.matches(Regex("""^[a-zA-Z][a-zA-Z0-9]*$"""))) return true
        // 含 ## 正则替换
        if (t.contains("##")) return true
        return false
    }

    // ---------- 旧实现（改名，兼容） ----------

    private fun regexList(html: String, listRule: String): List<String> {
        if (html.isBlank() || listRule.isBlank()) return emptyList()
        val regex = runCatching { Regex(listRule, RegexOption.DOT_MATCHES_ALL) }.getOrNull() ?: return emptyList()
        return regex.findAll(html).map { it.value }.toList()
    }

    private fun regexFirst(block: String, rule: String): String? {
        if (block.isBlank() || rule.isBlank()) return null
        val regex = runCatching { Regex(rule, RegexOption.DOT_MATCHES_ALL) }.getOrNull() ?: return null
        val m = regex.find(block) ?: return null
        return (m.groupValues.getOrNull(1)?.takeIf { it.isNotBlank() } ?: m.value).cleanText()
    }

    private fun regexContent(html: String, contentRule: String): List<String> {
        val block = regexFirst(html, contentRule) ?: return emptyList()
        return block
            .replace(Regex("""<br\s*/?>""", RegexOption.IGNORE_CASE), "\n")
            .replace(Regex("""</p>""", RegexOption.IGNORE_CASE), "\n")
            .replace(Regex("""<script[\s\S]*?</script>""", RegexOption.IGNORE_CASE), "")
            .replace(Regex("""<[^>]+>"""), "")
            .let { decodeEntitiesPublic(it) }
            .split(Regex("""\n+""")).map { it.trim() }.filter { it.isNotBlank() }
    }

    // ---------- 通用 ----------

    fun absolute(base: String, url: String): String {
        if (url.isBlank()) return ""
        if (url.startsWith("http://") || url.startsWith("https://")) return url
        val b = base.trimEnd('/')
        if (url.startsWith("/")) {
            val scheme = b.substringBefore("://", "")
            val host = b.substringAfter("://").substringBefore('/')
            return if (scheme.isNotBlank()) "$scheme://$host$url" else url
        }
        return "$b/$url"
    }

    private fun String.cleanText(): String =
        decodeEntitiesPublic(this.replace(Regex("""<[^>]+>"""), "")).replace(Regex("""\s+"""), " ").trim()

    /** 公开给 LegadoRuleEngine 复用 */
    fun decodeEntitiesPublic(input: String): String {
        if (input.indexOf('&') < 0) return input
        var s = input
        s = s.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
        s = s.replace("&quot;", "\"").replace("&apos;", "'").replace("&#39;", "'")
        s = s.replace("&mdash;", "—").replace("&ldquo;", "“").replace("&rdquo;", "”")
        s = NUM.replace(s) { runCatching { it.groupValues[1].toInt().toChar().toString() }.getOrDefault(it.value) }
        s = HEX.replace(s) { runCatching { it.groupValues[1].toInt(16).toChar().toString() }.getOrDefault(it.value) }
        return s
    }

    private val NUM = Regex("""&#(\d+);""")
    private val HEX = Regex("""&#[xX]([0-9a-fA-F]+);""")
}