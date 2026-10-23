package com.demo.core.common.util

import android.app.ActivityManager
import android.content.Context
import android.os.Build

/**
 * 设备分级：给「动效 / 帧率 / 玻璃模糊」提供默认档位。
 *
 * 判定依据（不联网、不读取敏感信息）：
 * - `ActivityManager.isLowRamDevice`：系统级低端标记；
 * - `MemoryInfo.totalMem`：物理内存；
 * - `Runtime.availableProcessors()`：核心数；
 * - 系统「动画缩放」为 0：说明用户已主动关闭动画（无障碍诉求），直接按最低档处理。
 *
 * 分级只用于给默认值，用户可以在设置里手动覆盖。
 */
enum class DeviceTier { LOW, MID, HIGH }

object DeviceTierDetector {

    private const val RAM_LOW_MB = 3_072      // < 3GB 视为低端
    private const val RAM_HIGH_MB = 6_144     // >= 6GB 视为高端
    private const val CORES_LOW = 4
    private const val CORES_HIGH = 8

    @Volatile
    private var cached: DeviceTier? = null

    fun detect(context: Context): DeviceTier {
        cached?.let { return it }
        val tier = runCatching { compute(context) }.getOrDefault(DeviceTier.MID)
        cached = tier
        return tier
    }

    private fun compute(context: Context): DeviceTier {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        if (am != null && runCatching { am.isLowRamDevice }.getOrDefault(false)) {
            return DeviceTier.LOW
        }
        val totalMb = am?.let {
            val info = ActivityManager.MemoryInfo()
            runCatching { it.getMemoryInfo(info) }
            info.totalMem
        }?.let { it / (1024 * 1024) } ?: 0L
        val cores = Runtime.getRuntime().availableProcessors()
        val score = (if (totalMb >= RAM_HIGH_MB) 2 else if (totalMb >= RAM_LOW_MB) 1 else 0) +
            (if (cores >= CORES_HIGH) 1 else if (cores >= CORES_LOW) 0 else -1)
        val tier = when {
            score >= 3 -> DeviceTier.HIGH
            score <= 0 -> DeviceTier.LOW
            else -> DeviceTier.MID
        }
        // 用户在系统里关掉动画 → 尊重系统设置，按最低档给默认
        val animationsOff = runCatching {
            android.provider.Settings.Global.getFloat(
                context.contentResolver,
                android.provider.Settings.Global.ANIMATOR_DURATION_SCALE,
                1f
            ) == 0f
        }.getOrDefault(false)
        return if (animationsOff) DeviceTier.LOW else tier
    }

    /** 该档位是否默认开启界面动效 */
    fun suggestAnimations(tier: DeviceTier): Boolean = tier != DeviceTier.LOW

    /** 该档位建议的持续动画帧率（fps） */
    fun suggestFps(tier: DeviceTier): Int = when (tier) {
        DeviceTier.LOW -> 30
        DeviceTier.MID -> 30
        DeviceTier.HIGH -> 60
    }

    /** 该档位是否允许真实模糊（RenderEffect）——低端机直接降级为静态玻璃 */
    fun suggestBlur(tier: DeviceTier): Boolean = tier == DeviceTier.HIGH

    /** 系统版本是否支持 RenderEffect 模糊 */
    fun blurSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
}
