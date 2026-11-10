import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../book_document.dart';
import 'page_layout.dart';

/// 分页计算的 isolates 边界。
///
/// 设计取舍：TextPainter 依赖 Flutter binding，后台 isolate 是否可用需真机验证。
/// 因此默认走**主线程同步 + 缓存**（精确且可测）；useIsolate 是显式开关，
/// 开启后把纯数据请求交给 compute，用不依赖 binding 的 FallbackMeasurer 出结果，
/// 并在 reply 里标记 measuredExactly=false，避免悄悄产生与主线程不同的页码。
///
/// 生产建议：先在目标机型压测后台 isolate 的 TextPainter，验证通过后再统一测量器，
/// 否则「隔离计算」和「主线程计算」两套结果会让 PageAnchor 还原漂移。

@immutable
class BlockDto {
  const BlockDto({
    required this.kind,
    required this.text,
    required this.level,
    required this.keepWithNext,
    this.assetPath,
  });

  final int kind; // BlockKind.index
  final String text;
  final int level;
  final bool keepWithNext;
  final String? assetPath;

  ContentBlock toBlock() => ContentBlock(
        kind: BlockKind.values[kind],
        text: text,
        level: level,
        keepWithNext: keepWithNext,
        assetPath: assetPath,
      );

  static BlockDto from(ContentBlock b) => BlockDto(
        kind: b.kind.index,
        text: b.text,
        level: b.level,
        keepWithNext: b.keepWithNext,
        assetPath: b.assetPath,
      );
}

@immutable
class LineDto {
  const LineDto({
    required this.text,
    required this.blockIndex,
    required this.lineInBlock,
    required this.indent,
    required this.height,
    required this.isImage,
    this.imagePath,
  });

  final String text;
  final int blockIndex;
  final int lineInBlock;
  final double indent;
  final double height;
  final bool isImage;
  final String? imagePath;

  LaidOutLine toLine() => LaidOutLine(
        text: text,
        blockIndex: blockIndex,
        lineInBlock: lineInBlock,
        indent: indent,
        height: height,
        isImage: isImage,
        imagePath: imagePath,
      );

  static LineDto from(LaidOutLine l) => LineDto(
        text: l.text,
        blockIndex: l.blockIndex,
        lineInBlock: l.lineInBlock,
        indent: l.indent,
        height: l.height,
        isImage: l.isImage,
        imagePath: l.imagePath,
      );
}

@immutable
class PaginationRequest {
  const PaginationRequest({
    required this.chapterId,
    required this.blocks,
    required this.pageWidth,
    required this.pageHeight,
    required this.fontSize,
    required this.fontFamily,
    required this.lineHeight,
    required this.firstLineIndentEm,
    required this.paragraphSpacing,
    required this.orphanLines,
    required this.widowLines,
  });

  final String chapterId;
  final List<BlockDto> blocks;
  final double pageWidth;
  final double pageHeight;
  final double fontSize;
  final String? fontFamily;
  final double lineHeight;
  final double firstLineIndentEm;
  final double paragraphSpacing;
  final int orphanLines;
  final int widowLines;

  PaginationConfig toConfig() => PaginationConfig(
        pageSize: Size(pageWidth, pageHeight),
        textStyle: TextStyle(fontSize: fontSize, fontFamily: fontFamily, height: lineHeight),
        firstLineIndentEm: firstLineIndentEm,
        lineHeight: lineHeight,
        paragraphSpacing: paragraphSpacing,
        orphanLines: orphanLines,
        widowLines: widowLines,
      );
}

@immutable
class PaginationReply {
  const PaginationReply({required this.chapterId, required this.pages, required this.measuredExactly});
  final String chapterId;
  final List<List<LineDto>> pages;
  final bool measuredExactly;
}

/// 纯 Dart 估算测量器：CJK 全宽、ASCII 半宽，用于无 binding 的后台 isolate。
class FallbackMeasurer implements TextMeasurer {
  const FallbackMeasurer(this.fontSize);
  final double fontSize;

