import 'package:flutter/widgets.dart';

import '../data/platform/platform_bridges.dart';
import '../domain/repositories/reader_bridge.dart';
import '../domain/repositories/render_bridge.dart';
import '../data/storage/sqlite_progress_store.dart';
import '../data/wenku/wenku8_cache.dart';

/// 平台能力的唯一注入点（第二十九轮解冻冻结功能）。
///
/// 页面用 `AppServices.of(context)` 拿窄接口，不 import 平台实现、
/// 不散写 MethodChannel 字符串、不出现 `Platform.is*`。
/// 静态 / 单测环境可注入 Fake 版本；真实版本由 main() 装配。
class AppServices extends InheritedWidget {
  AppServices({
    super.key,
    required Widget child,
    BookRenderBridge? render,
    TtsBridge? tts,
    SafBridge? saf,
    SqlExecutor? database,
    PlatformShareBridge? share,
    PlatformDeviceBridge? device,
    PlatformWidgetSync? widgetSync,
    PlatformFileScanBridge? fileScan,
    PlatformTtsEvents? ttsEvents,
    Wenku8Cache? wenku8Cache,
  })  : render = render ?? const PlatformRenderBridge(),
        tts = tts ?? const MethodChannelBridge(),
        saf = saf ?? const MethodChannelBridge(),
        database = database,
        share = share ?? const PlatformShareBridge(),
        device = device ?? const PlatformDeviceBridge(),
        widgetSync = widgetSync ?? const PlatformWidgetSync(),
        fileScan = fileScan ?? const PlatformFileScanBridge(),
        ttsEvents = ttsEvents,
        wenku8Cache = wenku8Cache,
        super(child: child);

  final BookRenderBridge render;
  final TtsBridge tts;
  final SafBridge saf;
  final SqlExecutor? database;
  final PlatformShareBridge share;
  final PlatformDeviceBridge device;
  final PlatformWidgetSync widgetSync;
  final PlatformFileScanBridge fileScan;
  final PlatformTtsEvents? ttsEvents;
  final Wenku8Cache? wenku8Cache;

  static AppServices of(BuildContext context) {
    final AppServices? s =
        context.dependOnInheritedWidgetOfExactType<AppServices>();
    assert(s != null, 'AppServices 必须挂在 MaterialApp 之上');
    return s!;
  }

  @override
  bool updateShouldNotify(AppServices oldWidget) => false;
}
