package com.demo

import android.app.Application
import android.os.StrictMode

import coil.Coil

import com.demo.core.common.util.Logger
import com.demo.assembly.di.AppContainer
import com.demo.assembly.di.ImageLoaderFactory

//enum 类型枚举
object BuildConfig {
    const val DEBUG = true
    const val PROD = false
}

class App : Application() {

    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        Logger.enabled = BuildConfig.DEBUG
        if (BuildConfig.DEBUG) enableStrictMode()
        Coil.setImageLoader(ImageLoaderFactory.create(this))
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
