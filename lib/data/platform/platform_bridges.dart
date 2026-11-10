import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show Size;

import '../storage/sqlite_progress_store.dart';
import '../../core/model/performance_prefs.dart';
import '../../domain/repositories/render_bridge.dart';

/// 第二十九轮：把此前 ❄️ 冻结的平台能力全部收口到一层 MethodChannel 实现。
///
/// 分层纪律：Dart 业务层只认 `BookRenderBridge` / `SqlExecutor` 这类窄接口，
/// 页面不出现 `Platform.is*`；三端各实现同名 channel，见 android/ ios/ ohos/。
/// 通道名与参数键沿用二十三轮已落地的三端骨架，保证 Dart 与原生对得上。
/// 本环境无 Flutter SDK，channel 调用的真机行为需本地 `flutter run` 验证。
class LrChannels {
  const LrChannels._();

  static const MethodChannel render =
      MethodChannel('com.demo.localreader/render');
  static const MethodChannel tts =
      MethodChannel('com.demo.localreader/tts');
  static const MethodChannel charset =
      MethodChannel('com.demo.localreader/charset');
  static const MethodChannel saf =
      MethodChannel('com.demo.localreader/saf');
  static const MethodChannel database =
      MethodChannel('com.demo.localreader/database');
  static const MethodChannel device =
      MethodChannel('com.demo.localreader/device');
  static const MethodChannel share =
      MethodChannel('com.demo.localreader/share');
  static const MethodChannel widgets =
      MethodChannel('com.demo.localreader/widgets');
  static const MethodChannel files =
      MethodChannel('com.demo.localreader/files');
  static const MethodChannel fonts =
      MethodChannel('com.demo.localreader/fonts');
  static const MethodChannel voice =
      MethodChannel('com.demo.localreader/voice');
}

/// PDF / 漫画页栅格化：原生注册外部纹理，Dart 侧只拿 textureId。
/// 不嵌 PlatformView，避免三端合成开销与 BackdropFilter 冲突。
class PlatformRenderBridge implements BookRenderBridge {
  const PlatformRenderBridge();

  @override
  Future<int> open(String documentId, String localPath) async {
    final int? handle = await LrChannels.render.invokeMethod<int>(
      'open',
      <String, Object>{
        'documentId': documentId,
        'localPath': localPath,
      },
    );
    if (handle == null) throw NativeRenderUnavailable('open');
    return handle;
  }

  @override
  Future<int> pageCount(int handle) async =>
      await LrChannels.render.invokeMethod<int>(
          'pageCount', <String, Object>{'handle': handle}) ??
      0;

  @override
  Future<PageInfo> pageInfo(int handle, int index) async {
    final Map<dynamic, dynamic>? m =
        await LrChannels.render.invokeMapMethod<String, dynamic>(
      'pageInfo',
      <String, Object>{'handle': handle, 'index': index},
    );
    if (m == null) throw NativeRenderUnavailable('pageInfo');
    final double w = (m['w'] as num?)?.toDouble() ?? 1;
    final double h = (m['h'] as num?)?.toDouble() ?? 1;
    final double aspect = (m['aspect'] as num?)?.toDouble() ?? (h == 0 ? 1 : w / h);
    return PageInfo(widthPx: w, heightPx: h, aspectRatio: aspect);
  }

  @override
  Future<RenderedPage> render(int handle, int index, Size targetPx) async {
    final int w = targetPx.width.round();
    final int h = targetPx.height.round();
    final Map<dynamic, dynamic>? m =
        await LrChannels.render.invokeMapMethod<String, dynamic>(
      'render',
      <String, Object>{
        'handle': handle,
        'index': index,
        'w': w,
        'h': h,
      },
    );
    if (m == null) throw NativeRenderUnavailable('render');
    return RenderedPage(
      index: index,
      textureId: m['textureId'] as int?,
      imageBytes: m['bytes'] as Uint8List?,
      widthPx: (m['w'] as num?)?.toDouble() ?? targetPx.width,
      heightPx: (m['h'] as num?)?.toDouble() ?? targetPx.height,
    );
  }

  @override
  Future<void> prefetch(int handle, List<int> upcoming) =>
      LrChannels.render.invokeMethod<void>('prefetch', <String, Object>{
        'handle': handle,
        'indices': upcoming,
      });

  @override
  Future<void> evict(int handle, List<int> indices) =>
      LrChannels.render.invokeMethod<void>('evict', <String, Object>{
        'handle': handle,
        'indices': indices,
      });

  @override
  Future<void> close(int handle) => LrChannels.render
      .invokeMethod<void>('close', <String, Object>{'handle': handle});
}

/// SQLite 执行器：真实实现由三端原生提供（Android SQLiteOpenHelper /
/// iOS FMDB / ohos relationalStore）。迁移仍走 `migrateDatabase()`。
class PlatformSqlExecutor implements SqlExecutor {
  const PlatformSqlExecutor();

  @override
  Future<int> userVersion() async =>
      await LrChannels.database.invokeMethod<int>('userVersion') ?? 0;

