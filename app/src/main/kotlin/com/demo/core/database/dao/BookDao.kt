package com.demo.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import androidx.room.Upsert

import com.demo.core.database.entity.BookEntity

import kotlinx.coroutines.flow.Flow

@Dao
interface BookDao {

    /** 按最后阅读排序分页（书架主网格） */
    @Query(
        """SELECT * FROM books
           WHERE (:groupId IS NULL OR group_id = :groupId)
             AND (:type IS NULL OR type = :type)
             AND (:favoriteOnly = 0 OR favorite = 1)
             AND (:keyword = '' OR title LIKE '%' || :keyword || '%' ESCAPE '\\' OR author LIKE '%' || :keyword || '%' ESCAPE '\\')
           ORDER BY last_read_at DESC, added_at DESC
           LIMIT :limit OFFSET :offset"""
    )
    fun pagedByLastRead(
        groupId: Long?, type: String?, favoriteOnly: Int, keyword: String, limit: Int, offset: Int
    ): List<BookEntity>

    @Query(
        """SELECT * FROM books
           WHERE (:groupId IS NULL OR group_id = :groupId)
             AND (:type IS NULL OR type = :type)
             AND (:favoriteOnly = 0 OR favorite = 1)
             AND (:keyword = '' OR title LIKE '%' || :keyword || '%' ESCAPE '\\' OR author LIKE '%' || :keyword || '%' ESCAPE '\\')
           ORDER BY added_at DESC
           LIMIT :limit OFFSET :offset"""
    )
    fun pagedByRecentAdded(
        groupId: Long?, type: String?, favoriteOnly: Int, keyword: String, limit: Int, offset: Int
    ): List<BookEntity>

    @Query(
        """SELECT * FROM books
           WHERE (:groupId IS NULL OR group_id = :groupId)
             AND (:type IS NULL OR type = :type)
             AND (:favoriteOnly = 0 OR favorite = 1)
             AND (:keyword = '' OR title LIKE '%' || :keyword || '%' ESCAPE '\\' OR author LIKE '%' || :keyword || '%' ESCAPE '\\')
           ORDER BY title COLLATE NOCASE ASC
           LIMIT :limit OFFSET :offset"""
    )
    fun pagedByTitle(
        groupId: Long?, type: String?, favoriteOnly: Int, keyword: String, limit: Int, offset: Int
    ): List<BookEntity>

    @Query(
        """SELECT * FROM books
           WHERE (:groupId IS NULL OR group_id = :groupId)
             AND (:type IS NULL OR type = :type)
             AND (:favoriteOnly = 0 OR favorite = 1)
             AND (:keyword = '' OR title LIKE '%' || :keyword || '%' ESCAPE '\\' OR author LIKE '%' || :keyword || '%' ESCAPE '\\')
           ORDER BY progress DESC, last_read_at DESC
           LIMIT :limit OFFSET :offset"""
    )
    fun pagedByProgress(
        groupId: Long?, type: String?, favoriteOnly: Int, keyword: String, limit: Int, offset: Int
    ): List<BookEntity>

    /** 在读（进度 >0 且 <1），用于首页"继续阅读" */
    @Query(
        """SELECT * FROM books
           WHERE progress > 0.001 AND progress < 0.999
           ORDER BY last_read_at DESC LIMIT :limit"""
    )
    fun continueReading(limit: Int): List<BookEntity>

    @Query("SELECT * FROM books WHERE favorite = 1 ORDER BY last_read_at DESC LIMIT :limit")
    fun favorites(limit: Int): List<BookEntity>

    @Query("SELECT * FROM books WHERE id = :id")
    suspend fun byId(id: Long): BookEntity?

    @Query("SELECT * FROM books WHERE file_path = :path LIMIT 1")
    suspend fun byPath(path: String): BookEntity?

    @Query("SELECT file_path FROM books")
    suspend fun allPaths(): List<String>

    /** 已入库书籍的 SAF 源 URI：用于回收孤儿物化缓存 */
    @Query("SELECT source_uri FROM books WHERE source_uri IS NOT NULL AND source_uri != ''")
    suspend fun allSourceUris(): List<String>

    /** 全量导出（备份） */
    @Query("SELECT * FROM books ORDER BY id ASC")
    suspend fun all(): List<BookEntity>

    @Query("SELECT COUNT(*) FROM books")
    suspend fun count(): Int

    @Query("SELECT COUNT(*) FROM books WHERE type = :type")
    suspend fun countByType(type: String): Int

    @Query("SELECT COUNT(*) FROM books WHERE progress >= 0.999")
    suspend fun finishedCount(): Int

    @Query("SELECT COUNT(*) FROM books WHERE progress > 0.001 AND progress < 0.999")
    suspend fun readingCount(): Int

    @Query("SELECT * FROM books WHERE progress >= 0.999 ORDER BY last_read_at DESC LIMIT :limit")
    suspend fun recentFinished(limit: Int): List<BookEntity>

    @Upsert
    suspend fun upsert(book: BookEntity): Long

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertAll(books: List<BookEntity>): List<Long>

    @Update
    suspend fun update(book: BookEntity)

    @Query("UPDATE books SET group_id = :groupId WHERE id IN (:ids)")
    suspend fun updateGroup(ids: List<Long>, groupId: Long?)

    @Query("UPDATE books SET favorite = :favorite WHERE id IN (:ids)")
    suspend fun updateFavorite(ids: List<Long>, favorite: Int)

    @Query("UPDATE books SET progress = :progress, last_read_at = :time WHERE id = :id")
    suspend fun updateProgress(id: Long, progress: Float, time: Long)

    @Query("DELETE FROM books WHERE id IN (:ids)")
    suspend fun deleteByIds(ids: List<Long>)

    @Query("DELETE FROM books WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("SELECT * FROM books ORDER BY added_at DESC LIMIT :limit")
    fun observeRecent(limit: Int): Flow<List<BookEntity>>

    @Query(
        """SELECT * FROM books
           WHERE (:groupId IS NULL OR group_id = :groupId)
             AND (:type IS NULL OR type = :type)
           ORDER BY last_read_at DESC LIMIT :limit"""
    )
    fun observeShelf(groupId: Long?, type: String?, limit: Int): Flow<List<BookEntity>>

    /**
     * 当前筛选下的书籍总数（Flow）。
     * 书架用它做"库是否变了"的信号：Room 会在 books 表发生写入后重新发射，
     * 因此删书 / 改分组 / 导入后首页能自动刷新，不再依赖调用方手动 refresh()。
     */
    @Query(
        """SELECT COUNT(*) FROM books
           WHERE (:groupId IS NULL OR group_id = :groupId)
             AND (:type IS NULL OR type = :type)
             AND (:favoriteOnly = 0 OR favorite = 1)"""
    )
    fun observeCount(groupId: Long?, type: String?, favoriteOnly: Int): Flow<Int>

    @Transaction
    suspend fun replaceAll(books: List<BookEntity>) {
        books.forEach { upsert(it) }
    }
}
