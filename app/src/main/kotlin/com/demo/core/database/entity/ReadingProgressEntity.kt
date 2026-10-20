package com.demo.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "reading_progress")
data class ReadingProgressEntity(
    @PrimaryKey val book_id: Long,
    val chapter_index: Int = 0,
    val char_offset: Int = 0,
    val page_index: Int = 0,
    val progress: Float = 0f,
    val updated_at: Long = System.currentTimeMillis()
)
