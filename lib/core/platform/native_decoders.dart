import 'package:flutter/foundation.dart';

/// 原生解码器的接入契约。这里只定义 Dart 侧需要的能力与查找约定，
/// 真实 FFI 绑定签名按所选构建产物用 ffigen 生成，避免手写 lookupFunction 出错。
enum NativeDecoderKind { pdfium, rar4, image, charset }

@immutable
class NativeDecoderSpec {
  const NativeDecoderSpec({
    required this.kind,
    required this.libraryName,
    required this.platforms,
    required this.responsibility,
  });

  final NativeDecoderKind kind;
  final String libraryName;
  final List<String> platforms;
  final String responsibility;
}

/// 三端要交付的动态库清单。鸿蒙侧 SO 需交叉编译为可在 HarmonyOS 运行的库，
/// 并在 ohos 工程中用 CMake 构建后由 dart:ffi 加载。
const List<NativeDecoderSpec> kDecoderSpecs = <NativeDecoderSpec>[
  NativeDecoderSpec(
    kind: NativeDecoderKind.pdfium,
    libraryName: 'libpdfium.so / PDFium.framework / libpdfium.so(ohos)',
    platforms: <String>['android', 'ios', 'ohos'],
    responsibility: 'PDF 解析与逐页光栅化，输出 BGRA 位图缓冲',
  ),
  NativeDecoderSpec(
    kind: NativeDecoderKind.rar4,
    libraryName: 'libunrar / 自研 RAR4 解压',
    platforms: <String>['android', 'ios', 'ohos'],
    responsibility: '仅 RAR4 及更早；RAR5 明确拒绝并提示转 CBZ/ZIP',
  ),
  NativeDecoderSpec(
    kind: NativeDecoderKind.image,
    libraryName: '平台图片解码器',
    platforms: <String>['android', 'ios', 'ohos'],
    responsibility: '漫画大图解码、按目标尺寸缩放、纹理帧通知',
  ),
  NativeDecoderSpec(
    kind: NativeDecoderKind.charset,
    libraryName: 'Charset.forName / CFStringEncoding / util.TextDecoder',
    platforms: <String>['android', 'ios', 'ohos'],
    responsibility: 'GBK / GB18030 / Big5 解码（纯 Dart 无可靠实现）',
  ),
];

class NativeDecoderUnavailable implements Exception {
  const NativeDecoderUnavailable(this.kind, this.platform);
  final NativeDecoderKind kind;
  final String platform;

  @override
  String toString() => 'NativeDecoderUnavailable: $platform 未提供 ${kind.name} 解码器';
}

abstract interface class NativeDecoderRegistry {
  bool isAvailable(NativeDecoderKind kind);

  /// 加载动态库。鸿蒙侧路径由 ohos 壳工程提供，不能写死 /system/lib。
  Future<void> load(NativeDecoderKind kind, String libraryPath);

  /// 三端渲染能力需要版本探测（例如 HCPP 要求 Android API 34+ 与 Impeller/Vulkan）。
  Future<Map<String, String>> capabilities();
}

/// FFI 绑定模板（接入时由 ffigen 生成，不要手写）：
///
/// ```dart
/// import 'dart:ffi';
/// import 'dart:io' show Platform;
///
/// final DynamicLibrary _pdfium = Platform.isAndroid
///     ? DynamicLibrary.open('libpdfium.so')
///     : DynamicLibrary.process();
///
/// // FPDF_InitLibrary / FPDF_LoadDocument / FPDF_GetPageCount / FPDF_LoadPage
/// // FPDF_GetPageWidthF / FPDF_GetPageHeightF / FPDFBitmap_Create
/// // FPDFBitmap_FillRect / FPDF_RenderPageBitmap / FPDFBitmap_GetBuffer
/// // FPDFBitmap_Destroy / FPDF_ClosePage / FPDF_CloseDocument / FPDF_DestroyLibrary
/// //
/// // 渲染流程：
/// //   PDF 页 → PDFium → BGRA 位图 → FFI 暴露指针/长度
/// //   → Dart 侧 Uint8List → image 包编码 PNG（单页快照）
/// //   或 → 原生 TextureRegistry 注册 textureId（连续翻页）
/// ```
///
/// 选型备注：FFI 传像素零拷贝、无序列化，是 PDF / 漫画解码的首选；
/// Texture 传 textureId + MarkNewFrameAvailable 帧通知，适合连续翻页；
/// Pigeon/MethodChannel 只用于低频系统能力（TTS、SAF、音量键、屏幕常亮）。
class UnimplementedDecoderRegistry implements NativeDecoderRegistry {
  const UnimplementedDecoderRegistry();

  @override
  bool isAvailable(NativeDecoderKind kind) => false;

  @override
  Future<void> load(NativeDecoderKind kind, String libraryPath) async =>
      throw NativeDecoderUnavailable(kind, '当前平台');

  @override
  Future<Map<String, String>> capabilities() async => <String, String>{'status': 'no_native_decoders'};
}
