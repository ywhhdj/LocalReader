package com.demo.core.database

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters

import com.demo.core.database.converter.Converters
import com.demo.core.database.dao.BookDao
import com.demo.core.database.dao.GroupDao
import com.demo.core.database.dao.ProgressDao
import com.demo.core.database.dao.SessionDao
import com.demo.core.database.entity.BookEntity
import com.demo.core.database.entity.BookGroupEntity
import com.demo.core.database.entity.ReadingProgressEntity
import com.demo.core.database.entity.ReadingSessionEntity

@Database(
    entities = [
        BookEntity::class,
        BookGroupEntity::class,
        ReadingProgressEntity::class,
        ReadingSessionEntity::class
    ],
    version = 1,
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun bookDao(): BookDao
    abstract fun groupDao(): GroupDao
    abstract fun progressDao(): ProgressDao
    abstract fun sessionDao(): SessionDao
}
