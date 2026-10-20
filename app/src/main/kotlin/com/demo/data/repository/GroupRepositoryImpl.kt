package com.demo.data.repository

import com.demo.core.database.dao.BookDao
import com.demo.core.database.dao.GroupDao
import com.demo.core.model.BookGroup
import com.demo.data.mapper.toEntity
import com.demo.data.mapper.toModel
import com.demo.domain.repository.GroupRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext

class GroupRepositoryImpl(
    private val groupDao: GroupDao,
    private val bookDao: BookDao
) : GroupRepository {

    override fun observeAll(): Flow<List<BookGroup>> =
        groupDao.observeAll().map { list -> list.map { it.toModel() } }

    override suspend fun all(): List<BookGroup> = withContext(Dispatchers.IO) {
        groupDao.all().map { it.toModel() }
    }

    override suspend fun create(name: String): Long = withContext(Dispatchers.IO) {
        if (name.isBlank()) return@withContext -1L
        if (groupDao.countByName(name) > 0) return@withContext -1L
        val sort = groupDao.all().maxOfOrNull { it.sort_order } ?: 0
        groupDao.insert(BookGroup(name = name, sortOrder = sort + 1).toEntity())
    }

    override suspend fun rename(id: Long, name: String) = withContext(Dispatchers.IO) {
        if (name.isNotBlank()) groupDao.rename(id, name)
    }

    override suspend fun delete(id: Long) = withContext(Dispatchers.IO) {
        bookDao.updateGroup(listOf(id), null) // 该分组的书回到"未分组"
        groupDao.delete(id)
    }
}
