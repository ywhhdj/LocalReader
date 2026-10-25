package com.demo

import android.app.Application
import android.content.Context
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

  private const val PREFS = "crash_guard"
  private const val KEY_LAST_AT = "last_crash_at"
  private const val KEY_COUNT = "crash_count"
  /** 判定"连续崩溃"的时间窗：比一次冷启动略长，避免把正常启动误判为二次崩溃 */
  private const val REPEAT_WINDOW_MS = 10_000L
  /** 给 startActivity 留出的执行时间 */
  private const val KILL_DELAY_MS = 300L

  fun install(app: Application) {
    val previous = Thread.getDefaultUncaughtExceptionHandler()
    Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
      Logger.e("未捕获异常：${throwable.javaClass.simpleName} ${throwable.message}", throwable, TAG)
      // 崩溃进程随时会被杀，用 SharedPreferences 的同步 commit 记录
      val repeat = runCatching {
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val last = prefs.getLong(KEY_LAST_AT, 0L)
        val count = prefs.getInt(KEY_COUNT, 0)
        val isRepeat = now - last < REPEAT_WINDOW_MS
        prefs.edit()
          .putLong(KEY_LAST_AT, now)
          .putInt(KEY_COUNT, if (isRepeat) count + 1 else 1)
          .commit()
        isRepeat
      }.getOrDefault(false)

      if (!repeat) {
        runCatching {
          val intent = Intent(Intent.ACTION_MAIN).apply {
            setClassName(app, MainActivity::class.java.name)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtra(EXTRA_CRASH, true)
          }
          app.startActivity(intent)
        }.onFailure { Logger.e("重启失败：${it.message}", it, TAG) }
      } else {
        Logger.e("检测到连续崩溃，放弃自动重启（避免崩溃循环）", null, TAG)
      }

      runCatching {
        previous?.uncaughtException(thread, throwable)
      }
      // 延迟杀进程：给 Activity 启动留出时间，且必须在默认 handler 之后执行
      Thread {
        runCatching { Thread.sleep(if (repeat) 0L else KILL_DELAY_MS) }
        Process.killProcess(Process.myPid())
      }.start()
      runCatching { Thread.sleep(KILL_DELAY_MS) }
      Process.killProcess(Process.myPid())
    }
  }

  /** 供启动页提示“上次异常已恢复” */
  const val KEY_CRASH = EXTRA_CRASH
}
