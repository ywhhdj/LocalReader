import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 混合渲染的唯一边界：Dart 只传「页描述 + 目标尺寸」，不传原始文件流；
/// 原生层不认文件格式，只认这个契约。
class NativeRenderUnavailable implements Exception {
  const NativeRenderUnavailable(this.what);
  final String what;

  @override
  String toString() => 'NativeRenderUnavailable: $what 尚未提供三端实现';
}

@immutable
class PageInfo {
  const PageInfo({required this.widthPx, required this.heightPx, required this.aspectRatio});
  final double widthPx;
  final double heightPx;
  final double aspectRatio;
}

@immutable
class RenderedPage {
  const RenderedPage({
    required this.index,
    required this.widthPx,
    required this.heightPx,
    this.textureId,
    this.imageBytes,
  }) : assert(textureId != null || imageBytes != null, '纹理与编码位图至少提供一路');

  final int index;

  /// 连续翻页 / 缩放平移走外部纹理（FFI 或 TextureRegistry 注册）。
  final int? textureId;

  /// 单页快照走 PNG/JPEG 字节：原生侧编码，或 Dart 侧用 image 包编码 FFI 位图。
  final Uint8List? imageBytes;
  final double widthPx;
  final double heightPx;

  double get aspectRatio => heightPx == 0 ? 1 : widthPx / heightPx;
}

abstract interface class BookRenderBridge {
  /// 打开文档返回句柄；同一文档只做一次初始化。
  Future<int> open(String documentId, String localPath);

  Future<int> pageCount(int handle);
  Future<PageInfo> pageInfo(int handle, int index);

  /// 按目标像素尺寸渲染，禁止原生出 4K 再在 Dart 里缩。
  Future<RenderedPage> render(int handle, int index, Size targetPx);

  /// 批量预取窗口：不要在滚动回调里逐帧调 channel。
  Future<void> prefetch(int handle, List<int> upcoming);

  /// 窗口外的页及时释放，控制漫画大图内存。
  Future<void> evict(int handle, List<int> indices);

  Future<void> close(int handle);
}

/// 降级实现：未接原生时显式抛错，绝不返回空白页造成「书打不开」的假象。
class UnimplementedRenderBridge implements BookRenderBridge {
  const UnimplementedRenderBridge([this.platform = '当前平台']);
  final String platform;

  NativeRenderUnavailable get _err => NativeRenderUnavailable('$platform 的 PDF/漫画渲染');

  @override
  Future<int> open(String documentId, String localPath) async => throw _err;
  @override
  Future<int> pageCount(int handle) async => throw _err;
  @override
  Future<PageInfo> pageInfo(int handle, int index) async => throw _err;
  @override
  Future<RenderedPage> render(int handle, int index, Size targetPx) async => throw _err;
  @override
  Future<void> prefetch(int handle, List<int> upcoming) async {}
  @override
  Future<void> evict(int handle, List<int> indices) async {}
  @override
  Future<void> close(int handle) async {}
}
