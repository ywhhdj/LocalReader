package com.demo.data.source

import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import org.jsoup.nodes.Element

/**
 * Legado 规则引擎
 *
 * 支持：
 * - CSS 选择器（JSoup 原生）：tag / .class / #id / [attr=val] / :first / :eq(n) / :contains(...)
 * - @ 管道：@text @ownText @html @outerHtml @href @src @textNodes @tag @attr(x) @css:xxx
 * - ##正则##替换##（尾部额外 # 表示 global）
 *
 * 不支持（明确降级返回空）：
 * - @js: / {{ }} / @XPath: / @json:
 */
object LegadoRuleEngine {

  // ---------- 对外 API（签名与 RuleEngine 对齐） ----------

  fun list(html: String, rule: String): List<String> {
    if (html.isBlank() || rule.isBlank()) return emptyList()
    val doc = parse(html) ?: return emptyList()
    val pipeline = Pipeline.parse(rule)
    return pipeline.selectAll(doc).map { it.outerHtml() }
  }

  fun first(block: String, rule: String): String? {
    if (block.isBlank() || rule.isBlank()) return null
    val doc = parse(block) ?: return null
    val pipeline = Pipeline.parse(rule)
    val el = pipeline.selectAll(doc).firstOrNull() ?: return null
    return pipeline.extractText(el).cleanText()
  }

  fun content(html: String, rule: String): List<String> {
    if (html.isBlank() || rule.isBlank()) return emptyList()
    val doc = parse(html) ?: return emptyList()
    val pipeline = Pipeline.parse(rule)
    val nodes = pipeline.selectAll(doc)
    if (nodes.isEmpty()) return emptyList()
    val raw = nodes.joinToString("\n") { pipeline.extractRaw(it) }
    return raw.replace(Regex("""<br\s*/?>""", RegexOption.IGNORE_CASE), "\n")
      .replace(Regex("""</p\s*>""", RegexOption.IGNORE_CASE), "\n\n")
      .replace(Regex("""<[^>]+>"""), "")
      .let { RuleEngine.decodeEntitiesPublic(it) }
      .split(Regex("""\n{2,}|\r?\n"""))
      .map { it.trim() }
      .filter { it.isNotBlank() }
  }

  // ---------- 内部 ----------

  private fun parse(html: String): Document? = runCatching { Jsoup.parse(html) }.getOrNull()

  private class Pipeline(
    val selector: String,
    val ops: List<String>,
    val replacePattern: Regex?,
    val replaceWith: String,
    val replaceGlobal: Boolean
  ) {
    companion object {
      /** 规则语法：selector[@op...][##正则##替换##] */
      fun parse(raw: String): Pipeline {
        var rule = raw.trim()

        // 尾部 ##正则##替换##（再多的 # 表示 global）
        var pattern: Regex? = null
        var replacement = ""
        var global = false
        val idx = rule.indexOf("##")
        if (idx >= 0) {
          val tail = rule.substring(idx + 2)
          global = tail.endsWith("###")
          val body = if (global) tail.dropLast(1) else tail
          val parts = body.split("##")
          if (parts.isNotEmpty() && parts[0].isNotEmpty()) {
            pattern = runCatching { Regex(parts[0]) }.getOrNull()
            replacement = parts.getOrNull(1).orEmpty()
          }
          rule = rule.substring(0, idx)
        }

        // 按 @ 拆，避免误伤 @css: / @attr(...)
        val pieces = ArrayList<String>()
        val sb = StringBuilder()
        var i = 0
        while (i < rule.length) {
          val c = rule[i]
          if (c == '@' && i + 1 < rule.length) {
            pieces.add(sb.toString())
            sb.setLength(0)
            val rest = rule.substring(i + 1)
            if (rest.startsWith("css:", true)) {
              sb.append("css:")
              i += 5
            } else i++
          } else {
            sb.append(c)
            i++
          }
        }
        if (sb.isNotEmpty()) pieces.add(sb.toString())

        if (pieces.isEmpty()) return Pipeline("", emptyList(), pattern, replacement, global)
        val selector = pieces[0].trim()
        val ops = pieces.drop(1).map { it.trim() }.filter { it.isNotEmpty() }
        return Pipeline(selector, ops, pattern, replacement, global)
      }
    }

    /** 选择所有匹配节点（root 是 Document 时是文档根；根元素时也能工作） */
    fun selectAll(root: Document): List<Element> {
      val sel = selector.removePrefix("css:").removePrefix("CSS:").ifBlank { "body" }
      return runCatching { root.select(sel).toList() }.getOrDefault(emptyList())
    }

    fun selectAll(root: Element): List<Element> {
      if (selector.isBlank()) return listOf(root)
      val sel = selector.removePrefix("css:").removePrefix("CSS:")
      return runCatching { root.select(sel).toList() }.getOrDefault(emptyList())
    }

    /** 从 Element 抽取文本/属性 */
    fun extractText(el: Element): String {
      if (ops.isEmpty()) return el.text()
      var cur: Element? = el
      var last = ""
      for (op in ops) {
        cur = cur ?: break
        last = when {
          op == "text" || op == "textNodes" -> cur.text()
          op == "ownText" -> cur.ownText()
          op == "html" -> cur.html()
          op == "outerHtml" -> cur.outerHtml()
          op == "href" || op == "src" -> cur.attr(op)
          op == "tag" -> cur.tagName()
          op.startsWith("attr(", true) -> cur.attr(op.substring(5).trimEnd(')'))
          op.startsWith("css:", true) || op.startsWith("CSS:") -> {
            val sel = op.substring(4)
            val next = cur.selectFirst(sel)
            cur = next
            next?.text().orEmpty()
          }
          // 继续向下选择
          else -> {
            val next = cur.selectFirst(op)
            cur = next
            next?.text().orEmpty()
          }
        }
      }
      return applyReplace(last)
    }

    fun extractRaw(el: Element): String {
      if (ops.contains("html")) return el.html()
      if (ops.contains("outerHtml")) return el.outerHtml()
      return applyReplace(el.text())
    }

    private fun applyReplace(s: String): String {
      val p = replacePattern ?: return s
      return if (replaceGlobal) p.replace(s, replaceWith) else p.replaceFirst(s, replaceWith)
    }
  }

  private fun String.cleanText(): String =
    RuleEngine.decodeEntitiesPublic(this).replace(Regex("""\s+"""), " ").trim()
}
