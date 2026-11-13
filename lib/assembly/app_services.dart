import 'package:flutter/widgets.dart';

import '../data/platform/backup_service.dart';
import '../data/platform/import_service.dart';
import '../data/platform/persistence.dart';
import '../data/platform/platform_bridges.dart';
import '../data/platform/real_bridges.dart';
import '../data/platform/sqlite_runtime.dart';
import '../data/storage/sqlite_progress_store.dart';
import '../data/wenku/wenku8_cache.dart';
import '../domain/repositories/reader_bridge.dart';
import '../domain/repositories/render_bridge.dart';

/// 平台能力的唯一注入点（第三十二轮：把 ❄️ 冻结项全部换成真实实现）。
///
/// 页面用 `AppServices.of(context)` 拿窄接口，不 import 平台实现、
/// 不散写 MethodChannel 字符串、不出现 `Platform.is*`。
/// 单测 / 静态环境仍可注入 Fake，未注入时一律走三端 MethodChannel 实现。
class AppServices extends InheritedWidget {
  AppServices({
    super.key,
    required Widget child,
    BookRenderBridge? render,
    TtsBridge? tts,
    SafBridge? saf,
    SqlExecutor? database,
    SqlPrefsStore? prefs,
    PlatformShareBridge? share,
    PlatformDeviceBridge? device,
    PlatformWidgetSync? widgetSync,
    PlatformFileScanBridge? fileScan,
    PlatformTtsEvents? ttsEvents,
    Wenku8Cache? wenku8Cache,
  })  : render = render ?? const PlatformRenderBridge(),
        tts = tts ?? const PlatformTtsBridge(),
        saf = saf ?? const PlatformSafBridge(),
        database = database ?? SqliteRuntime.instance.executor,
        _prefsOverride = prefs,
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
  final SqlExecutor database;
  final SqlPrefsStore? _prefsOverride;
  final PlatformShareBridge share;
  final PlatformDeviceBridge device;
  final PlatformWidgetSync widgetSync;
  final PlatformFileScanBridge fileScan;
  final PlatformTtsEvents? ttsEvents;
  final Wenku8Cache? wenku8Cache;

  /// 朗读完成事件流；app 层持有实例以便 dispose 时注销 handler。
  Stream<int>? get sentenceDone => ttsEvents?.sentenceDone;

  /// 全应用一份 KV 缓存：读命中内存，不会每次交互都查库。
  /// 单测注入自定义 executor 时，自动退化成该 executor 的私有 prefs。
  late final SqlPrefsStore prefs = _prefsOverride ??
      (database is GatedSqlExecutor
          ? SqliteRuntime.instance.prefs
          : SqlPrefsStore(database));
  late final WebDavConfigStore webDavConfig = WebDavConfigStore(prefs);
  late final BackupService backup = BackupService(
    configStore: webDavConfig,
    share: share,
  );
  late final ImportService importer = ImportService(
    saf: saf is PlatformSafBridge
        ? saf as PlatformSafBridge
        : const PlatformSafBridge(),
    files: const PlatformFileAccess(),
    database: database,
  );

  /// 真实 TTS / 字体 / 语音 / 字符集 / 存储桥，页面按需取。
  static const PlatformTtsBridge ttsReal = PlatformTtsBridge();
  static const PlatformFontInstaller fonts = PlatformFontInstaller();
  static const PlatformVoiceCatalog voices = PlatformVoiceCatalog();
  static const PlatformCharsetFallback charset = PlatformCharsetFallback();
  static const PlatformFileAccess files = PlatformFileAccess();

  PlatformStorageBridge get storage => PlatformStorageBridge(database);

  static AppServices of(BuildContext context) {
    final AppServices? s =
        context.dependOnInheritedWidgetOfExactType<AppServices>();
    assert(s != null, 'AppServices 必须挂在 MaterialApp 之上');
    return s!;
  }

  @override
  bool updateShouldNotify(AppServices oldWidget) => false;
}
