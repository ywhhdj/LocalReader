package com.demo.core.common.util

import java.util.concurrent.CopyOnWriteArrayList

/**
 * 内存压力广播（纯 Kotlin，无 Android 依赖）。
 *
 * Application 收到 onTrimMemory / onLowMemory 时调用 [release]，
 * 阅读器等"大内存持有者"注册自己的释放动作：
 * - 小说阅读器：清空章节内容缓存（下次切章重新解析，不影响当前页）；
 * - 漫画阅读器：收缩窗口外的宽高比缓存。
 *
 * 与其等着被 LowMemoryKiller 连进程一起杀掉（阅读进度来不及落库），
 * 不如主动让出可再生的内存。
 */
object MemoryPressure {

    private val listeners = CopyOnWriteArrayList<() -> Unit>()

    /**
     * 注册释放动作，返回取消注册的函数（ViewModel.onCleared 里调用）。
     */
    fun register(onRelease: () -> Unit): () -> Unit {
        listeners.add(onRelease)
        return { listeners.remove(onRelease) }
    }

    /** 逐个通知；单个回调抛异常不影响其余回调 */
    fun release() {
        for (listener in listeners) {
            runCatching { listener.invoke() }
                .onFailure { Logger.w("内存释放失败：${it.message}", "MemoryPressure") }
        }
    }
}
