package com.demo.core.database.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "reading_sessions",
    indices = [Index(value = ["start_at"]), Index(value = ["book_id"])]
)
data class ReadingSessionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0L,
    val book_id: Long,
    val start_at: Long,
    val duration_ms: Long,
    val type: String = "NOVEL"
)
