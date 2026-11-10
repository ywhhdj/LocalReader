import 'package:flutter/services.dart';

/// 平台能力收口层：Dart 页面只依赖这些抽象，不允许在业务页面里散落平台判断。
/// Android / iOS / ohos 三端各自提供实现，鸿蒙侧落在 ohos/entry/src/main/ets/plugins/。

const MethodChannel _channel = MethodChannel('com.demo.localreader/bridge');

/// 书籍解析：优先纯 Dart 实现（EPUB/TXT/CBZ/PDF/FB2/RTF/MD/DOCX…），
/// 仅 RAR4 解压、系统级文件渲染等少数能力下沉到原生。
abstract interface class BookParserBridge {
  Future<ParsedBook> parse(String localPath);
  Future<List<String>> splitChapters(String rawText, String encoding);
  Future<List<int>> renderPdfPage(String localPath, int page);
}

/// RAR5 与加密包不支持，需在 UI 层明确提示「转 CBZ/ZIP」。
class UnsupportedArchiveException implements Exception {
  const UnsupportedArchiveException(this.reason);
  final String reason;

  @override
  String toString() => 'UnsupportedArchiveException: $reason';
}

class ParsedBook {
  const ParsedBook({
    required this.title,
    required this.author,
    required this.chapters,
    this.coverBytes,
  });

  final String title;
  final String author;
  final List<String> chapters;
  final List<int>? coverBytes;
}

/// TTS：Dart 侧维护分句队列，暂停/续播精确到句，读完自动进入下一章。
abstract interface class TtsBridge {
  Future<void> enqueueSentences(List<String> sentences);
  Future<void> pause();
  Future<void> resumeAtSentence(int index);
  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> stop();
}

/// 存储与进度：滚动/翻页期间固定间隔采样落库（含页内位置），退出前兜底写一次。
abstract interface class StorageBridge {
  Future<void> saveProgress(String bookId, double chapterProgress, double pageOffset);
  Future<Map<String, dynamic>> loadProgress(String bookId);
  Future<void> exportSnapshot(String targetPath);
}

/// 文件授权：Android 保留 SAF 目录授权持久化（takePersistableUriPermission，重启可一键重扫）；
/// iOS 用 UIDocumentPicker；HarmonyOS 用系统文件选择器。
abstract interface class SafBridge {
  Future<String?> pickDirectory();
  Future<List<String>> rescanPersisted();
  Future<bool> hasPersistedGrant();
}

/// 最小占位实现，用于 P0 阶段让页面跑起来；P1/P2 替换为真实实现。
class MethodChannelBridge implements BookParserBridge, TtsBridge, StorageBridge, SafBridge {
  const MethodChannelBridge();

  @override
  Future<ParsedBook> parse(String localPath) async {
    final Map<dynamic, dynamic>? result =
        await _channel.invokeMapMethod<String, dynamic>('parse', <String, dynamic>{'path': localPath});
    if (result == null) throw UnsupportedArchiveException('原生层未返回解析结果，请接入纯 Dart 解析器');
    return ParsedBook(
      title: result['title'] as String? ?? '未命名',
      author: result['author'] as String? ?? '',
      chapters: (result['chapters'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
    );
  }

  @override
  Future<List<String>> splitChapters(String rawText, String encoding) =>
      _channel.invokeListMethod<String>('splitChapters', <String, dynamic>{
        'text': rawText,
        'encoding': encoding,
      }).then((List<String>? v) => v ?? <String>[]);

  @override
  Future<List<int>> renderPdfPage(String localPath, int page) =>
      _channel.invokeListMethod<int>('renderPdfPage', <String, dynamic>{'path': localPath, 'page': page})
          .then((List<int>? v) => v ?? <int>[]);

  @override
  Future<void> enqueueSentences(List<String> sentences) async {
    await _channel.invokeMethod<void>('ttsEnqueue', <String, dynamic>{'sentences': sentences});
  }

  @override
  Future<void> pause() async {
    await _channel.invokeMethod<void>('ttsPause');
  }

  @override
  Future<void> resumeAtSentence(int index) async {
    await _channel.invokeMethod<void>('ttsResume', <String, dynamic>{'index': index});
  }

  @override
  Future<void> setRate(double rate) async {
    await _channel.invokeMethod<void>('ttsSetRate', <String, dynamic>{'rate': rate});
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _channel.invokeMethod<void>('ttsSetPitch', <String, dynamic>{'pitch': pitch});
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod<void>('ttsStop');
  }

  @override
  Future<void> saveProgress(String bookId, double chapterProgress, double pageOffset) async {
    await _channel.invokeMethod<void>('saveProgress', <String, dynamic>{
      'bookId': bookId,
      'chapterProgress': chapterProgress,
      'pageOffset': pageOffset,
    });
  }

  @override
  Future<Map<String, dynamic>> loadProgress(String bookId) =>
      _channel.invokeMapMethod<String, dynamic>('loadProgress', <String, dynamic>{'bookId': bookId})
          .then((Map<String, dynamic>? v) => v ?? <String, dynamic>{});

  @override
  Future<void> exportSnapshot(String targetPath) async {
    await _channel.invokeMethod<void>('exportSnapshot', <String, dynamic>{'path': targetPath});
  }

  @override
  Future<String?> pickDirectory() => _channel.invokeMethod<String>('pickDirectory');

  @override
  Future<List<String>> rescanPersisted() =>
      _channel.invokeListMethod<String>('rescanPersisted').then((List<String>? v) => v ?? <String>[]);

  @override
  Future<bool> hasPersistedGrant() =>
      _channel.invokeMethod<bool>('hasPersistedGrant').then((bool? v) => v ?? false);
}
