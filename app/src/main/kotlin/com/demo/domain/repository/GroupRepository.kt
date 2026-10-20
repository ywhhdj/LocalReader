package com.demo.domain.repository

import com.demo.core.model.BookGroup

import kotlinx.coroutines.flow.Flow

interface GroupRepository {
    fun observeAll(): Flow<List<BookGroup>>
    suspend fun all(): List<BookGroup>
    suspend fun create(name: String): Long
    suspend fun rename(id: Long, name: String)
    suspend fun delete(id: Long)
}
