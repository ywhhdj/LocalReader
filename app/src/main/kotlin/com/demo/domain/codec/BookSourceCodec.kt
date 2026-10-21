package com.demo.domain.codec

import kotlinx.coroutines.sync.Mutex

import android.content.Context
import com.demo.core.common.util.Json
import com.demo.core.common.util.MiniJson
import com.demo.domain.repository.BookSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.withLock

object BookSourceCodec {

  fun encode(sources: List<BookSource>): String =
    MiniJson.stringify(MiniJson.arrOf(sources.map { it.toJson() }))

  fun decode(raw: String?): List<BookSource> {
    if (raw.isNullOrBlank()) return emptyList()
    val json = MiniJson.parseOrNull(raw) ?: return emptyList()
    val items = when (json) {
      is Json.Arr -> json.items
      is Json.Obj -> json.arr("sources")?.items ?: listOf(json)
      else -> emptyList()
    }
    return items.mapNotNull { parseOne(it) }.filter { it.valid }
  }

  private fun parseOne(item: Json): BookSource? =
    if (item.str("bookSourceName") != null || item.str("bookSourceUrl") != null)
            parseLegado(item)
    else parseLegacy(item)

  /** Legado（阅读3.0+） */
  private fun parseLegado(item: Json): BookSource? {
    val name = item.str("bookSourceName")?.trim().orEmpty()
    val base = item.str("bookSourceUrl")?.trim().orEmpty()
    if (name.isBlank() || base.isBlank()) return null
    // enabled 缺省视为启用
    if (item.str("enabled") == "false") return null

    val rs = item.obj("ruleSearch")
    val rt = item.obj("ruleToc")
    val rc = item.obj("ruleContent")

    return BookSource(
      id = item.str("id") ?: base,
      name = name,
      baseUrl = base,
      searchUrl = item.str("searchUrl") ?: "",
      charset = item.str("charset") ?: "UTF-8",
      searchListRule = rs?.str("bookList") ?: "",
      titleRule = rs?.str("name") ?: "",
      authorRule = rs?.str("author") ?: "",
      detailUrlRule = rs?.str("bookUrl") ?: "",
      coverRule = rs?.str("coverUrl") ?: "",
      tocListRule = rt?.str("chapterList") ?: "",
      tocTitleRule = rt?.str("chapterName") ?: "",
      tocUrlRule = rt?.str("chapterUrl") ?: "",
      contentRule = rc?.str("content") ?: ""
    )
  }

  /** 旧简化格式 */
  private fun parseLegacy(item: Json): BookSource? {
    val name = item.str("name") ?: return null
    return BookSource(
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
  }

  private fun BookSource.toJson(): Json = MiniJson.objOf(
    "id" to MiniJson.of(id),
    "name" to MiniJson.of(name),
    "baseUrl" to MiniJson.of(baseUrl),
    "searchUrl" to MiniJson.of(searchUrl),
    "charset" to MiniJson.of(charset),
    "searchListRule" to MiniJson.of(searchListRule),
    "titleRule" to MiniJson.of(titleRule),
    "authorRule" to MiniJson.of(authorRule),
    "detailUrlRule" to MiniJson.of(detailUrlRule),
    "coverRule" to MiniJson.of(coverRule),
    "tocListRule" to MiniJson.of(tocListRule),
    "tocTitleRule" to MiniJson.of(tocTitleRule),
    "tocUrlRule" to MiniJson.of(tocUrlRule),
    "contentRule" to MiniJson.of(contentRule)
  )

  private const val ASSET_NAME = "template.json"

  @Volatile
  private var cachedTemplateText: String? = null

  @Volatile
  private var cachedTemplateSources: List<BookSource>? = null

  private val templateMutex = Mutex()


  suspend fun templateText(context: Context): String? {
    cachedTemplateText?.let { return it }
    return templateMutex.withLock {
      cachedTemplateText ?: withContext(Dispatchers.IO) {
        runCatching {
          context.assets.open(ASSET_NAME)
              .bufferedReader(Charsets.UTF_8)
              .use { it.readText() }
        }.getOrNull()
      }?.also { cachedTemplateText = it }
    }
  }

  suspend fun loadTemplateFromAssets(context: Context): List<BookSource> {
    cachedTemplateSources?.let { return it }
    val text = templateText(context) ?: return emptyList()
    val sources = decode(text)
    cachedTemplateSources = sources
    return sources
  }

  fun clearTemplateCache() {
    cachedTemplateText = null
    cachedTemplateSources = null
  }
}
