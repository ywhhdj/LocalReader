package com.demo.core.database.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "books",
    indices = [
        Index(value = ["file_path"], unique = true),
        Index(value = ["type"]),
        Index(value = ["group_id"]),
        Index(value = ["last_read_at"]),
        Index(value = ["title"])
    ]
)
data class BookEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0L,
    val title: String,
    val author: String = "",
    val type: String,
    val format: String,
    val file_path: String,
    val source_uri: String? = null,
    val cover_path: String? = null,
    val size_bytes: Long = 0L,
    val added_at: Long = System.currentTimeMillis(),
    val last_read_at: Long = 0L,
    val group_id: Long? = null,
    val favorite: Int = 0,
    val progress: Float = 0f,
    val chapter_count: Int = 0,
    val page_count: Int = 0,
    val meta_json: String? = null
)
