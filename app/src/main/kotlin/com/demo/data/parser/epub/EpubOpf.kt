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

    /**
     * 解析 OPF。
     *
     * 元数据（书名 / 作者）此前漏检的三类真实成因，这里一并处理：
     * 1. **标签大小写**：OEBPS 1.0 与部分国产工具写 `<dc:Title>` / `<dc:Creator>`，
     *    原来按小写字面量比较，直接匹配不上 → 作者永远是"未知"；
     * 2. **metadata 容器名变体**：`<dc-metadata>` / `<opf:metadata>` 这类写法
     *    不会等于 "metadata"，旧实现的布尔开关一直没打开，内部字段全被忽略；
     *    改用"深度计数 + 名字以 metadata 结尾"判定；
     * 3. **作者来源不止 dc:creator**：`<meta name="author">`、EPUB3 的
     *    `<meta property="dcterms:creator">`、`opf:file-as` 属性都作为兜底。
     */
    fun parse(bytes: ByteArray): Opf {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(ByteArrayInputStream(bytes), XmlUtils.detectXmlEncoding(bytes).name())
        var title = ""
        /** 收集到的作者候选：正文文本优先，其次 opf:file-as */
        val authors = ArrayList<Pair<String, String>>()   // (role, name)
        var metaAuthor = ""
        /** metadata 嵌套深度：>0 说明当前在元数据区（兼容 dc-metadata 等变体） */
        var metadataDepth = 0
        var inSpine = false
        var coverId: String? = null
        var tocId: String? = null
        val manifest = LinkedHashMap<String, ManifestItem>()
        val spine = ArrayList<String>()
        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.START_TAG -> {
                    val raw = XmlUtils.localName(parser)
                    val name = raw.lowercase()
                    when {
                        // 兼容 metadata / dc-metadata / opf:metadata
                        name.endsWith("metadata") -> metadataDepth++
                        metadataDepth > 0 && name == "title" ->
                            if (title.isBlank()) title = XmlUtils.readText(parser)
                        metadataDepth > 0 && name == "creator" -> {
                            // 属性只能在 START_TAG 上取：readText 会把游标推到 END_TAG
                            val role = attrEndsWith(parser, "role").orEmpty()
                            val fileAs = attrEndsWith(parser, "file-as")
                            val text = XmlUtils.readText(parser)
                            val value = text.ifBlank { fileAs.orEmpty() }
                            if (value.isNotBlank()) authors.add(role to value)
                        }
                        metadataDepth > 0 && name == "meta" -> {
                            val prop = parser.getAttributeValue(null, "property").orEmpty()
                            val metaName = parser.getAttributeValue(null, "name").orEmpty()
                            val content = parser.getAttributeValue(null, "content").orEmpty()
                            if (metaName.equals("cover", true)) {
                                coverId = content
                            } else if (metaName.equals("author", true) ||
                                metaName.endsWith("author", true) ||
                                prop.equals("dcterms:creator", true)
                            ) {
                                // EPUB3：<meta property="dcterms:creator">作者</meta>
                                val text = XmlUtils.readText(parser)
                                val value = text.ifBlank { content }
                                if (value.isNotBlank()) metaAuthor = value
                            }
                        }
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
                XmlPullParser.END_TAG -> when (XmlUtils.localName(parser).lowercase()) {
                    "spine" -> inSpine = false
                    // 只在 metadata 系列标签闭合时递减，避免嵌套标签误关
                    else -> if (XmlUtils.localName(parser).endsWith("metadata", true)) {
                        metadataDepth = (metadataDepth - 1).coerceAtLeast(0)
                    }
                }
            }
            event = parser.next()
        }
        val author = pickAuthor(authors, metaAuthor)
        return Opf(clean(title), author, coverId, tocId, manifest, spine)
    }

    /**
     * 选定作者：
     * 1. 优先 `opf:role="aut"`（创作者），排除译者 / 编者；
     * 2. 其次第一个非空候选；
     * 3. 都没有才用 `<meta>` 里的作者。
     */
    private fun pickAuthor(authors: List<Pair<String, String>>, metaAuthor: String): String {
        val cleaned = authors.map { (role, name) -> role.lowercase() to clean(name) }
            .filter { it.second.isNotBlank() }
        val aut = cleaned.firstOrNull { it.first == "aut" }?.second
        if (!aut.isNullOrBlank()) return aut
        val any = cleaned.firstOrNull()?.second
        if (!any.isNullOrBlank()) return any
        return clean(metaAuthor)
    }

    /** 去 HTML 标签、压缩空白；多个作者用「、」连接 */
    private fun clean(raw: String): String = raw
        .replace(Regex("""<[^>]*>"""), " ")
        .replace(Regex("""\s+"""), " ")
        .trim()
        .trim('、', ',', '，', ';', '；', '|')

    /** 取属性值（属性名可能带 opf: 前缀，逐个比对后缀） */
    private fun attrEndsWith(parser: XmlPullParser, suffix: String): String? {
        for (i in 0 until parser.attributeCount) {
            val n = parser.getAttributeName(i).substringAfter(':').lowercase()
            if (n == suffix) return parser.getAttributeValue(i)
        }
        return null
    }

}