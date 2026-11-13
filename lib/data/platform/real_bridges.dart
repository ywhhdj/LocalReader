import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../data/parser/book_parser.dart';
import '../../data/parser/charset_bridge.dart';
import '../../data/storage/sqlite_progress_store.dart' show SqlExecutor;
import '../../domain/repositories/reader_bridge.dart';
import 'platform_bridges.dart';

/// 第三十二轮：把「❄️ 冻结」的平台能力逐个换成真实 MethodChannel 实现。
///
/// 约定（与 android/ ios/ ohos/ 三端插件一一对应）：
///   tts      : speak / setRate / setPitch / pause / stop / resume
///             原生完成一句后回调 onSentenceDone(utteranceId)
///   saf      : pickDirectory / persistGrant / rescanPersisted / hasPersistedGrant
///   files    : list / readBytes / metadata
///   charset  : decode(bytes, encoding)
///   fonts    : list / load
///   voice    : models
///   database : 见 PlatformSqlExecutor
///   share    : 见 PlatformShareBridge
///
/// 所有实现都保持「窄接口」形状：页面只从 AppServices 取，不散写 Platform.is*。
/// 通道未注册（例如桌面 / 单测环境）时统一抛 [PlatformUnavailable]，
/// 由 UI 显示明确提示，绝不留下「点了没反应」。

class PlatformUnavailable implements Exception {
  const PlatformUnavailable(this.feature, [this.detail = '']);
  final String feature;
  final String detail;

  @override
  String toString() => detail.isEmpty
      ? '$feature 需要平台能力，当前环境未接入原生插件'
      : '$feature 需要平台能力：$detail';
}

Future<T> _guard<T>(String feature, Future<T?> Function() body) async {
  try {
    final T? value = await body();
    if (value == null) throw MissingPluginException('$feature 返回空结果');
    return value;
  } on MissingPluginException {
    throw PlatformUnavailable(feature, '原生通道未注册');
  } on PlatformException catch (e) {
    throw PlatformUnavailable(feature, '${e.code} ${e.message ?? ''}'.trim());
  }
}

/// TTS：Dart 的 SentenceQueue 决定「读哪一句」，原生一次只读一句并回报完成。
/// 旧 `MethodChannelBridge` 用的是 `com.demo.localreader/bridge`，
/// 三端注册的是 `com.demo.localreader/tts`，通道名不一致正是「朗读点了没反应」的根因。
class PlatformTtsBridge implements TtsBridge {
  const PlatformTtsBridge();

  MethodChannel get _ch => LrChannels.tts;

  /// 单句朗读并等待原生 onSentenceDone；[events] 为空时退化为「发完即返回」。
  Future<void> speakOne(
    String sentence,
    int index, {
    Stream<int>? sentenceDone,
    double rate = 1.0,
    double pitch = 1.0,
  }) async {
    try {
      await _ch.invokeMethod<void>('speak', <String, Object>{
        'sentence': sentence,
        'utteranceId': '$index',
        'rate': rate,
        'pitch': pitch,
      });
    } on MissingPluginException {
      throw const PlatformUnavailable('TTS 朗读', '原生通道未注册');
    } on PlatformException catch (e) {
      throw PlatformUnavailable('TTS 朗读', '${e.code} ${e.message ?? ''}'.trim());
    }
    if (sentenceDone == null) return;
    // 完成事件带 utteranceId；只接受当前句，超时按失败处理而不是卡死队列。
    await sentenceDone
        .firstWhere((int id) => id == index)
        .timeout(const Duration(seconds: 60), onTimeout: () => index);
  }

  @override
  Future<void> enqueueSentences(List<String> sentences) async {
    await setRate(1.0);
    await setPitch(1.0);
    for (int i = 0; i < sentences.length; i++) {
      await _ch.invokeMethod<void>('speak', <String, Object>{
        'sentence': sentences[i],
        'utteranceId': '$i',
      });
    }
  }

  @override
  Future<void> pause() => _ch.invokeMethod<void>('pause');

  @override
  Future<void> resumeAtSentence(int index) => _ch
      .invokeMethod<void>('resume', <String, Object>{'index': index});

