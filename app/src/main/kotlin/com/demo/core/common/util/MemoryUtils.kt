package com.demo.core.common.util

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import kotlin.math.max
import kotlin.math.min

object MemoryUtils {

    /** 是否为低内存设备（影响预加载页数与玻璃特效开关） */
    fun isLowRamDevice(context: Context): Boolean {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        return am?.isLowRamDevice == true
    }

    /** 建议的解码内存上限（字节），约为进程可用内存的 1/8 */
    fun imageBudgetBytes(context: Context): Long {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val info = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(info)
        val avail = if (info.availMem > 0) info.availMem else 256L * 1024 * 1024
        return max(32L * 1024 * 1024, avail / 8)
    }

    /**
     * PDF 单页渲染的长边上限：按设备内存分档。
     * 2048 长边的 ARGB_8888 位图约 16MB，低端机连续翻页很容易 OOM。
     */
    fun pdfPageMaxEdge(context: Context?): Int {
        if (context == null) return 1600
        val lowRam = runCatching { isLowRamDevice(context) }.getOrDefault(false)
        if (lowRam) return 1280
        val budget = imageBudgetBytes(context)
        return if (budget >= 96L * 1024 * 1024) 2048 else 1600
    }

    /** 依据内存等级给出漫画预加载页数：4-6 */
    fun preloadPageCount(context: Context): Int {
        if (isLowRamDevice(context)) return 4
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 4 else 5
    }

    /** 依据屏幕与内存计算图片采样目标宽度 */
    fun targetWidth(screenWidth: Int, context: Context): Int =
        min(screenWidth * if (isLowRamDevice(context)) 1 else 2, 4096)
}
