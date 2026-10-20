package com.demo.core.database.converter

import androidx.room.TypeConverter

/** 简单列表 ↔ 字符串（zip 条目表等附加信息） */
class Converters {

    @TypeConverter
    fun fromList(value: List<String>?): String? = value?.joinToString("\u0001")

    @TypeConverter
    fun toList(value: String?): List<String>? =
        if (value.isNullOrEmpty()) null else value.split("\u0001")
}
