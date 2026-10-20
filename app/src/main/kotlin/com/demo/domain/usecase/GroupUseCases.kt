package com.demo.domain.usecase

import com.demo.core.model.BookGroup
import com.demo.domain.repository.GroupRepository
import kotlinx.coroutines.flow.Flow

class ObserveGroupsUseCase(private val repo: GroupRepository) {
    operator fun invoke(): Flow<List<BookGroup>> = repo.observeAll()
}

class CreateGroupUseCase(private val repo: GroupRepository) {
    suspend operator fun invoke(name: String): Long = repo.create(name.trim())
}

class RenameGroupUseCase(private val repo: GroupRepository) {
    suspend operator fun invoke(id: Long, name: String) = repo.rename(id, name.trim())
}

class DeleteGroupUseCase(private val repo: GroupRepository) {
    suspend operator fun invoke(id: Long) = repo.delete(id)
}
