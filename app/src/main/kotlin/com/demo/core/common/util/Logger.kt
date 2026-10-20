package com.demo.core.common.util

import android.util.Log

/** 简易日志：release 可通过 setEnabled(false) 关闭 */
object Logger {
    private const val TAG = "LiquidReader"
    @Volatile
    var enabled: Boolean = true

    fun d(msg: String, tag: String = TAG) { 
        if (enabled) Log.d(tag, msg) 
    }
    fun i(msg: String, tag: String = TAG) { 
        if (enabled) Log.i(tag, msg) 
    }
    fun w(msg: String, tag: String = TAG) { 
        if (enabled) Log.w(tag, msg) 
    }
    fun e(msg: String, t: Throwable? = null, tag: String = TAG) { 
        if (enabled) Log.e(tag, msg, t) 
    }
}
