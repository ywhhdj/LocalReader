package com.demo.domain.repository

/** 在线书源规则（正则抽取，零第三方依赖） */
data class BookSource(
    val id: String = "",
    val name: String = "",
    val baseUrl: String = "",
    /** 搜索地址，${key} 为关键词占位符 */
    val searchUrl: String = "",
    val charset: String = "UTF-8",
    /** 搜索结果列表块 */
    val searchListRule: String = "",
    val titleRule: String = "",
    val authorRule: String = "",
    val detailUrlRule: String = "",
    val coverRule: String = "",
    /** 目录页列表块 */
    val tocListRule: String = "",
    val tocTitleRule: String = "",
    val tocUrlRule: String = "",
    /** 正文块 */
    val contentRule: String = ""
) {
    val valid: Boolean get() = name.isNotBlank() && searchUrl.isNotBlank() && searchListRule.isNotBlank()
}

data class OnlineBook(
    val sourceId: String = "",
    val sourceName: String = "",
    val title: String = "",
    val author: String = "",
    val coverUrl: String? = null,
    val detailUrl: String = "",
    val intro: String = ""
)

data class OnlineChapter(
    val index: Int = 0,
    val title: String = "",
    val url: String = ""
)

/**
 * 在线书源（**默认关闭**）。
 * 仅在设置页显式开启并配置书源后可用；关闭时所有方法返回空，不产生任何网络请求。
 */
interface BookSourceRepository {

    /** 是否启用（由设置控制，默认 false） */
    val enabled: Boolean

    /** 已配置的书源 */
    fun sources(): List<BookSource>

    /** 替换书源配置 */
    fun updateSources(sources: List<BookSource>)

    suspend fun search(sourceId: String, keyword: String): List<OnlineBook>

    suspend fun chapters(book: OnlineBook): List<OnlineChapter>

    suspend fun content(book: OnlineBook, chapter: OnlineChapter): List<String>

    /** 抓取整本并另存为 TXT，返回本地文件路径（供导入本地书库） */
    suspend fun saveAsTxt(
        book: OnlineBook,
        chapters: List<OnlineChapter>,
        onProgress: (Int, Int) -> Unit = { _, _ -> }
    ): String?
}
