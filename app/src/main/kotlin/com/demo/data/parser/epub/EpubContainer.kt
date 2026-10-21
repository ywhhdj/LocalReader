package com.demo.data.parser.epub

import android.util.Xml
import com.demo.data.parser.common.XmlUtils
import com.demo.data.parser.common.ZipUtils
import org.xmlpull.v1.XmlPullParser
import java.io.ByteArrayInputStream
import java.util.zip.ZipFile

internal object EpubContainer {

    fun resolveOpfPath(zip: ZipFile): String? {
        val container = zip.getEntry("META-INF/container.xml")?.let { ZipUtils.readEntryBytes(zip, it) }
        if (container != null) {
            val path = parseContainer(container)
            if (!path.isNullOrBlank() && zip.getEntry(path) != null) return path
            val decoded = com.demo.data.parser.common.PathUtils.decodePath(path.orEmpty())
            zip.entries().toList().firstOrNull {
                it.name.equals(path, true) || it.name.equals(decoded, true) ||
                    it.name.endsWith(decoded.substringAfterLast('/'), true)
            }?.let { return it.name }
        }
        return zip.entries().toList().firstOrNull {
            !it.isDirectory && it.name.endsWith(".opf", true)
        }?.name
    }

    private fun parseContainer(bytes: ByteArray): String? {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(ByteArrayInputStream(bytes), XmlUtils.detectXmlEncoding(bytes).name())
        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            if (event == XmlPullParser.START_TAG && XmlUtils.localName(parser) == "rootfile") {
                val media = parser.getAttributeValue(null, "media-type")
                val path = parser.getAttributeValue(null, "full-path")
                if (!path.isNullOrBlank() && (media == null || media.contains("oebps-package"))) {
                    return com.demo.data.parser.common.PathUtils.decodePath(path)
                }
            }
            event = parser.next()
        }
        return null
    }
}