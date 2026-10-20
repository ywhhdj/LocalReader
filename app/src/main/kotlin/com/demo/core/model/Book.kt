package com.demo.core.model

/**
 * 书籍类型：小说 / 漫画
 */
enum class BookType(val value: String) {
    NOVEL("NOVEL"),
    COMIC("COMIC");

    companion object {
        fun from(value: String?): BookType =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: NOVEL
    }
}

/**
 * 文件格式
 */
enum class BookFormat(val value: String, val extensions: List<String>) {
    EPUB("EPUB", listOf("epub")),
    TXT("TXT", listOf("txt", "text")),
    PDF("PDF", listOf("pdf")),
    CBZ("CBZ", listOf("cbz")),
    ZIP("ZIP", listOf("zip")),
    CBR("CBR", listOf("cbr")),
    RAR("RAR", listOf("rar")),
    FOLDER("FOLDER", emptyList()),
    UNKNOWN("UNKNOWN", emptyList());

    companion object {
        fun from(value: String?): BookFormat =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: UNKNOWN

        fun fromExtension(ext: String): BookFormat =
            entries.firstOrNull { it.extensions.any { e -> e.equals(ext, ignoreCase = true) } } ?: UNKNOWN

        /** 受支持的扫描扩展名 */
        fun scanExtensions(): List<String> = entries.flatMap { it.extensions }
    }
}

/**
 * 领域书籍模型（UI / domain 层统一使用）
 */
data class Book(
    val id: Long = 0L,
    val title: String,
    val author: String = "",
    val type: BookType = BookType.NOVEL,
    val format: BookFormat = BookFormat.UNKNOWN,
    /** 文件或目录绝对路径 */
    val filePath: String,
    /** SAF 授权 URI（可选，用于无文件路径权限时读取） */
    val sourceUri: String? = null,
    /** 封面缓存路径（本地文件） */
    val coverPath: String? = null,
    val sizeBytes: Long = 0L,
    val addedAt: Long = System.currentTimeMillis(),
    val lastReadAt: Long = 0L,
    val groupId: Long? = null,
    val favorite: Boolean = false,
    /** 0f..1f */
    val progress: Float = 0f,
    val chapterCount: Int = 0,
    val pageCount: Int = 0,
    /** 解析器附加信息（编码、zip 条目表等 JSON） */
    val metaJson: String? = null
) {
    /** 列表稳定 key */
    val stableKey: String get() = filePath

    val isFinished: Boolean get() = progress >= 0.999f

    fun displayMeta(): String = buildString {
        append(format.value)
        if (type == BookType.NOVEL && chapterCount > 0) append(" · ${chapterCount}章")
        if (type == BookType.COMIC && pageCount > 0) append(" · ${pageCount}页")
    }
}
