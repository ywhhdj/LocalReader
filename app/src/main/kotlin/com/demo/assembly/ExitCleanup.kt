package com.demo.assembly.cleanup

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.os.Handler
import android.os.Looper

import com.demo.core.common.util.Logger

import java.util.concurrent.atomic.AtomicInteger

/**
 * 「软件关闭」时清理临时文件。
 *
 * CBZ/ZIP/RAR 的解压页、PDF 的渲染页、EPUB 的图片缓存都是**查看时临时生成**的：
 * 不清理的话，看几本漫画就会在内部存储里留下几百 MB 解压产物。
 *
 * 触发时机：
 * - 所有 Activity 都销毁（用户退出 / 从任务列表划掉）→ 延迟 [EXIT_DELAY_MS] 执行，
 *   期间若又启动 Activity（配置变更、误触返回）则取消；
 * - 进程被系统直接杀掉时没有回调，因此 Application 启动时也会补清一次上一轮残留。
 *
 * 清理动作本身由调用方注入（IO 线程执行），这里只负责"什么时候该清"。
 */
class ExitCleanup(private val action: () -> Unit) {

  private val handler = Handler(Looper.getMainLooper())
  private val alive = AtomicInteger(0)
  private var pending: Runnable? = null

  private val callbacks = object : Application.ActivityLifecycleCallbacks {
    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
      cancelPending()
      alive.incrementAndGet()
    }

    override fun onActivityDestroyed(activity: Activity) {
      if (alive.decrementAndGet() <= 0 && activity.isFinishing) schedule()
    }

    override fun onActivityStarted(activity: Activity) = Unit
    override fun onActivityResumed(activity: Activity) = Unit
    override fun onActivityPaused(activity: Activity) = Unit
    override fun onActivityStopped(activity: Activity) = Unit
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
  }

  fun install(app: Application) {
    app.registerActivityLifecycleCallbacks(callbacks)
  }

  private fun schedule() {
    cancelPending()
    val task = Runnable {
      pending = null
      if (alive.get() > 0) return@Runnable
      runCatching { action() }
        .onFailure { Logger.w("退出清理失败：${it.message}", "ExitCleanup") }
    }
    pending = task
    handler.postDelayed(task, EXIT_DELAY_MS)
  }

  private fun cancelPending() {
    pending?.let { handler.removeCallbacks(it) }
    pending = null
  }

  companion object {
    /** 退出后延迟清理：给"配置变更 / 立刻返回"留出取消窗口 */
    const val EXIT_DELAY_MS = 4_000L
  }
}