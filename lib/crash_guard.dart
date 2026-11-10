import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';

/// 连续崩溃保护（第二十四轮）。
///
/// 原项目工程结构里列了 `CrashGuard.kt（含连续崩溃保护）`，Flutter 侧一直只有
/// `main.dart` 的 TODO。本层把**判据**收成纯 Dart：时间窗内连续崩溃达到阈值，
/// 下次启动进安全模式（跳过可选初始化、保留最小可读路径）。
///
/// 框架回调注册由 `assembly/app_bootstrap.dart` 在启动时调用 [install]；
/// 判据本身仍是纯 Dart，连续崩溃的持久化接平台存储（❄️ 冻结）。
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

  /// 对应原项目 App.kt 的崩溃兜底：把框架错误与平台未捕获错误收成一条记录链。
  /// 连续崩溃计数仍由 [record] / [shouldEnterSafeMode] 裁决，这里只接管回调。
  static void install(
    CrashGuardPolicy policy, {
    void Function(Object error, StackTrace stack)? onCrash,
  }) {
    FlutterError.onError = (FlutterErrorDetails details) {
      onCrash?.call(details.exception, details.stack ?? StackTrace.empty);
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      onCrash?.call(error, stack);
      return true;
    };
  }

  /// 安全模式下要跳过的可选初始化，只有一份清单。
  static const List<String> skippedInSafeMode = <String>[
    '字体按需包检查', '小组件刷新', '云端目录预取', '崩溃上报',
  ];
}
