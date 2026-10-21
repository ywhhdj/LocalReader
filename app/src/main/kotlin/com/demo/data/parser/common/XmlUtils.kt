package com.demo.data.parser.common

import org.xmlpull.v1.XmlPullParser
import java.nio.charset.Charset
import java.nio.charset.StandardCharsets

internal object XmlUtils {

    fun localName(parser: XmlPullParser): String = parser.name.substringAfter(':')

    fun readText(parser: XmlPullParser): String {
        val sb = StringBuilder()
        var event = parser.next()
        while (event != XmlPullParser.END_TAG && event != XmlPullParser.END_DOCUMENT) {
            if (event == XmlPullParser.TEXT || event == XmlPullParser.CDSECT) {
                sb.append(parser.text)
            }
            event = parser.next()
        }
        return sb.toString().trim()
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