package com.demo.core.model

/** 书架分组 */
data class BookGroup(
    val id: Long = 0L,
    val name: String,
    val sortOrder: Int = 0,
    /** SYSTEM：内置（全部/小说/漫画/收藏）；USER：用户自建 */
    val kind: GroupKind = GroupKind.USER,
    val createdAt: Long = System.currentTimeMillis()
)

enum class GroupKind { SYSTEM, USER }

/** 内置分组 ID 约定（负数避免与自增 ID 冲突） */
object BuiltInGroup {
    const val ALL: Long = -1L
    const val NOVEL: Long = -2L
    const val COMIC: Long = -3L
    const val FAVORITE: Long = -4L

    fun builtIns(): List<BookGroup> = listOf(
        BookGroup(ALL, "全部", 0, GroupKind.SYSTEM),
        BookGroup(NOVEL, "小说", 1, GroupKind.SYSTEM),
        BookGroup(COMIC, "漫画", 2, GroupKind.SYSTEM),
        BookGroup(FAVORITE, "收藏", 3, GroupKind.SYSTEM)
    )
}
