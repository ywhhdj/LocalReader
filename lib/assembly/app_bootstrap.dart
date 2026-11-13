import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, runApp;

import '../app.dart';
import '../core/common/device_tier.dart';
import '../core/common/memory_utils.dart';
import '../crash_guard.dart';
import '../data/platform/persistence.dart' show CrashRecord, CrashRecordStore;
import '../data/platform/sqlite_runtime.dart' show SqliteRuntime;

/// 对应原 Kotlin 工程 `App.kt`：图片缓存（Coil）/ 崩溃兜底 / 容器 / 内存裁剪，
/// 以及 `assembly/` 的启动装配职责。`main.dart` 只负责调 [run]，不散写初始化。
///
/// 退出清理仍由 `AppState.dispose()` 与 `Wenku8Bootstrap` 的关闭钩子承担，
/// 这里不重复注册一份，避免「两处都以为自己负责清理」。
class AppBootstrap {
  const AppBootstrap._();

  static const CrashGuardPolicy _crashPolicy = CrashGuardPolicy();

  /// 连续崩溃计数走全应用共享的 KV 缓存；SQLite 未开启时只写内存，
  /// 开启后由门控层统一落盘，不再在启动时查库。
  static final CrashRecordStore _crashRecords =
      CrashRecordStore(SqliteRuntime.instance.prefs);
  static bool _crashHooked = false;

  /// 静态阶段没有平台设备通道，按「未知设备」取最保守预算；
  /// 接 SDK 后由 `AppServices.detectCapability()` 填 [DeviceCapability] 再分档。
  static MemoryBudget run({DeviceCapability capability = DeviceCapability.unknown}) {
    WidgetsFlutterBinding.ensureInitialized();

    // 1) 崩溃兜底：框架错误与平台未捕获错误都进同一条记录链。
    //    SQLite 属可选初始化 —— 启动阶段**不查库**；只有用户代码显式开启
    //    SQLite 之后，才从已预热的记录里恢复一次「连续崩溃」判据。
    if (!_crashHooked) {
      _crashHooked = true;
      SqliteRuntime.instance.addOnEnabled(_restoreCrashGuard);
    }
    CrashGuard.install(_crashPolicy, onCrash: (Object error, StackTrace stack) {
      unawaited(_recordCrash(error, stack));
    });

    // 2) 内存裁剪：预算只在这里落到 Flutter binding，业务层不碰 imageCache。
    final MemoryBudget budget =
        MemoryBudget.resolve(DeviceTierResolver.classify(capability));
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSizeBytes = budget.maxImageCacheBytes;
    imageCache.maximumSize = budget.maxImageCacheEntries;

    // 3) 容器装配：DI / 路由 / 主题都挂在 LocalReaderApp 内部。
    runApp(const LocalReaderApp());
    return budget;
  }

  static String _lastCrashSignature = '';
  static int _lastCrashAtMs = 0;

  static Future<void> _recordCrash(Object error, StackTrace stack) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    // 同一条异常在极短时间内重复上报（例如同一帧的多处错误）只记一次，
    // 避免日志与计数被刷爆。
    final String signature = '${error.runtimeType}:$error';
    if (signature == _lastCrashSignature && now - _lastCrashAtMs < 2000) {
      return;
    }
    _lastCrashSignature = signature;
    _lastCrashAtMs = now;
    final CrashRecord previous = await _crashRecords.load();
    final int windowMs = _crashPolicy.window.inMilliseconds;
    // 只有「窗口内连续」才算一次连崩；超出窗口就重新起一条链。
    final bool chained = previous.count > 0 && now - previous.lastAtMs <= windowMs;
    final CrashRecord next = CrashRecord(
      count: (chained ? previous.count : 0) + 1,
      firstAtMs: chained ? previous.firstAtMs : now,
      lastAtMs: now,
    );
    await _crashRecords.save(next);
    debugPrint('[CrashGuard] 未捕获异常 ${next.count} 次 / '
        '阈值 ${_crashPolicy.threshold}（窗口 '
        '${_crashPolicy.window.inMinutes} 分钟）；'
        '布局溢出与框架断言不计入');
  }

  static Future<void> _restoreCrashGuard() async {
    final CrashRecord record = await _crashRecords.load();
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int windowMs = _crashPolicy.window.inMilliseconds;
    if (record.count >= _crashPolicy.threshold &&
        now - record.lastAtMs <= windowMs) {
      CrashGuard.safeModeActive = true;
      debugPrint('[CrashGuard] 进入${_crashPolicy.safeModeLabel}：'
          '跳过 ${CrashGuard.skippedInSafeMode.join(' / ')}');
    } else if (record.count > 0 && now - record.firstAtMs > windowMs * 2) {
      // 稳定跑过两个窗口后清零，避免一次历史连崩永久锁死安全模式。
      await _crashRecords.clear();
    }
  }
}

/// 崩溃兜底注册入口，薄封装在 CrashGuard 里，这里保留一个统一引用点。
void installCrashGuard(CrashGuardPolicy policy) => CrashGuard.install(policy);
