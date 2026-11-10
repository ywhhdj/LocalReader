import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, runApp;

import '../app.dart';
import '../core/common/device_tier.dart';
import '../core/common/memory_utils.dart';
import '../crash_guard.dart';

/// 对应原 Kotlin 工程 `App.kt`：图片缓存（Coil）/ 崩溃兜底 / 容器 / 内存裁剪，
/// 以及 `assembly/` 的启动装配职责。`main.dart` 只负责调 [run]，不散写初始化。
///
/// 退出清理仍由 `AppState.dispose()` 与 `Wenku8Bootstrap` 的关闭钩子承担，
/// 这里不重复注册一份，避免「两处都以为自己负责清理」。
class AppBootstrap {
  const AppBootstrap._();

  /// 静态阶段没有平台设备通道，按「未知设备」取最保守预算；
  /// 接 SDK 后由 `AppServices.detectCapability()` 填 [DeviceCapability] 再分档。
  static MemoryBudget run({DeviceCapability capability = DeviceCapability.unknown}) {
    WidgetsFlutterBinding.ensureInitialized();

    // 1) 崩溃兜底：框架错误与平台未捕获错误都进同一条记录链。
    CrashGuard.install(const CrashGuardPolicy());

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
}

/// 崩溃兜底注册入口，薄封装在 CrashGuard 里，这里保留一个统一引用点，
/// 便于未来把「连续崩溃 -> 安全模式」接到启动流程。
void installCrashGuard(CrashGuardPolicy policy) => CrashGuard.install(policy);