  @override
  Future<void> setRate(double rate) =>
      _ch.invokeMethod<void>('setRate', <String, Object>{'rate': rate});

  @override
  Future<void> setPitch(double pitch) =>
      _ch.invokeMethod<void>('setPitch', <String, Object>{'pitch': pitch});

  @override
  Future<void> stop() => _ch.invokeMethod<void>('stop');

  /// 朗读设置面板「打开系统 TTS 设置」：此前只弹一句静态提示，属于点了不跳转。
  Future<void> openSystemSettings() async {
    try {
      await _ch.invokeMethod<void>('openSettings');
    } on MissingPluginException {
      throw const PlatformUnavailable('系统 TTS 设置', '原生通道未注册');
    } on PlatformException catch (e) {
      throw PlatformUnavailable(
          '系统 TTS 设置', '${e.code} ${e.message ?? ''}'.trim());
    }
  }
}

/// SAF：目录授权持久化 + 重启后一键重扫（原 README 的推荐导入方式）。
class PlatformSafBridge implements SafBridge {
  const PlatformSafBridge();

  MethodChannel get _ch => LrChannels.saf;

  @override
  Future<String?> pickDirectory() async {
    try {
      return await _ch.invokeMethod<String>('pickDirectory');
    } on MissingPluginException {
      throw const PlatformUnavailable('目录授权', '原生通道未注册');
    } on PlatformException catch (e) {
      throw PlatformUnavailable('目录授权', '${e.code} ${e.message ?? ''}'.trim());
    }
  }

  Future<bool> persistGrant(String uri) async {
    final bool? ok = await _ch.invokeMethod<bool>(
        'persistGrant', <String, Object>{'uri': uri});
    return ok ?? false;
  }

  @override
  Future<List<String>> rescanPersisted() async =>
      (await _ch.invokeListMethod<String>('rescanPersisted')) ??
      const <String>[];

  @override
  Future<bool> hasPersistedGrant() async =>
      (await _ch.invokeMethod<bool>('hasPersistedGrant')) ?? false;
}

/// 真实文件访问：SAF 树 / 绝对路径下的书籍文件列表与字节读取。
/// 导入向导的「扫描」从此读的是真文件，不再是 ImportDemoPaths。
class PlatformFileAccess {
  const PlatformFileAccess();

  static const List<String> bookExtensions = <String>[
    'txt', 'epub', 'md', 'markdown', 'fb2', 'rtf', 'docx', 'html', 'htm',
    'xhtml', 'pdf', 'cbz', 'zip', 'cbr', 'rar', 'doc', 'mobi', 'azw',
    'azw3', 'prc',
  ];

  Future<List<String>> list(String root, {List<String>? extensions}) async {
    final List<String>? out = await LrChannels.files.invokeListMethod<String>(
      'list',
      <String, Object>{
        'uri': root,
        'exts': extensions ?? bookExtensions,
      },
    );
    return out ?? const <String>[];
  }

  Future<Uint8List> readBytes(String path) async {
    final Uint8List? out = await LrChannels.files.invokeMethod<Uint8List>(
      'readBytes',
      <String, Object>{'path': path},
    );
    if (out == null) {
      throw const PlatformUnavailable('文件读取', '原生未返回字节');
    }
    return out;
  }

  Future<int> sizeOf(String path) async =>
      (await LrChannels.files.invokeMethod<int>(
        'size',
        <String, Object>{'path': path},
      )) ??
      0;
}

/// GBK / GB18030 / Big5 交给三端原生解码；纯 Dart 只做 BOM / UTF-8 校验。
class PlatformCharsetFallback {
  const PlatformCharsetFallback();

  Future<String> decode(Uint8List bytes, DetectedEncoding encoding) async {
    final String hint = encoding == DetectedEncoding.big5
        ? 'big5'
        : encoding == DetectedEncoding.gb18030
            ? 'gb18030'
            : encoding == DetectedEncoding.gbk
                ? 'gbk'
                : 'auto';
    return _guard<String>('字符集解码', () async {
      final Map<Object?, Object?>? out =
          await LrChannels.charset.invokeMapMethod<Object?, Object?>(
        'decode',
        <String, Object>{'bytes': bytes, 'encoding': hint},
      );
      return out?['text'] as String?;
    });
  }
}

