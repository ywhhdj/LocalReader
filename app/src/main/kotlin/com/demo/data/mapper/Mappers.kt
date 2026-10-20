package com.demo.data.mapper

import com.demo.core.database.entity.BookEntity
import com.demo.core.database.entity.BookGroupEntity
import com.demo.core.database.entity.ReadingProgressEntity
import com.demo.core.model.Book
import com.demo.core.model.BookFormat
import com.demo.core.model.BookGroup
import com.demo.core.model.BookType
import com.demo.core.model.GroupKind
import com.demo.core.model.ReadingProgress

fun BookEntity.toModel(): Book = Book(
    id = id,
    title = title,
    author = author,
    type = BookType.from(type),
    format = BookFormat.from(format),
    filePath = file_path,
    sourceUri = source_uri,
    coverPath = cover_path,
    sizeBytes = size_bytes,
    addedAt = added_at,
    lastReadAt = last_read_at,
    groupId = group_id,
    favorite = favorite == 1,
    progress = progress,
    chapterCount = chapter_count,
    pageCount = page_count,
    metaJson = meta_json
)

fun Book.toEntity(id: Long = this.id): BookEntity = BookEntity(
    id = id,
    title = title,
    author = author,
    type = type.value,
    format = format.value,
    file_path = filePath,
    source_uri = sourceUri,
    cover_path = coverPath,
    size_bytes = sizeBytes,
    added_at = addedAt,
    last_read_at = lastReadAt,
    group_id = groupId,
    favorite = if (favorite) 1 else 0,
    progress = progress,
    chapter_count = chapterCount,
    page_count = pageCount,
    meta_json = metaJson
)

fun BookGroupEntity.toModel(): BookGroup = BookGroup(
    id = id,
    name = name,
    sortOrder = sort_order,
    kind = if (kind == "SYSTEM") GroupKind.SYSTEM else GroupKind.USER,
    createdAt = created_at
)

fun BookGroup.toEntity(): BookGroupEntity = BookGroupEntity(
    id = id,
    name = name,
    sort_order = sortOrder,
    kind = kind.name,
    created_at = createdAt
)

fun ReadingProgressEntity.toModel(): ReadingProgress = ReadingProgress(
    bookId = book_id,
    chapterIndex = chapter_index,
    charOffset = char_offset,
    pageIndex = page_index,
    progress = progress,
    updatedAt = updated_at
)

fun ReadingProgress.toEntity(): ReadingProgressEntity = ReadingProgressEntity(
    book_id = bookId,
    chapter_index = chapterIndex,
    char_offset = charOffset,
    page_index = pageIndex,
    progress = progress,
    updated_at = updatedAt
)
