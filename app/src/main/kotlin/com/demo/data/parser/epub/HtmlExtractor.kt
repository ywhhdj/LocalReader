package com.demo.data.parser.epub

import com.demo.core.model.BookBlock

/**
 * 轻量 HTML → 正文块抽取（无第三方依赖）。
 * 保留段落/标题/图片/引用，剥离脚本与样式，输出结构化 blocks 供 Compose 渲染。
 *
 * 稳定性要点（"制作信息"等异常章节曾导致崩溃）：
 * 1. 剥离 svg / iframe / form / nav 等非正文块（内嵌巨型 SVG 会生成上万文本块直接 OOM）；
 * 2. 限制块数量与单块文本长度，超长内容分段，避免一次性创建海量 Composable；
 * 3. 保留段落内真实换行（旧实现把 \s+ 全部折叠为空格，正文全糊成一大坨）；
 * 4. 整体 try-catch，任何解析异常都退化成一段占位文本而不是崩溃。
 */
object HtmlExtractor {

    private val TAG_REGEX = Regex("""<(/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*?)(/?)>""")
    private val DROP_REGEX = Regex(
        """<(script|style|head|svg|noscript|iframe|object|embed|form|button|select|textarea|nav|footer|audio|video|canvas)[\s\S]*?</\1>""",
        RegexOption.IGNORE_CASE
    )
    private val COMMENT_REGEX = Regex("""<!--[\s\S]*?-->""")
    private val SRC_REGEX = Regex("""src\s*=\s*["']([^"']+)["']""", RegexOption.IGNORE_CASE)
    private val ALT_REGEX = Regex("""alt\s*=\s*["']([^"']*)["']""", RegexOption.IGNORE_CASE)
    private val SPACE_REGEX = Regex("""[ \t\r\u00A0\u3000]+""")
    private val BLANK_LINE_REGEX = Regex("""\n[ \t]*\n+""")
    private val XML_PROLOG_REGEX = Regex("""<\?[\s\S]*?\?>""")
    /** DOCTYPE 可能带内部子集 [ <!ENTITY ...> ]，用 [^>\[] 排除 '>' 和 '[' 再配平方括号 */
    private val DOCTYPE_REGEX = Regex("""<!DOCTYPE(?:[^>\[]|\[[\s\S]*?])*>""", RegexOption.IGNORE_CASE)

    /** 单章节正文最大处理长度（超出截断，防止超大章节 OOM） */
    private const val MAX_HTML_LENGTH = 4 * 1024 * 1024
    /** 单章节最大块数 */
    private const val MAX_BLOCKS = 1200
    /** 单块最大字符数，超出自动分段 */
    private const val MAX_BLOCK_TEXT = 4000

    fun extract(html: String, imageResolver: ((String) -> String?)? = null): List<BookBlock> {
        return runCatching { extractInternal(html, imageResolver) }
            .getOrElse { listOf(BookBlock.Paragraph("（该章节内容解析失败，可尝试重新导入本书）")) }
    }

