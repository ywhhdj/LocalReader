package com.demo.data.parser.epub

import android.util.Xml
import com.demo.data.parser.common.PathUtils
import com.demo.data.parser.common.XmlUtils
import org.xmlpull.v1.XmlPullParser
import java.io.ByteArrayInputStream

internal data class Opf(
    val title: String,
    val author: String,
    val coverId: String?,
    val tocId: String?,
    val manifest: Map<String, ManifestItem>,
    val spine: List<String>
)

internal data class ManifestItem(val href: String, val mediaType: String, val properties: String)

internal object EpubOpf {

    fun parse(bytes: ByteArray): Opf {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(ByteArrayInputStream(bytes), XmlUtils.detectXmlEncoding(bytes).name())
        var title = ""
        var author = ""
        var coverId: String? = null
        var tocId: String? = null
        var inMetadata = false
        var inSpine = false
        val manifest = LinkedHashMap<String, ManifestItem>()
        val spine = ArrayList<String>()
        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.START_TAG -> {
                    val name = XmlUtils.localName(parser)
                    when {
                        name == "metadata" -> inMetadata = true
                        inMetadata && name == "title" -> if (title.isBlank()) title = XmlUtils.readText(parser)
                        inMetadata && name == "creator" -> if (author.isBlank()) author = XmlUtils.readText(parser)
                        name == "meta" && parser.getAttributeValue(null, "name") == "cover" ->
                            coverId = parser.getAttributeValue(null, "content")
                        name == "item" -> {
                            val id = parser.getAttributeValue(null, "id") ?: ""
                            val href = PathUtils.decodePath(parser.getAttributeValue(null, "href") ?: "")
                            val media = parser.getAttributeValue(null, "media-type") ?: ""
                            val props = parser.getAttributeValue(null, "properties") ?: ""
                            if (id.isNotBlank() && href.isNotBlank()) {
                                manifest[id] = ManifestItem(href, media, props)
                                if (props.contains("cover-image")) coverId = coverId ?: id
                                if (props.contains("nav")) tocId = id
                            }
                        }
                        name == "spine" -> {
                            inSpine = true
                            val toc = parser.getAttributeValue(null, "toc")
                            if (!toc.isNullOrBlank()) tocId = tocId ?: toc
                        }
                        name == "itemref" && inSpine ->
                            parser.getAttributeValue(null, "idref")?.let { spine.add(it) }
                    }
                }
                XmlPullParser.END_TAG -> when (XmlUtils.localName(parser)) {
                    "metadata" -> inMetadata = false
                    "spine" -> inSpine = false
                }
            }
            event = parser.next()
        }
        return Opf(title.trim(), author.trim(), coverId, tocId, manifest, spine)
    }
}