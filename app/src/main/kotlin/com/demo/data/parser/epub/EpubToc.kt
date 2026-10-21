package com.demo.data.parser.epub

import android.util.Xml
import com.demo.core.common.util.Logger
import com.demo.core.model.Chapter
import com.demo.data.parser.common.PathUtils
import com.demo.data.parser.common.XmlUtils
import com.demo.data.parser.common.ZipUtils

import org.xmlpull.v1.XmlPullParser
import java.io.ByteArrayInputStream
import java.util.zip.ZipFile

internal object EpubToc {

    private const val NCX_MEDIA_TYPE = "application/x-dtbncx+xml"

    fun resolve(zip: ZipFile, opf: Opf, basePath: String): List<Chapter> {
        opf.tocId?.let { id ->
            val navPath = opf.manifest[id]?.href?.let { PathUtils.joinPath(basePath, it) }
            val entry = navPath?.let { zip.getEntry(it) }
            if (entry != null) {
                val bytes = ZipUtils.readEntryBytes(zip, entry)
                if (bytes != null) {
                    val navDir = entry.name.substringBeforeLast('/', "")
                    val nav = parseNavXhtml(bytes, navDir)
                    if (nav.isNotEmpty()) return nav
                }
            }
        }
        val ncxItem = opf.manifest.values.firstOrNull { it.mediaType == NCX_MEDIA_TYPE }
            ?: opf.manifest.values.firstOrNull { it.href.endsWith(".ncx", true) }
        if (ncxItem != null) {
            val ncxPath = PathUtils.joinPath(basePath, ncxItem.href)
            val entry = zip.getEntry(ncxPath)
            if (entry != null) {
                val bytes = ZipUtils.readEntryBytes(zip, entry)
                if (bytes != null) {
                    val ncxDir = entry.name.substringBeforeLast('/', "")
                    val ncx = parseNcx(bytes, ncxDir)
                    if (ncx.isNotEmpty()) return ncx
                }
            }
        }
        return opf.spine.mapIndexedNotNull { index, idref ->
            val href = opf.manifest[idref]?.href ?: return@mapIndexedNotNull null
            Chapter(index = index, title = "第 ${index + 1} 章", href = PathUtils.joinPath(basePath, href))
        }
    }

    private fun parseNavXhtml(bytes: ByteArray, navDir: String): List<Chapter> {
        val text = String(bytes, XmlUtils.detectHtmlCharset(bytes))
        val result = ArrayList<Chapter>()
        val anchor = Regex("""<a[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)</a>""", RegexOption.IGNORE_CASE)
        val navBlock = Regex("""<nav[\s\S]*?</nav>""", RegexOption.IGNORE_CASE).findAll(text)
            .map { it.value }
            .firstOrNull { it.contains("toc", true) || it.contains("nav", true) }
            ?: Regex("""<nav[\s\S]*?</nav>""", RegexOption.IGNORE_CASE).find(text)?.value
            ?: text
        var index = 0
        for (m in anchor.findAll(navBlock)) {
            val href = PathUtils.stripFragment(m.groupValues[1])
            val label = plainOf(m.groupValues[2])
            if (href.isBlank() || label.isBlank()) continue
            val joined = PathUtils.joinPath(navDir, href)
            if (result.any { it.href == joined }) continue
            result.add(Chapter(index++, label, joined))
        }
        return result
    }

    private fun parseNcx(bytes: ByteArray, ncxDir: String): List<Chapter> {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        return runCatching {
            parser.setInput(ByteArrayInputStream(bytes), XmlUtils.detectXmlEncoding(bytes).name())
            val result = ArrayList<Chapter>()
            var label = ""
            var src = ""
            var event = parser.eventType
            while (event != XmlPullParser.END_DOCUMENT) {
                when (event) {
                    XmlPullParser.START_TAG -> when (XmlUtils.localName(parser)) {
                        "text" -> label = XmlUtils.readText(parser)
                        "content" -> src = parser.getAttributeValue(null, "src") ?: ""
                    }
                    XmlPullParser.END_TAG -> if (XmlUtils.localName(parser) == "navPoint") {
                        val clean = PathUtils.stripFragment(src)
                        if (clean.isNotBlank()) {
                            val href = PathUtils.joinPath(ncxDir, clean)
                            if (result.none { it.href == href }) {
                                result.add(Chapter(
                                    index = result.size,
                                    title = label.trim().ifBlank { "第 ${result.size + 1} 章" },
                                    href = href
                                ))
                            }
                        }
                        label = ""
                        src = ""
                    }
                }
                event = parser.next()
            }
            result
        }.getOrDefault(emptyList())
    }

    private fun plainOf(html: String): String {
        val noTag = html.replace(Regex("""<[^>]+>"""), " ")
        return HtmlExtractor.decodeEntitiesStatic(noTag).replace(Regex("""\s+"""), " ").trim()
    }
}