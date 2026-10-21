package com.demo.data.source

import com.demo.core.common.util.FileUtil
import com.demo.core.common.util.Logger
import com.demo.core.common.util.SimpleHttp
import com.demo.core.model.AppSettings
import com.demo.domain.codec.BookSourceCodec
import com.demo.domain.repository.BookSource
import com.demo.domain.repository.BookSourceRepository
import com.demo.domain.repository.OnlineBook
import com.demo.domain.repository.OnlineChapter
import com.demo.domain.repository.SettingsRepository
import java.io.File
import java.net.URLEncoder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 在线书源实现（**默认关闭**）。
 *
 * 安全/合规约定：
 * - 关闭状态下所有方法直接返回空，不产生任何网络请求；
 * - 仅使用用户自行配置的书源（设置页粘贴 JSON），应用不内置任何第三方站点；
 * - 抓取结果只能"另存为 TXT 到本地书库"，不进入在线阅读缓存。
 */
class BookSourceRepositoryImpl(
        private val settingsRepository: SettingsRepository,
        private val onlineDir: File
) : BookSourceRepository {

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

  @Volatile private var settings: AppSettings = AppSettings()

  @Volatile private var cachedSources: List<BookSource> = emptyList()

  init {
    onlineDir.mkdirs()
    scope.launch {
      settingsRepository.observe().collectLatest {
        settings = it
        cachedSources = BookSourceCodec.decode(it.onlineSourceJson)
      }
    }
  }

  override val enabled: Boolean
    get() = settings.onlineSourceEnabled

  override fun sources(): List<BookSource> = if (enabled) cachedSources else emptyList()

  override fun updateSources(sources: List<BookSource>) {
    cachedSources = sources
    scope.launch {
      settingsRepository.update {
        it.copy(onlineSourceJson = BookSourceCodec.encode(sources)) 
      }
    }
  }

  override suspend fun search(sourceId: String, keyword: String): List<OnlineBook> = withContext(Dispatchers.IO) {
    if (!enabled || keyword.isBlank()) return@withContext emptyList()
    val source = sources().firstOrNull { it.id == sourceId } ?: sources().firstOrNull()
      ?: return@withContext emptyList()
    val all = ArrayList<OnlineBook>()
    // 最多翻 3 页（Legado 默认行为）
    for (page in 1..3) {
        val url = buildSearchUrl(source, keyword, page) ?: break
        val html = runCatching { SimpleHttp.getText(url, UA) }.getOrNull() ?: break
        val batch = RuleEngine.list(html, source.searchListRule).mapNotNull { block ->
            val title = RuleEngine.first(block, source.titleRule) ?: return@mapNotNull null
            val detail = RuleEngine.first(block, source.detailUrlRule)
              ?.let { RuleEngine.absolute(source.baseUrl, it) } ?: return@mapNotNull null
            OnlineBook(
              sourceId = source.id,
              sourceName = source.name,
              title = title,
              author = RuleEngine.first(block, source.authorRule).orEmpty(),
              coverUrl = RuleEngine.first(block, source.coverRule)?.let { RuleEngine.absolute(source.baseUrl, it) },
              detailUrl = detail
            )
        }.distinctBy { it.detailUrl }
        if (batch.isEmpty()) break
        all.addAll(batch.filter { it.detailUrl !in all.map { b -> b.detailUrl } })
        if (all.size >= 60) break
    }
    all.distinctBy { it.detailUrl }
  }
  override suspend fun chapters(book: OnlineBook): List<OnlineChapter> =
  withContext(Dispatchers.IO) {
    if (!enabled) return@withContext emptyList()
    val source =
            sources().firstOrNull { it.id == book.sourceId }
                    ?: return@withContext emptyList()
    val html =
            runCatching { SimpleHttp.getText(book.detailUrl, UA) }.getOrNull()
                    ?: return@withContext emptyList()
    val rule = source.tocListRule.ifBlank { source.searchListRule }
    return@withContext RuleEngine.list(html, rule)
      .mapNotNull { block ->
        val title =
          RuleEngine.first(
            block,
            source.tocTitleRule.ifBlank { source.titleRule }
          )
        val url =
          RuleEngine.first(
            block,
            source.tocUrlRule.ifBlank { source.detailUrlRule }
          )?.let { RuleEngine.absolute(source.baseUrl, it) }
        if (title.isNullOrBlank() || url.isNullOrBlank()) return@mapNotNull null
        OnlineChapter(index = 0, title = title, url = url)
      }
      .mapIndexed { i, c -> c.copy(index = i) }
      .distinctBy { it.url }
  }

  override suspend fun content(book: OnlineBook, chapter: OnlineChapter): List<String> =
          withContext(Dispatchers.IO) {
            if (!enabled) return@withContext emptyList()
            val source =
                    sources().firstOrNull { it.id == book.sourceId }
                            ?: return@withContext emptyList()
            val html =
                    runCatching { SimpleHttp.getText(chapter.url, UA) }.getOrNull()
                            ?: return@withContext emptyList()
            RuleEngine.content(html, source.contentRule)
          }

  /** 抓取整本并另存为 TXT，返回本地文件路径（供导入书库） */
  override suspend fun saveAsTxt(
          book: OnlineBook,
          chapters: List<OnlineChapter>,
          onProgress: (Int, Int) -> Unit
  ): String? =
          withContext(Dispatchers.IO) {
            if (!enabled || chapters.isEmpty()) return@withContext null
            val source = sources().firstOrNull { it.id == book.sourceId } ?: return@withContext null
            val file = File(onlineDir, FileUtil.safeFileName(book.title) + ".txt")
            runCatching {
                      file.bufferedWriter(Charsets.UTF_8).use { writer ->
                        writer.write(book.title)
                        writer.newLine()
                        if (book.author.isNotBlank()) {
                          writer.write("作者：${book.author}")
                          writer.newLine()
                        }
                        writer.newLine()
                        chapters.forEachIndexed { i, chapter ->
                          writer.write(chapter.title)
                          writer.newLine()
                          writer.newLine()
                          val html = runCatching { SimpleHttp.getText(chapter.url, UA) }.getOrNull()
                          val paragraphs =
                                  html?.let { RuleEngine.content(it, source.contentRule) }.orEmpty()
                          paragraphs.forEach { p ->
                            writer.write(p)
                            writer.newLine()
                          }
                          writer.newLine()
                          onProgress(i + 1, chapters.size)
                        }
                      }
                      file.absolutePath
                    }
                    .onFailure { Logger.w("保存在线书籍失败：${it.message}", "BookSource") }
                    .getOrNull()
          }

  private fun buildSearchUrl(source: BookSource, keyword: String, page: Int = 1): String? {
    val encoded = runCatching { 
      URLEncoder.encode(keyword, source.charset.ifBlank { "UTF-8" })
    }.getOrDefault(keyword)
    val url = source.searchUrl
      .replace("{{key}}", encoded)
      .replace("\${key}", encoded)
      .replace("{key}", encoded)
      .replace("{{page}}", page.toString())
      .replace("\${page}", page.toString())
      .replace("{page}", page.toString())
    return if (url.startsWith("http")) url
    else RuleEngine.absolute(source.baseUrl, url).takeIf { it.startsWith("http") }
  }

  private val UA: Map<String, String> =
    mapOf(
      "User-Agent" to "Mozilla/5.0 (Linux; Android) LiquidReader",
      "Accept" to "text/html,*/*"
    )
}