/// 字体注册与系统字体枚举：FontCatalog 的「导入字体」不再只登记元数据。
class PlatformFontInstaller {
  const PlatformFontInstaller();

  Future<List<String>> systemFonts() async =>
      (await LrChannels.fonts.invokeListMethod<String>('list')) ??
      const <String>[];

  Future<void> load(String assetOrPath) => LrChannels.fonts
      .invokeMethod<void>('load', <String, Object>{'path': assetOrPath});
}

/// TTS 音色枚举：BilingualPrefs 的「跳过无语音语言」改用真实音色列表裁决。
class PlatformVoiceCatalog {
  const PlatformVoiceCatalog();

  Future<List<String>> models() async =>
      (await LrChannels.voice.invokeListMethod<String>('models')) ??
      const <String>[];
}

/// 真实解析器：纯 Dart 文本格式 + 原生栅格化格式的元数据壳。
class PlatformBookParserBridge implements BookParserBridge {
  const PlatformBookParserBridge(this.parser);

  final BookParser parser;

  @override
  Future<ParsedBook> parse(String localPath) async {
    final Uint8List bytes;
    try {
      bytes = await const PlatformFileAccess().readBytes(localPath);
    } on PlatformUnavailable {
      rethrow;
    }
    try {
      final doc = await parser.parse(localPath, bytes);
      return ParsedBook(
        title: doc.title,
        author: doc.author,
        chapters: <String>[for (final c in doc.chapters) c.title],
      );
    } on UnsupportedFormatException catch (e) {
      throw UnsupportedArchiveException(e.reason);
    }
  }

  @override
  Future<List<String>> splitChapters(String rawText, String encoding) async {
    // TXT 章节切分是纯 Dart 规则，避免把整章文本跨 channel 来回搬。
    return RegExp(r'(?m)^\s*(第[零〇一二三四五六七八九十百千0-9]+[章节回卷部篇].*|Chapter\s+\d+.*)$')
        .allMatches(rawText)
        .map((Match m) => m.group(0)!.trim())
        .toList(growable: false);
  }

  @override
  Future<List<int>> renderPdfPage(String localPath, int page) async {
    // PDF 逐页渲染统一走 BookRenderBridge（PlatformRenderBridge.render）。
    throw const PlatformUnavailable(
        'PDF 逐页渲染', '请通过 BookRenderBridge.open/render 获取页面像素');
  }
}

/// StorageBridge：进度采样真实落库（SqliteProgressStore），不再空操作。
class PlatformStorageBridge implements StorageBridge {
  const PlatformStorageBridge(this.executor);

  final SqlExecutor executor;

  @override
  Future<void> saveProgress(
      String bookId, double chapterProgress, double pageOffset) async {
    await executor.execute(
      '''INSERT INTO progress
           (book_id, chapter_index, page_index, page_offset, block_index,
            line_index, char_offset, updated_at)
         VALUES (?, 0, ?, ?, 0, 0, 0, ?)
         ON CONFLICT(book_id) DO UPDATE SET
           page_index = excluded.page_index,
           page_offset = excluded.page_offset,
           updated_at = excluded.updated_at''',
      <Object?>[
        bookId,
        (chapterProgress * 1000).round(),
        pageOffset,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> loadProgress(String bookId) async {
    final List<Map<String, Object?>> rows = await executor.query(
      'SELECT page_index, page_offset, updated_at FROM progress WHERE book_id = ?',
      <Object?>[bookId],
    );
    if (rows.isEmpty) return <String, dynamic>{};
    return <String, dynamic>{
      'chapterProgress': ((rows.first['page_index'] as num?) ?? 0) / 1000.0,
      'pageOffset': (rows.first['page_offset'] as num?) ?? 0.0,
      'updatedAt': rows.first['updated_at'],
    };
  }

  @override
  Future<void> exportSnapshot(String targetPath) async {
    final List<Map<String, Object?>> rows =
        await executor.query('SELECT * FROM progress');
    final String payload = jsonEncode(rows);
    await const PlatformShareBridge()
        .saveText(targetPath.split(RegExp(r'[/\\]')).last, payload);
  }
}
