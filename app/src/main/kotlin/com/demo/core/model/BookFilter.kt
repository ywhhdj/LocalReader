package com.demo.core.model

/** 书架查询条件 */
data class BookFilter(
    val groupId: Long? = null,
    val type: BookType? = null,
    val favoriteOnly: Boolean = false,
    val keyword: String = "",
    val sort: SortOrder = SortOrder.LAST_READ,
    val limit: Int = DEFAULT_PAGE_SIZE,
    val offset: Int = 0
) {
    companion object {
        const val DEFAULT_PAGE_SIZE = 24
        /** 首页横向区块上限，控制内存与首屏耗时 */
        const val RECENT_LIMIT = 12
        const val CONTINUE_LIMIT = 8
        const val GROUP_BLOCK_LIMIT = 6
    }
}

enum class SortOrder {
    LAST_READ, RECENT_ADDED, TITLE, PROGRESS;

    companion object {
        fun from(value: String?): SortOrder =
            entries.firstOrNull { it.name.equals(value, ignoreCase = true) } ?: LAST_READ
    }
}
