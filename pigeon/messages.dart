// Pigeon 契约输入文件。放在 pigeon/ 而不是 lib/，避免混入应用编译单元。
// 生成命令见 tool/gen_pigeon.sh；生成产物不要手改，也不要提交手写占位文件。
//
// 选型：Pigeon 用代码生成替代手写 MethodChannel 字符串协议，解决
// 「方法名 / 参数形状 / 数据类型 / 编解码器」三端各自约定容易漂移的问题。
// 注意社区 Pigeon 无官方 ArkTS 后端：ohos 侧需按 codec 手写对齐（见 docs/平台实现清单.md）。

import 'dart:typed_data';

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/core/platform/pigeon_generated.dart',
  dartOptions: DartOptions(),
  kotlinOut:
      'android/app/src/main/kotlin/com/demo/localreader/PigeonMessages.kt',
  kotlinOptions: KotlinOptions(package: 'com.demo.localreader'),
  swiftOut: 'ios/Classes/PigeonMessages.swift',
  swiftOptions: SwiftOptions(),
  dartPackageName: 'local_reader',
))
void configurePigeon() {}

/// 页描述与目标尺寸：Dart 只传这些，不传原始文件流。
class RenderRequest {
  RenderRequest({
    required this.handle,
    required this.index,
    required this.widthPx,
    required this.heightPx,
  });

  final int handle;
  final int index;
  final int widthPx;
  final int heightPx;
}

class RenderReply {
  RenderReply(
      {this.textureId,
      this.imageBytes,
      required this.widthPx,
      required this.heightPx});

  /// 连续翻页走纹理；单页快照走编码位图，二者至少一路。
  final int? textureId;
  final Uint8List? imageBytes;
  final int widthPx;
  final int heightPx;
}

class PageInfoReply {
  PageInfoReply(
      {required this.widthPx,
      required this.heightPx,
      required this.aspectRatio});
  final double widthPx;
  final double heightPx;
  final double aspectRatio;
}

class CharsetReply {
  CharsetReply({required this.text, required this.encoding});
  final String text;
  final String encoding;
}

@HostApi()
abstract class RendererApi {
  int open(String documentId, String localPath);
  int pageCount(int handle);
  PageInfoReply pageInfo(int handle, int index);

  @async
  RenderReply render(RenderRequest request);

  @async
  void prefetch(int handle, List<int?> indices);

  @async
  void evict(int handle, List<int?> indices);

  void close(int handle);
  Map<String?, String?> capabilities();
}

@HostApi()
abstract class CharsetApi {
  @async
  CharsetReply decode(Uint8List bytes, String encoding);
}

@HostApi()
abstract class TtsApi {
  @async
  void speak(String sentence, String utteranceId);
  void setRate(double rate);
  void setPitch(double pitch);
  void pause();
  void stop();
}

@HostApi()
abstract class SafApi {
  String? pickDirectory();
  bool persistGrant(String uri);
  List<String> rescanPersisted();
  bool hasPersistedGrant();
}

/// 原生 → Dart 的事件：按句朗读完成后 Dart 侧 SentenceQueue 才推进 cursor。
@FlutterApi()
abstract class TtsEvents {
  void onSentenceDone(String utteranceId);
  void onSentenceError(String utteranceId, String message);
}