  @override
  double measure(String text, TextStyle style) {
    double w = 0;
    for (final int c in text.codeUnits) {
      if (_isCjk(c)) {
        w += fontSize;
      } else if (c < 0x80) {
        w += fontSize * 0.5;
      } else {
        w += fontSize * 0.6;
      }
    }
    return w;
  }

  static bool _isCjk(int c) =>
      (c >= 0x4E00 && c <= 0x9FFF) ||
      (c >= 0x3400 && c <= 0x4DBF) ||
      (c >= 0x3000 && c <= 0x303F) ||
      (c >= 0xFF00 && c <= 0xFFEF);
}

/// compute 的入口必须是顶层 / 静态函数，且只接收可传递的纯数据。
PaginationReply paginationEntry(PaginationRequest request) {
  final Chapter chapter = Chapter(
    id: request.chapterId,
    title: request.chapterId,
    blocks: request.blocks.map((BlockDto b) => b.toBlock()).toList(),
  );
  // 不初始化 WidgetsFlutterBinding：后台 isolate 里用纯 Dart 测量器，避免 binding 依赖。
  final PaginationResult result = PaginationEngine(
    measurer: FallbackMeasurer(request.fontSize),
  ).layout(chapter, request.toConfig());

  return PaginationReply(
    chapterId: request.chapterId,
    pages: <List<LineDto>>[
      for (final LaidOutPage p in result.pages)
        <LineDto>[for (final LaidOutLine l in p.lines) LineDto.from(l)],
    ],
    measuredExactly: false,
  );
}

/// 分页服务：同 config+chapter 命中缓存不重复算；窗口尺寸变化自动失效。
class PaginationService {
  PaginationService({this.useIsolate = false, this.measurer = const FlutterTextMeasurer()});

  /// 默认关闭。开启前需真机验证后台 isolate 的 TextPainter 可用性与页码一致性。
  final bool useIsolate;
  final TextMeasurer measurer;

  String? _cacheKey;
  PaginationResult? _cache;

  String _key(Chapter chapter, PaginationConfig config) =>
      '${chapter.id}|${config.pageSize.width.toStringAsFixed(1)}x'
      '${config.pageSize.height.toStringAsFixed(1)}|${config.fontSize}|'
      '${config.firstLineIndentEm}|${config.lineHeight}|${config.orphanLines}|${config.widowLines}|'
      '${chapter.blocks.length}|${measurer.runtimeType}|$useIsolate';

  Future<PaginationResult> layout(Chapter chapter, PaginationConfig config) async {
    final String key = _key(chapter, config);
    if (_cache != null && _cacheKey == key) return _cache!;

    PaginationResult result;
    if (useIsolate) {
      final PaginationRequest request = PaginationRequest(
        chapterId: chapter.id,
        blocks: <BlockDto>[for (final ContentBlock b in chapter.blocks) BlockDto.from(b)],
        pageWidth: config.pageSize.width,
        pageHeight: config.pageSize.height,
        fontSize: config.fontSize,
        fontFamily: config.textStyle.fontFamily,
        lineHeight: config.lineHeight,
        firstLineIndentEm: config.firstLineIndentEm,
        paragraphSpacing: config.paragraphSpacing,
        orphanLines: config.orphanLines,
        widowLines: config.widowLines,
      );
      try {
        final PaginationReply reply = await compute<PaginationRequest, PaginationReply>(
          paginationEntry,
          request,
          debugLabel: 'pagination:${chapter.id}',
        );
        result = PaginationResult(
          chapterId: reply.chapterId,
          config: config,
          pages: <LaidOutPage>[
            for (int i = 0; i < reply.pages.length; i++)
              LaidOutPage(
                index: i,
                lines: <LaidOutLine>[for (final LineDto l in reply.pages[i]) l.toLine()],
              ),
          ],
        );
      } on Object {
        // 后台 isolate 不可用时回退主线程精确计算，绝不静默返回空白页。
        result = PaginationEngine(measurer: measurer).layout(chapter, config);
      }
    } else {
      result = PaginationEngine(measurer: measurer).layout(chapter, config);
    }

    _cacheKey = key;
    _cache = result;
    return result;
  }

  void invalidate() {
    _cacheKey = null;
    _cache = null;
  }
}
