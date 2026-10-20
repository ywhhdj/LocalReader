package com.demo.core.model

/**
 * 漫画章节
 */
data class ComicChapter(
  val index: Int,
  val title: String,
  val pageCount: Int = 0,
  val path: String = "",
  val startIndex: Int = 0,
  val endIndex: Int = 0
) {
  operator fun contains(pageIndex: Int): Boolean =
        pageIndex in startIndex..endIndex

  companion object {
    /** 单章节标题 */
    const val SINGLE_TITLE: String = "单话"
  }
}