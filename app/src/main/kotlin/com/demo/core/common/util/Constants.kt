package com.demo.core.common.util

object Constants {
    const val DB_NAME = "liquid_reader.db"
    const val DB_VERSION = 1

    const val COVER_DIR = "covers"
    const val BOOK_CACHE_DIR = "bookcache"
    const val PAGE_CACHE_DIR = "pagecache"

    const val COVER_MAX_EDGE = 450
    const val COVER_CACHE_MAX_COUNT = 300
    const val PAGE_CACHE_MAX_COUNT = 120

    const val MAX_FILE_SIZE = 200L * 1024 * 1024
    const val MAX_SCAN_FILES = 20_000
    const val SCAN_MAX_DEPTH = 4

    const val PROGRESS_SAVE_THROTTLE_MS = 500L
    const val SEARCH_DEBOUNCE_MS = 300L

    val IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "webp", "gif", "bmp", "avif")
}
