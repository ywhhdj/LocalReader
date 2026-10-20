package com.demo.data.parser

import com.demo.core.model.BookBlock

/**
 * 轻量 HTML → 正文块抽取（无第三方依赖）。
 * 保留段落/标题/图片/引用，剥离脚本与样式，输出结构化 blocks 供 Compose 渲染。
 */
object HtmlExtractor {

    private val TAG_REGEX = Regex("""<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*?)(/?)>""")
    private val SCRIPT_REGEX = Regex("""<(script|style|head)[\s\S]*?</\1>""", RegexOption.IGNORE_CASE)
    private val COMMENT_REGEX = Regex("""<!--[\s\S]*?-->""")
    private val SRC_REGEX = Regex("""src\s*=\s*["']([^"']+)["']""", RegexOption.IGNORE_CASE)
    private val ALT_REGEX = Regex("""alt\s*=\s*["']([^"']*)["']""", RegexOption.IGNORE_CASE)

    fun extract(html: String, imageResolver: ((String) -> String?)? = null): List<BookBlock> {
        var cleaned = html
        cleaned = SCRIPT_REGEX.replace(cleaned, " ")
        cleaned = COMMENT_REGEX.replace(cleaned, " ")

        val blocks = ArrayList<BookBlock>(64)
        val buffer = StringBuilder()
        var pendingKind = Kind.PARAGRAPH
        var headingLevel = 2

        fun flush() {
            val text = buffer.toString().trim()
            buffer.setLength(0)
            if (text.isEmpty()) return
            when (pendingKind) {
                Kind.HEADING -> blocks.add(BookBlock.Heading(text, headingLevel))
                Kind.QUOTE -> blocks.add(BookBlock.Quote(text))
                Kind.PARAGRAPH -> blocks.add(BookBlock.Paragraph(text))
            }
        }

        var last = 0
        for (m in TAG_REGEX.findAll(cleaned)) {
            val text = cleaned.substring(last, m.range.first)
            val decoded = decodeEntities(text)
            val folded = decoded.replace(Regex("""\s+"""), " ")
            if (folded.isNotBlank()) {
                if (buffer.isNotEmpty()) buffer.append(' ')
                buffer.append(folded.trim())
            }
            last = m.range.last + 1

            val closing = m.groupValues[1].isNotEmpty()
            val tag = m.groupValues[2].lowercase()
            val attrs = m.groupValues[3]

            when {
                tag == "br" || tag == "hr" -> flush()
                tag == "img" -> {
                    flush()
                    val src = SRC_REGEX.find(attrs)?.groupValues?.get(1) ?: continue
                    val alt = ALT_REGEX.find(attrs)?.groupValues?.get(1) ?: ""
                    val resolved = imageResolver?.invoke(src)
                    if (resolved != null) blocks.add(BookBlock.Image(resolved, alt))
                }
                tag.matches(Regex("""h[1-6]""")) -> {
                    flush()
                    if (!closing) {
                        pendingKind = Kind.HEADING
                        headingLevel = tag.substring(1).toIntOrNull() ?: 2
                    } else pendingKind = Kind.PARAGRAPH
                }
                tag == "blockquote" || tag == "q" -> {
                    flush()
                    pendingKind = if (closing) Kind.PARAGRAPH else Kind.QUOTE
                }
                tag == "p" || tag == "div" || tag == "li" || tag == "tr" || tag == "section" -> {
                    flush()
                    pendingKind = Kind.PARAGRAPH
                }
            }
        }
        val tail = decodeEntities(cleaned.substring(last)).replace(Regex("""\s+"""), " ").trim()
        if (tail.isNotBlank()) buffer.append(tail)
        flush()
        return blocks
    }

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

    private enum class Kind { PARAGRAPH, HEADING, QUOTE }
}
