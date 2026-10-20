package com.demo.core.database.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "book_groups",
    indices = [Index(value = ["name"], unique = true)]
)
data class BookGroupEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0L,
    val name: String,
    val sort_order: Int = 0,
    val kind: String = "USER",
    val created_at: Long = System.currentTimeMillis()
)