  @override
  Future<void> setUserVersion(int version) =>
      LrChannels.database.invokeMethod<void>(
          'setUserVersion', <String, Object>{'version': version});

  @override
  Future<void> execute(String sql, [List<Object?> args = const <Object?>[]]) =>
      LrChannels.database.invokeMethod<void>(
          'execute', <String, Object>{'sql': sql, 'args': args});

  @override
  Future<List<Map<String, Object?>>> query(String sql,
      [List<Object?> args = const <Object?>[]]) async {
    final List<dynamic>? rows =
        await LrChannels.database.invokeListMethod<dynamic>(
            'query', <String, Object>{'sql': sql, 'args': args});
    if (rows == null) return <Map<String, Object?>>[];
    return <Map<String, Object?>>[
      for (final dynamic r in rows)
        if (r is Map) Map<String, Object?>.from(r),
    ];
  }

  @override
  Future<void> transaction(Future<void> Function() body) async {
    await LrChannels.database.invokeMethod<void>('begin');
    try {
      await body();
      await LrChannels.database.invokeMethod<void>('commit');
    } catch (_) {
      await LrChannels.database.invokeMethod<void>('rollback');
      rethrow;
    }
  }
}

/// 导出落盘 + 系统分享：页面只给纯文本，写文件 / 分享由原生做。
class PlatformShareBridge {
  const PlatformShareBridge();

  Future<String?> saveText(String fileName, String text) =>
      LrChannels.share.invokeMethod<String>(
          'saveText', <String, Object>{'name': fileName, 'text': text});

  Future<void> shareText(String text) => LrChannels.share
      .invokeMethod<void>('shareText', <String, Object>{'text': text});

  Future<void> saveImage(Uint8List bytes, String fileName) =>
      LrChannels.share.invokeMethod<void>('saveImage', <String, Object>{
        'name': fileName,
        'bytes': bytes,
      });
}

/// 屏幕常亮 / 音量键翻页 / 系统字体 / 语音模型枚举。
class PlatformDeviceBridge {
  const PlatformDeviceBridge();

  Future<void> setScreenOn(bool on) => LrChannels.device
      .invokeMethod<void>('setScreenOn', <String, Object>{'on': on});

  Future<List<String>> systemFonts() async =>
      (await LrChannels.fonts.invokeListMethod<String>('list')) ??
      <String>[];

  Future<void> loadFont(String assetOrPath) => LrChannels.fonts
      .invokeMethod<void>('load', <String, Object>{'path': assetOrPath});

  /// 第三十轮：设备档位探测。静态 / 无平台实现时返回 unknown，
  /// 页面据此显示「未检测」，不伪装成已识别设备。
  Future<DeviceCapability> detectCapability() async {
    final Map<Object?, Object?>? raw =
        await LrChannels.device.invokeMapMethod<Object?, Object?>('capability');
    if (raw == null) return const DeviceCapability();
    return DeviceCapability.fromMap(Map<String, Object?>.from(raw));
  }

  Future<List<String>> voiceModels() async =>
      (await LrChannels.voice.invokeListMethod<String>('models')) ??
      <String>[];
}

/// 桌面小组件数据同步：Dart 只推共享 JSON，卡片本体三端原生绘制。
class PlatformWidgetSync {
  const PlatformWidgetSync();

  Future<void> push(String widgetId, Map<String, Object?> payload) =>
      LrChannels.widgets.invokeMethod<void>(
          'update', <String, Object>{'id': widgetId, 'payload': payload});

  Future<void> remove(String widgetId) => LrChannels.widgets
      .invokeMethod<void>('remove', <String, Object>{'id': widgetId});
}

/// 真实文件扫描：SAF 授权持久化后按扩展名列出文件，交给 Dart 解析器。
class PlatformFileScanBridge {
  const PlatformFileScanBridge();

  Future<List<String>> list(String treeUri, List<String> extensions) async =>
      (await LrChannels.files.invokeListMethod<String>(
        'list',
        <String, Object>{'uri': treeUri, 'exts': extensions},
      )) ??
      <String>[];
}

/// 原生 → Dart 的朗读完成事件：`onSentenceDone` 带 utteranceId，
/// `SentenceQueue` 靠它精确到句推进，不靠定时器猜。
class PlatformTtsEvents {
  PlatformTtsEvents() {
    LrChannels.tts.setMethodCallHandler(_handle);
  }

  final StreamController<int> _controller = StreamController<int>.broadcast();

  Stream<int> get sentenceDone => _controller.stream;

  Future<dynamic> _handle(MethodCall call) async {
    if (call.method != 'onSentenceDone') return null;
    final Object? args = call.arguments;
    final Object? raw = args is Map ? args['utteranceId'] : null;
    final int index = raw is int ? raw : int.tryParse('$raw') ?? 0;
    _controller.add(index);
    return null;
  }

  void dispose() {
    LrChannels.tts.setMethodCallHandler(null);
    _controller.close();
  }
}
