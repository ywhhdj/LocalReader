package com.demo.data.parser.common

import org.xmlpull.v1.XmlPullParser
import java.nio.charset.Charset
import java.nio.charset.StandardCharsets

internal object XmlUtils {

    fun localName(parser: XmlPullParser): String = parser.name.substringAfter(':')

    /**
     * 读取当前元素的文本内容，游标停在对应的 END_TAG 上。
     *
     * 旧实现遇到第一个 END_TAG 就停：`<dc:creator>张三<a>…</a></dc:creator>`
     * 这类带嵌套标签的写法会在子标签闭合处提前结束，文本被截断。
     * 改用深度计数，只有回到本层（depth == 0）的闭合才算结束。
     */
    fun readText(parser: XmlPullParser): String {
        val sb = StringBuilder()
        var depth = 0
        var event = parser.next()
        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.START_TAG -> depth++
                XmlPullParser.END_TAG -> {
                    if (depth == 0) break
                    depth--
                }
                XmlPullParser.TEXT, XmlPullParser.CDSECT -> {
                    val t = parser.text
                    if (!t.isNullOrEmpty()) {
                        if (sb.isNotEmpty()) sb.append(' ')
                        sb.append(t)
                    }
                }
            }
            event = parser.next()
        }
        return sb.toString().replace(Regex("""\s+"""), " ").trim()
    }

    fun charsetOf(name: String): Charset = runCatching { Charset.forName(name.trim()) }
        .getOrDefault(StandardCharsets.UTF_8)

    fun detectXmlEncoding(bytes: ByteArray): Charset {
        val head = String(bytes, 0, minOf(bytes.size, 256), StandardCharsets.ISO_8859_1)
        Regex("""encoding\s*=\s*["']([^"']+)""", RegexOption.IGNORE_CASE).find(head)
            ?.groupValues?.get(1)?.let { return charsetOf(it) }
        return StandardCharsets.UTF_8
    }

  fun detectHtmlCharset(bytes: ByteArray): Charset {
    val head = String(bytes, 0, minOf(bytes.size, 2048), StandardCharsets.ISO_8859_1)
    Regex("""<meta[^>]+charset\s*=\s*["']?([A-Za-z0-9\-_]+)""", RegexOption.IGNORE_CASE).find(head)
        ?.groupValues?.get(1)?.let { return charsetOf(it) }
    return detectXmlEncoding(bytes)
  }
}