package com.demo.core.database

import android.content.Context
import androidx.room.Room
import androidx.room.RoomDatabase

import com.demo.core.common.util.Constants

/** 数据库构建入口：WAL + 单实例，避免多进程/多实例占用内存 */
object DatabaseProvider {

    @Volatile
    private var instance: AppDatabase? = null

    fun get(context: Context): AppDatabase =
        instance ?: synchronized(this) {
            instance ?: build(context.applicationContext).also { instance = it }
        }

    private fun build(context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, Constants.DB_NAME)
            .setJournalMode(RoomDatabase.JournalMode.WRITE_AHEAD_LOGGING)
            .fallbackToDestructiveMigration()
            .build()
}
