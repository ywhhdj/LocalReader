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

    /** 依据内存等级给出漫画预加载页数：1~3 */
    fun preloadPageCount(context: Context): Int {
        if (isLowRamDevice(context)) return 1
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 2 else 2
    }

    /** 依据屏幕与内存计算图片采样目标宽度 */
    fun targetWidth(screenWidth: Int, context: Context): Int =
        min(screenWidth * if (isLowRamDevice(context)) 1 else 2, 4096)
}
