import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/model/book_document.dart';
import 'charset_bridge.dart';
import 'text_parser.dart';

/// 分界线判据：内容能不能重排。
/// 可重排文本 → 纯 Dart 解析 + Flutter 自绘；固定版式 / 位图 → 原生栅格化。
enum RenderRoute { dartText, nativeRaster, unsupported }

@immutable
class FormatRoute {
  const FormatRoute(this.route, this.note);
  final RenderRoute route;
  final String note;
}

class UnsupportedFormatException implements Exception {
  const UnsupportedFormatException(this.reason);
  final String reason;

  @override
  String toString() => 'UnsupportedFormatException: $reason';
}

abstract interface class BookParser {
  Future<BookDocument> parse(String path, Uint8List bytes);
}

class ParserRouter implements BookParser {
  const ParserRouter({required this.charset});

  final CharsetBridge charset;

  static const Map<String, FormatRoute> _routes = <String, FormatRoute>{
    'txt': FormatRoute(RenderRoute.dartText, '编码探测 + 章节切分'),
    'md': FormatRoute(RenderRoute.dartText, 'Markdown 转 ContentBlock'),
    'markdown': FormatRoute(RenderRoute.dartText, 'Markdown 转 ContentBlock'),
    'epub': FormatRoute(RenderRoute.dartText, '文字型 EPUB；图片型/固定版式改走 nativeRaster，由解析结果决定'),
    'fb2': FormatRoute(RenderRoute.dartText, '纯 Dart 抽取文本'),
    'rtf': FormatRoute(RenderRoute.dartText, '纯 Dart 抽取文本'),
    'docx': FormatRoute(RenderRoute.dartText, '纯 Dart 抽取文本与图片'),
    // 参考仓库 README 列出的 DOC / MOBI / AZW / AZW3 / PRC / HTML：
    // 老式二进制 DOC 与 MOBI 系在静态阶段只登记路由，真实解析需对应解码器（❄️ 冻结）。
    'doc': FormatRoute(RenderRoute.dartText, '老式 DOC 文本抽取（静态阶段仅登记）'),
    'mobi': FormatRoute(RenderRoute.dartText, 'MOBI 文本抽取（静态阶段仅登记）'),
    'azw': FormatRoute(RenderRoute.dartText, 'AZW 文本抽取（静态阶段仅登记）'),
    'azw3': FormatRoute(RenderRoute.dartText, 'AZW3 文本抽取（静态阶段仅登记）'),
    'prc': FormatRoute(RenderRoute.dartText, 'PRC 文本抽取（静态阶段仅登记）'),
    'html': FormatRoute(RenderRoute.dartText, '转 ContentBlock，不用 WebView'),
    'htm': FormatRoute(RenderRoute.dartText, '转 ContentBlock，不用 WebView'),
    'xhtml': FormatRoute(RenderRoute.dartText, '转 ContentBlock，不用 WebView'),
    'pdf': FormatRoute(RenderRoute.nativeRaster, 'PDFium / PDFKit / ohos PDF Kit 逐页渲染'),
    'cbz': FormatRoute(RenderRoute.nativeRaster, 'ZIP 解包 + 原生大图解码 + 纹理预取'),
    'zip': FormatRoute(RenderRoute.nativeRaster, '同 CBZ'),
    'cbr': FormatRoute(RenderRoute.nativeRaster, '仅 RAR4 及更早；RAR5 走 unsupported'),
    'rar': FormatRoute(RenderRoute.nativeRaster, '仅 RAR4 及更早；RAR5 走 unsupported'),
  };

  /// 格式分界的**唯一静态出口**：导入扫描、详情展示、正文解析都读这一张表，
  /// 不允许任何页面再维护第二份扩展名映射（否则 RAR5 / CBZ 口径会漂移）。
  static FormatRoute routeForPath(String path) {
    final String ext = extOf(path);
    return _routes[ext] ?? const FormatRoute(RenderRoute.unsupported, '未登记的格式');
  }

  /// 实例方法保留给 parse()，委托静态出口，保证两种调用完全一致。
  FormatRoute routeFor(String path) => routeForPath(path);

  static String extOf(String path) {
    final int dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  }

  @override
  Future<BookDocument> parse(String path, Uint8List bytes) async {
    final String ext = extOf(path);
    final FormatRoute route = routeForPath(path);

    // 对齐原项目口径：RAR5 / 加密包明确报错，提示转 CBZ/ZIP，不做静默失败。
    if (_isRar5(bytes)) {
      throw const UnsupportedFormatException('RAR5 暂不支持，请转换为 CBZ/ZIP');
    }
    if (_looksEncrypted(bytes, ext)) {
      throw const UnsupportedFormatException('加密压缩包暂不支持，请转换为 CBZ/ZIP');
    }

    switch (route.route) {
      case RenderRoute.dartText:
        return TextBookParser(charset: charset).parse(
          path,
          bytes,
          id: _id(path),
          title: _title(path),
          markdown: ext == 'md' || ext == 'markdown',
        );
      case RenderRoute.nativeRaster:
        // 原生栅格化格式：Dart 只保留元数据壳，正文页由 BookRenderBridge 提供。
        return BookDocument(
          id: _id(path),
          title: _title(path),
          author: '',
          chapters: const <Chapter>[],
          sourcePath: path,
          sourceFormat: _format(ext),
          requiresNativeRender: true,
        );
      case RenderRoute.unsupported:
        throw UnsupportedFormatException('${route.note}：$ext');
    }
  }

  String _title(String path) {
    final String name = path.split(RegExp(r'[/\\]')).last;
    final int dot = name.lastIndexOf('.');
    return dot < 0 ? name : name.substring(0, dot);
  }

  String _id(String path) => path.hashCode.toUnsigned(32).toString();

  SourceFormat _format(String ext) {
    switch (ext) {
      case 'pdf': return SourceFormat.pdf;
      case 'cbz': case 'zip': return SourceFormat.cbz;
      case 'cbr': case 'rar': return SourceFormat.cbr;
      case 'epub': return SourceFormat.epub;
      case 'txt': return SourceFormat.txt;
      case 'md': case 'markdown': return SourceFormat.markdown;
      case 'fb2': return SourceFormat.fb2;
      case 'rtf': return SourceFormat.rtf;
      case 'docx': return SourceFormat.docx;
      default: return SourceFormat.unknown;
    }
  }

  bool _isRar5(Uint8List b) =>
      b.length >= 8 &&
      b[0] == 0x52 && b[1] == 0x61 && b[2] == 0x72 && b[3] == 0x21 &&
      b[4] == 0x1A && b[5] == 0x07 && b[6] == 0x01 && b[7] == 0x00;

  bool _looksEncrypted(Uint8List b, String ext) {
    if (ext != 'zip' && ext != 'cbz') return false;
    // ZIP 通用位标志 bit0 置位即加密；逐个 central directory 判断由解析库完成，这里做首包快检。
    if (b.length >= 8 && b[0] == 0x50 && b[1] == 0x4B && b[2] == 0x03 && b[3] == 0x04) {
      return (b[6] & 0x01) == 0x01;
    }
    return false;
  }
}
