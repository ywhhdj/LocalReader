package com.demo.core.common.util

object Constants {
    const val DB_NAME = "liquid_reader.db"
    const val DB_VERSION = 1

    const val COVER_DIR = "covers"
    const val BOOK_CACHE_DIR = "bookcache"
    const val PAGE_CACHE_DIR = "pagecache"
    /** SAF 文件物化缓存（Android 11+ 无所有文件权限时使用） */
    const val SAF_CACHE_DIR = "safcache"
    /** WebDAV 备份快照暂存目录 */
    const val BACKUP_DIR = "backup"
    /** 在线书源下载落目录（仅用户主动保存时产生） */
    const val ONLINE_DIR = "online"

    const val COVER_MAX_EDGE = 450
    const val COVER_CACHE_MAX_COUNT = 300
    const val PAGE_CACHE_MAX_COUNT = 120

    const val MAX_FILE_SIZE = 200L * 1024 * 1024
    const val MAX_SCAN_FILES = 20_000
    const val SCAN_MAX_DEPTH = 4

    /** 图片文件夹/压缩包内过小的图片视为封面 logo，不作为漫画页 */
    const val MIN_IMAGE_SIZE = 8 * 1024L
    /** 单本 EPUB 图片解压缓存上限 */
    const val BOOK_IMAGE_CACHE_MAX_BYTES = 20L * 1024 * 1024
    /** PDF 单页渲染像素上限 */
    const val PDF_PAGE_MAX_EDGE = 2048

    const val PROGRESS_SAVE_THROTTLE_MS = 500L
    const val SEARCH_DEBOUNCE_MS = 300L

    val IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "webp", "gif", "bmp", "avif")
}
