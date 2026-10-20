package com.demo.data.source

/**
 * 极简抽取规则：全部按正则处理（无第三方 HTML 解析器）。
 * - 规则为空 → 返回空
 * - 有捕获组 → 取第 1 组；无捕获组 → 取整段匹配
 */
object RuleEngine {

    fun list(html: String, listRule: String): List<String> {
        if (html.isBlank() || listRule.isBlank()) return emptyList()
        val regex = runCatching { Regex(listRule, RegexOption.DOT_MATCHES_ALL) }.getOrNull() ?: return emptyList()
        return regex.findAll(html).map { it.value }.toList()
    }

    fun first(block: String, rule: String): String? {
        if (block.isBlank() || rule.isBlank()) return null
        val regex = runCatching { Regex(rule, RegexOption.DOT_MATCHES_ALL) }.getOrNull() ?: return null
        val m = regex.find(block) ?: return null
        return (m.groupValues.getOrNull(1)?.takeIf { it.isNotBlank() } ?: m.value).cleanText()
    }

    /** 正文：取出整块 → 去标签 → 分段 */
    fun content(html: String, contentRule: String): List<String> {
        val block = first(html, contentRule) ?: return emptyList()
        return block
            .replace(Regex("""<br\s*/?>""", RegexOption.IGNORE_CASE), "\n")
            .replace(Regex("""</p>""", RegexOption.IGNORE_CASE), "\n")
            .replace(Regex("""<script[\s\S]*?</script>""", RegexOption.IGNORE_CASE), "")
            .replace(Regex("""<[^>]+>"""), "")
            .let { decodeEntities(it) }
            .split(Regex("""\n+"""))
            .map { it.trim() }
            .filter { it.isNotBlank() }
    }

    fun absolute(base: String, url: String): String {
        if (url.isBlank()) return ""
        if (url.startsWith("http://") || url.startsWith("https://")) return url
        val b = base.trimEnd('/')
        return if (url.startsWith("/")) {
            val scheme = b.substringBefore("://", "")
            val host = b.substringAfter("://").substringBefore('/')
            if (scheme.isNotBlank()) "$scheme://$host$url" else url
        } else "$b/$url"
    }

    private fun String.cleanText(): String = decodeEntities(this.replace(Regex("""<[^>]+>"""), ""))
        .replace(Regex("""\s+"""), " ")
        .trim()

    private fun decodeEntities(input: String): String {
        if (input.indexOf('&') < 0) return input
        var s = input
        s = s.replace("&nbsp;", " ")
        s = s.replace("&amp;", "&")
        s = s.replace("&lt;", "<")
        s = s.replace("&gt;", ">")
        s = s.replace("&quot;", "\"")
        s = s.replace("&apos;", "'")
        s = s.replace("&#39;", "'")
        s = s.replace("&mdash;", "—")
        s = s.replace("&ldquo;", "“")
        s = s.replace("&rdquo;", "”")
        return s
    }
}
