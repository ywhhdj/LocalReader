package com.demo.core.model

/** 书架视图模式 */
enum class GridMode(val columns: Int) {
  TWO(2),
  THREE(3),
  LIST(1);

  companion object {
    fun fromName(name: String?): GridMode =
      entries.firstOrNull { it.name == name } ?: THREE
  }
}