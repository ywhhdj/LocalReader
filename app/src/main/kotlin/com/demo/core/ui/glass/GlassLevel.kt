package com.demo.core.ui.glass

/** 液态玻璃强度：Off 时完全关闭实时模糊（低配机省电） */
enum class GlassLevel(val blurRadiusDp: Int, val tintAlpha: Float) {
  OFF(0, 0.14f),
  LOW(10, 0.12f),
  MEDIUM(18, 0.14f),
  HIGH(28, 0.16f);

  companion object {
    fun from(value: String?): GlassLevel =
        entries.firstOrNull { it.name.equals(value, ignoreCase = true) } ?: MEDIUM
  }
}