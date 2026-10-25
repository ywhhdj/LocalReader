package com.demo.core.common.util

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object FormatUtil {

    fun formatBytes(bytes: Long): String {
        if (bytes <= 0) return "0 B"
        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        var value = bytes.toDouble()
        var idx = 0
        while (value >= 1024 && idx < units.lastIndex) {
            value /= 1024
            idx++
        }
        return if (idx == 0) "$bytes B" else String.format(Locale.getDefault(), "%.1f %s", value, units[idx])
    }

    /** 毫秒 → 人类可读时长 */
    fun formatDuration(millis: Long): String {
        if (millis <= 0) return "0 分钟"
        val totalSec = millis / 1000
        val h = totalSec / 3600
        val m = (totalSec % 3600) / 60
        val s = totalSec % 60
        return when {
            h > 0 -> if (m > 0) "${h}小时${m}分" else "${h}小时"
            m > 0 -> if (s > 0 && m < 10) "${m}分${s}秒" else "${m}分钟"
            else -> "${s}秒"
        }
    }

    fun formatDate(millis: Long): String =
        if (millis <= 0) "-" else SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(millis))

    fun formatDateTime(millis: Long): String =
        if (millis <= 0) "-" else SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date(millis))

    fun formatPercent(progress: Float): String = "${(progress * 100).toInt()}%"

    /** 今日 00:00 时间戳 */
    fun startOfToday(now: Long = System.currentTimeMillis()): Long {
        val cal = java.util.Calendar.getInstance().apply { timeInMillis = now }
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        cal.set(java.util.Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    /**
     * 当前本地时区相对 UTC 的偏移毫秒（含夏令时）。
     * SQL 分组需要与 Kotlin 侧使用同一偏移，否则"今日时长 / 柱状图 / 连续天数"三者口径不一致
     * （东八区下会变成以本地早上 8:00 分界）。
     */
    fun zoneOffsetMillis(now: Long = System.currentTimeMillis()): Long =
        java.util.TimeZone.getDefault().getOffset(now).toLong()

    /**
     * 本地日键。必须与 SQL 端 `(start_at + :offset) / 86400000` 保持同一公式，
     * 且与 [startOfToday]（本地零点）对齐。
     */
    fun dayKey(millis: Long): Long = (millis + zoneOffsetMillis(millis)) / 86_400_000L

    fun weekdayLabel(millis: Long): String =
        SimpleDateFormat("EEE", Locale.getDefault()).format(Date(millis))
}
