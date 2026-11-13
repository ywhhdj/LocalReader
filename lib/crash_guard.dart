import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';

/// 连续崩溃保护（第二十四轮）。
///
/// 原项目工程结构里列了 `CrashGuard.kt（含连续崩溃保护）`，Flutter 侧一直只有
/// `main.dart` 的 TODO。本层把**判据**收成纯 Dart：时间窗内连续崩溃达到阈值，
/// 下次启动进安全模式（跳过可选初始化、保留最小可读路径）。
///
/// 框架回调注册由 `assembly/app_bootstrap.dart` 在启动时调用 [install]；
/// 判据本身仍是纯 Dart，连续崩溃的持久化接平台存储（平台实现）。
@immutable
class CrashGuardPolicy {
  const CrashGuardPolicy({
    this.threshold = 3,
    this.window = const Duration(minutes: 5),
    this.safeModeLabel = '安全模式',
  });

  final int threshold;
  final Duration window;
  final String safeModeLabel;
}

@immutable
class CrashGuard {
  const CrashGuard({
    this.timestamps = const <int>[],
    this.policy = const CrashGuardPolicy(),
  });

  /// 用「距启动的毫秒数」而非 `DateTime.now()`，便于规格单测固定时钟，
  /// 也避免真机时区/系统时间改动影响窗口判定。
  final List<int> timestamps;
  final CrashGuardPolicy policy;

  CrashGuard record(int elapsedMs) {
    final List<int> next = <int>[...timestamps, elapsedMs]
      ..sort();
    final int cutoff = elapsedMs - policy.window.inMilliseconds;
    return CrashGuard(
      timestamps: List<int>.unmodifiable(
        next.where((int t) => t >= cutoff),
      ),
      policy: policy,
    );
  }

  bool get shouldEnterSafeMode => timestamps.length >= policy.threshold;

  CrashGuard reset() => CrashGuard(policy: policy);

  int get recentCount => timestamps.length;

  /// 框架「可恢复错误」判据。
  ///
  /// Debug 下 `RenderFlex overflowed`、`Navigator operation requested with a
  /// context that does not include a Navigator` 这类断言会**每帧 / 每次点击**
  /// 走一次 `FlutterError.onError`，但 isolate 并没有终止，用户仍可继续操作。
  /// 把它们计入「连续崩溃」会在几秒内把计数刷到阈值、误触发安全模式——
  /// 真机日志里一次 12px 溢出被累计到 15 次就是这个原因。
  ///
  /// 这类错误仍然 `presentError` 方便排查，但不再进崩溃计数；
  /// 真正的未捕获 Dart 异常由 `PlatformDispatcher.onError` 单独记录。
  static bool isRecoverableFrameworkError(FlutterErrorDetails details) {
    if (details.silent) return true;
    final String message = '${details.exception}';
    final String library = details.library ?? '';
    if (library.contains('rendering') && message.contains('overflowed')) {
      return true;
    }
    if (message.contains('A RenderFlex overflowed')) return true;
    if (message.contains(
        'Navigator operation requested with a context that does not include a Navigator')) {
      return true;
    }
    // build / layout 阶段的断言属于框架可恢复错误，不是 isolate 级崩溃。
    if (details.exception is AssertionError) return true;
    return false;
  }

  /// 对应原项目 App.kt 的崩溃兜底：框架错误照常上报，
  /// 只有真正的未捕获异常才进连续崩溃计数。
  static void install(
    CrashGuardPolicy policy, {
    void Function(Object error, StackTrace stack)? onCrash,
  }) {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (!isRecoverableFrameworkError(details)) {
        onCrash?.call(details.exception, details.stack ?? StackTrace.empty);
      }
      // 布局 / 导航断言仍然打印，方便在 DevTools 里定位，但不刷崩溃计数。
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      onCrash?.call(error, stack);
      return true;
    };
  }

  /// 启动时由持久化崩溃记录裁决；AppBootstrap 与 app 层据此跳过可选初始化，
  /// 保留最小可读路径。持久化在 assembly/app_bootstrap.dart，纯 Dart 层不反向依赖。
  static bool safeModeActive = false;

  /// 安全模式下要跳过的可选初始化，只有一份清单。
  static const List<String> skippedInSafeMode = <String>[
    '字体按需包检查', '小组件刷新', '云端目录预取', '崩溃上报',
  ];
}
