package com.demo

import android.app.Application
import android.content.Intent
import android.os.Process

import com.demo.core.common.util.Logger

/**
 * 崩溃兜底：记录完整堆栈后重启到首页，避免"阅读中直接强退"。
 * 真正的问题仍需按日志修复，这里只保证应用不卡在崩溃状态。
 */
object CrashGuard {

  private const val EXTRA_CRASH = "extra_crash"
  private const val TAG = "CrashGuard"

  fun install(app: Application) {
    val previous = Thread.getDefaultUncaughtExceptionHandler()
    Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
      Logger.e("未捕获异常：${throwable.javaClass.simpleName} ${throwable.message}", throwable, TAG)
      runCatching {
        val intent = Intent(Intent.ACTION_MAIN).apply {
          setClassName(app, MainActivity::class.java.name)
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
          putExtra(EXTRA_CRASH, true)
        }
        app.startActivity(intent)
      }.onFailure { Logger.e("重启失败：${it.message}", it, TAG) }
      runCatching { 
        previous?.uncaughtException(thread, throwable) 
      }
      Process.killProcess(Process.myPid())
    }
  }

  /** 供启动页提示“上次异常已恢复” */
  const val KEY_CRASH = EXTRA_CRASH
}
