package com.demo.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.demo.core.database.entity.BookGroupEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface GroupDao {

    @Query("SELECT * FROM book_groups ORDER BY sort_order ASC, id ASC")
    fun observeAll(): Flow<List<BookGroupEntity>>

    @Query("SELECT * FROM book_groups ORDER BY sort_order ASC, id ASC")
    suspend fun all(): List<BookGroupEntity>

    @Query("SELECT * FROM book_groups WHERE id = :id")
    suspend fun byId(id: Long): BookGroupEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(group: BookGroupEntity): Long

    @Query("UPDATE book_groups SET name = :name WHERE id = :id")
    suspend fun rename(id: Long, name: String)

    @Query("DELETE FROM book_groups WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("SELECT COUNT(*) FROM book_groups WHERE name = :name")
    suspend fun countByName(name: String): Int
}