    private fun extractInternal(html: String, imageResolver: ((String) -> String?)?): List<BookBlock> {
        var cleaned = if (html.length > MAX_HTML_LENGTH) html.substring(0, MAX_HTML_LENGTH) else html
        cleaned = XML_PROLOG_REGEX.replace(cleaned, " ")
        cleaned = DOCTYPE_REGEX.replace(cleaned, " ")
        cleaned = DROP_REGEX.replace(cleaned, " ")
        cleaned = COMMENT_REGEX.replace(cleaned, " ")

        val blocks = ArrayList<BookBlock>(64)
        val buffer = StringBuilder()
        var pendingKind = Kind.PARAGRAPH
        var headingLevel = 2

        fun flush() {
            if (blocks.size >= MAX_BLOCKS) {
                buffer.setLength(0)
                return
            }
            val text = buffer.toString().trim()
            buffer.setLength(0)
            if (text.isEmpty()) return
            when (pendingKind) {
                Kind.HEADING -> blocks.add(BookBlock.Heading(text.take(MAX_BLOCK_TEXT), headingLevel))
                Kind.QUOTE -> blocks.add(BookBlock.Quote(text.take(MAX_BLOCK_TEXT)))
                Kind.PARAGRAPH -> splitLong(text).forEach { blocks.add(BookBlock.Paragraph(it)) }
            }
        }

        var last = 0
        for (m in TAG_REGEX.findAll(cleaned)) {
            if (blocks.size >= MAX_BLOCKS) break
            val text = cleaned.substring(last, m.range.first)
            val folded = normalize(text)
            if (folded.isNotBlank()) {
                if (buffer.isNotEmpty()) buffer.append('\n')
                buffer.append(folded)
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
                    if (src.startsWith("data:", true)) continue
                    val alt = ALT_REGEX.find(attrs)?.groupValues?.get(1) ?: ""
                    if (blocks.size >= MAX_BLOCKS) continue
                    val resolved = runCatching { imageResolver?.invoke(src) }.getOrNull()
                    if (!resolved.isNullOrBlank()) blocks.add(BookBlock.Image(resolved, alt))
                }
                tag.matches(HEADING_REGEX) -> {
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
                tag == "p" || tag == "div" || tag == "li" || tag == "tr" || tag == "section" ||
                    tag == "article" || tag == "td" || tag == "h4" || tag == "h5" || tag == "h6" ||
                    tag == "pre" || tag == "dd" || tag == "dt" -> {
                    flush()
                    pendingKind = Kind.PARAGRAPH
                }
            }
        }
        val tail = normalize(cleaned.substring(last.coerceAtMost(cleaned.length)))
        if (tail.isNotBlank()) {
            if (buffer.isNotEmpty()) buffer.append('\n')
            buffer.append(tail)
        }
        flush()
        if (blocks.isEmpty()) blocks.add(BookBlock.Paragraph("（本章无正文内容）"))
        return blocks
    }

    /** 保留段落内换行，折叠多余空白（HTML 源码缩进不会变成换行） */
    private fun normalize(text: String): String {
        if (text.isBlank()) return ""
        var s = decodeEntities(text).replace("\uFEFF", "")
        s = s.replace(BLANK_LINE_REGEX, "\n")
        s = s.replace(SPACE_REGEX, " ")
        s = s.replace(Regex("""\n """), "\n").replace(Regex(""" \n"""), "\n")
        s = s.replace(Regex("""\n{2,}"""), "\n")
        return s.trim()
    }

    /** 超长段落按句分段，避免单个 Text 承载巨量字符 */
    private fun splitLong(text: String): List<String> {
        if (text.length <= MAX_BLOCK_TEXT) return listOf(text)
        val out = ArrayList<String>()
        var start = 0
        while (start < text.length) {
            val end = (start + MAX_BLOCK_TEXT).coerceAtMost(text.length)
            var cut = end
            if (end < text.length) {
                val nl = text.lastIndexOf('\n', end)
                if (nl > start + MAX_BLOCK_TEXT / 2) cut = nl
            }
            out.add(text.substring(start, cut).trim())
            start = cut
        }
        return out.filter { it.isNotEmpty() }.ifEmpty { listOf(text.take(MAX_BLOCK_TEXT)) }
    }

    /** 供外部复用（如目录标题去标签后解码实体） */
    fun decodeEntitiesStatic(input: String): String = decodeEntities(input)

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
        s = NUM_ENTITY.replace(s) { m ->
            runCatching { m.groupValues[1].toInt().toChar().toString() }.getOrDefault(m.value)
        }
        s = HEX_ENTITY.replace(s) { m ->
            runCatching { m.groupValues[1].toInt(16).toChar().toString() }.getOrDefault(m.value)
        }
        return s
    }

    private val HEADING_REGEX = Regex("""h[1-6]""")
    private val NUM_ENTITY = Regex("""&#(\d+);""")
    private val HEX_ENTITY = Regex("""&#[xX]([0-9a-fA-F]+);""")

    private enum class Kind { PARAGRAPH, HEADING, QUOTE }
}
