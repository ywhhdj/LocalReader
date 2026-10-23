package com.demo

import android.app.Application
import android.content.ComponentCallbacks2
import android.content.res.Configuration
import android.os.StrictMode

import coil.Coil

import com.demo.core.common.util.Logger
import com.demo.assembly.di.AppContainer
import com.demo.assembly.di.ImageLoaderFactory

//构建配置
object BuildConfig {
    val DEBUG = false
}

class App : Application() {

    lateinit var container: AppContainer
        private set

    /**
     * 内存紧张时主动让出可再生内存：
     * - 先通知业务侧（阅读器章节缓存等）自行收缩；
     * - 再按系统等级裁剪 Coil 内存缓存。
     * 与其等 LMK 连进程一起杀掉（阅读进度来不及落库），不如提前让出。
     */
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        com.demo.core.common.util.MemoryPressure.release()
        runCatching {
            val cache = Coil.imageLoader(this).memoryCache
            when {
                level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL -> cache?.clear()
                level >= ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN -> cache?.trimMemory(50)
                else -> cache?.trimMemory(25)
            }
        }
    }

    override fun onLowMemory() {
        super.onLowMemory()
        com.demo.core.common.util.MemoryPressure.release()
        runCatching { Coil.imageLoader(this).memoryCache?.clear() }
    }

    override fun onCreate() {
        super.onCreate()
        Logger.enabled = BuildConfig.DEBUG
        if (BuildConfig.DEBUG) enableStrictMode()
        Coil.setImageLoader(ImageLoaderFactory.create(this))
        CrashGuard.install(this)
        container = AppContainer(this)
    }

    private fun enableStrictMode() {
        StrictMode.setThreadPolicy(
            StrictMode.ThreadPolicy.Builder()
                .detectDiskReads()
                .detectDiskWrites()
                .penaltyLog()
                .build()
        )
        StrictMode.setVmPolicy(
            StrictMode.VmPolicy.Builder()
                .detectLeakedClosableObjects()
                .penaltyLog()
                .build()
        )
    }
}
