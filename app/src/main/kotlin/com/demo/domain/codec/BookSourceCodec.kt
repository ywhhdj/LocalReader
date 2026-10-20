package com.demo.domain.codec

import com.demo.core.common.util.Json
import com.demo.core.common.util.MiniJson
import com.demo.domain.repository.BookSource

/** 书源配置序列化（数组 JSON，字段缺省即空） */
object BookSourceCodec {

    fun encode(sources: List<BookSource>): String = MiniJson.stringify(
        MiniJson.arrOf(sources.map { s ->
            MiniJson.objOf(
                "id" to MiniJson.of(s.id),
                "name" to MiniJson.of(s.name),
                "baseUrl" to MiniJson.of(s.baseUrl),
                "searchUrl" to MiniJson.of(s.searchUrl),
                "charset" to MiniJson.of(s.charset),
                "searchListRule" to MiniJson.of(s.searchListRule),
                "titleRule" to MiniJson.of(s.titleRule),
                "authorRule" to MiniJson.of(s.authorRule),
                "detailUrlRule" to MiniJson.of(s.detailUrlRule),
                "coverRule" to MiniJson.of(s.coverRule),
                "tocListRule" to MiniJson.of(s.tocListRule),
                "tocTitleRule" to MiniJson.of(s.tocTitleRule),
                "tocUrlRule" to MiniJson.of(s.tocUrlRule),
                "contentRule" to MiniJson.of(s.contentRule)
            )
        })
    )

    fun decode(raw: String?): List<BookSource> {
        if (raw.isNullOrBlank()) return emptyList()
        val json = MiniJson.parseOrNull(raw) ?: return emptyList()
        val items = when (json) {
            is Json.Arr -> json.items
            is Json.Obj -> json.arr("sources")?.items ?: listOf(json)
            else -> emptyList()
        }
        return items.mapNotNull { item ->
            val name = item.str("name") ?: return@mapNotNull null
            BookSource(
                id = item.str("id", name),
                name = name,
                baseUrl = item.str("baseUrl", ""),
                searchUrl = item.str("searchUrl", ""),
                charset = item.str("charset", "UTF-8"),
                searchListRule = item.str("searchListRule", ""),
                titleRule = item.str("titleRule", ""),
                authorRule = item.str("authorRule", ""),
                detailUrlRule = item.str("detailUrlRule", ""),
                coverRule = item.str("coverRule", ""),
                tocListRule = item.str("tocListRule", ""),
                tocTitleRule = item.str("tocTitleRule", ""),
                tocUrlRule = item.str("tocUrlRule", ""),
                contentRule = item.str("contentRule", "")
            )
        }.filter { it.valid }
    }

    /** 内置模板（仅作示例，未启用时不会发起任何请求） */
    fun template(): String = """[
  {
    "id": "example",
    "name": "示例书源",
    "baseUrl": "https://example.com",
    "searchUrl": "https://example.com/search?q=${'$'}{key}",
    "charset": "UTF-8",
    "searchListRule": "<li class=\"book\">[\\s\\S]*?</li>",
    "titleRule": "<h3>([^<]+)</h3>",
    "authorRule": "作者：([^<]+)",
    "detailUrlRule": "href=\"([^\"]+)\"",
    "coverRule": "src=\"([^\"]+)\"",
    "tocListRule": "<dd>[\\s\\S]*?</dd>",
    "tocTitleRule": "<a[^>]*>([^<]+)</a>",
    "tocUrlRule": "href=\"([^\"]+)\"",
    "contentRule": "<div id=\"content\">([\\s\\S]*?)</div>"
  }
]"""
}
