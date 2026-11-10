import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/book_document.dart';
import 'line_break_rules.dart';

/// 测量器抽象：分页计算可放 isolate / 可注入伪测量器做单测，不必依赖真实渲染树。
abstract interface class TextMeasurer {
  double measure(String text, TextStyle style);
}

class FlutterTextMeasurer implements TextMeasurer {
  const FlutterTextMeasurer();

  @override
  double measure(String text, TextStyle style) {
    if (text.isEmpty) return 0;
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
  }
}

@immutable
class PaginationConfig {
  const PaginationConfig({
    required this.pageSize,
    required this.textStyle,
    this.firstLineIndentEm = 2,
    this.lineHeight = 1.75,
    this.paragraphSpacing = 0.45,
    this.orphanLines = 2,
    this.widowLines = 2,
  });

  /// 已减去左右 padding 的可用区域（逻辑像素）。
  final Size pageSize;
  final TextStyle textStyle;

  /// 段落首行缩进 = 字号 × N；续行一律 0。
  final double firstLineIndentEm;
  final double lineHeight;
  final double paragraphSpacing;

  /// 段末至少留几行在下页（orphan control）。
  final int orphanLines;

  /// 段首至少几行必须留在本页，否则整段推到下页（widow control）。
  final int widowLines;

  double get fontSize => textStyle.fontSize ?? 16;
  double get indentPx => fontSize * firstLineIndentEm;
  double get linePx => fontSize * lineHeight;
  double get paragraphGapPx => linePx * paragraphSpacing;
  double get contentWidth => pageSize.width;
}

@immutable
class LaidOutLine {
  const LaidOutLine({
    required this.text,
    required this.blockIndex,
    required this.lineInBlock,
    required this.indent,
    required this.height,
    this.isImage = false,
    this.imagePath,
  });

  final String text;
  final int blockIndex;
  final int lineInBlock;
  final double indent;
  final double height;
  final bool isImage;
  final String? imagePath;
}

@immutable
class LaidOutPage {
  const LaidOutPage({required this.index, required this.lines});
  final int index;
  final List<LaidOutLine> lines;
}

@immutable
class PaginationResult {
  const PaginationResult({required this.chapterId, required this.pages, required this.config});
  final String chapterId;
  final List<LaidOutPage> pages;
  final PaginationConfig config;

  PageAnchor anchorFor(int pageIndex) {
    if (pages.isEmpty || pageIndex < 0 || pageIndex >= pages.length) {
      return const PageAnchor(chapterIndex: 0, pageIndex: 0, blockIndex: 0, lineIndex: 0, charOffset: 0);
    }
    final LaidOutLine first = pages[pageIndex].lines.first;
    return PageAnchor(
      chapterIndex: 0,
      pageIndex: pageIndex,
      blockIndex: first.blockIndex,
      lineIndex: first.lineInBlock,
      charOffset: 0,
    );
  }
}

/// 分页引擎：LocalReader 原「章节按屏幕尺寸实时分页、段落首行缩进、孤儿行控制、
/// 跨页续块不重复缩进」的纯 Dart 实现。
class PaginationEngine {
  const PaginationEngine({this.measurer = const FlutterTextMeasurer()});

  final TextMeasurer measurer;

  PaginationResult layout(Chapter chapter, PaginationConfig config) {
    final List<_BlockGroup> groups = _mergeKeepWithNext(_buildGroups(chapter, config));
    return PaginationResult(
      chapterId: chapter.id,
      pages: _paginate(groups, config),
      config: config,
    );
  }

  List<_BlockGroup> _buildGroups(Chapter chapter, PaginationConfig config) {
    final List<_BlockGroup> groups = <_BlockGroup>[];
    for (int bi = 0; bi < chapter.blocks.length; bi++) {
      final ContentBlock b = chapter.blocks[bi];
      if (b.isPageBreak) {
        groups.add(_BlockGroup(blockIndex: bi, lines: const <LaidOutLine>[], isBreak: true));
        continue;
      }
      if (b.isImage) {
        groups.add(_BlockGroup(
          blockIndex: bi,
          isImage: true,
          lines: <LaidOutLine>[
            LaidOutLine(
              text: '',
              blockIndex: bi,
              lineInBlock: 0,
              indent: 0,
              height: config.pageSize.height * 0.6,
              isImage: true,
              imagePath: b.assetPath,
            ),
          ],
        ));
        continue;
      }
      groups.add(_BlockGroup(
        blockIndex: bi,
        lines: _breakLines(b, bi, config),
        keepWithNext: b.keepWithNext,
      ));
    }
    return groups;
  }

  /// 标题 keepWithNext：与下一段合并成同一个不可拆单元，避免标题落在页底。
  List<_BlockGroup> _mergeKeepWithNext(List<_BlockGroup> src) {
    final List<_BlockGroup> out = <_BlockGroup>[];
    for (int i = 0; i < src.length; i++) {
      _BlockGroup g = src[i];
      while (g.keepWithNext && i + 1 < src.length && !src[i + 1].isBreak) {
        i++;
        g = _BlockGroup(
          blockIndex: g.blockIndex,
          lines: <LaidOutLine>[...g.lines, ...src[i].lines],
          keepWithNext: src[i].keepWithNext,
        );
      }
      out.add(g);
    }
    return out;
  }

  List<LaidOutLine> _breakLines(ContentBlock block, int blockIndex, PaginationConfig config) {
    final String text = block.text;
    final TextStyle style = config.textStyle;
    final bool indentFirst = block.kind == BlockKind.paragraph || block.kind == BlockKind.quote;
    final double firstIndent = indentFirst ? config.indentPx : 0;
    final List<LaidOutLine> lines = <LaidOutLine>[];

    int cursor = 0;
    int lineInBlock = 0;
    while (cursor < text.length) {
      final double available = lineInBlock == 0 ? config.contentWidth - firstIndent : config.contentWidth;
      int end = _fit(text, cursor, available, style);
      if (end <= cursor) end = math.min(cursor + 1, text.length);
      end = _wordBoundary(text, cursor, end);
      // 中文标点避头尾：断行后二次校正，end 恒 > cursor，不会死循环。
      end = LineBreakRules.adjustEnd(text, cursor, end);

      lines.add(LaidOutLine(
        text: text.substring(cursor, end),
        blockIndex: blockIndex,
        lineInBlock: lineInBlock,
        // 关键：只有段首行缩进；段落被拆到下一页时，续行 indent 仍为 0，
        // 即「跨页续块不重复缩进」。
        indent: lineInBlock == 0 ? firstIndent : 0,
        height: config.linePx,
      ));
      cursor = end;
      lineInBlock++;
    }
    if (lines.isEmpty) {
      lines.add(LaidOutLine(
        text: '',
        blockIndex: blockIndex,
        lineInBlock: 0,
        indent: 0,
        height: config.linePx,
      ));
    }
    return lines;
  }

  /// 二分找最大不超宽前缀，避免逐字符 O(n²)。
  int _fit(String text, int start, double width, TextStyle style) {
    int lo = start;
    int hi = text.length;
    while (lo < hi) {
      final int mid = (lo + hi + 1) >> 1;
      if (measurer.measure(text.substring(start, mid), style) <= width) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// 英文按词回退断点；中文逐字断行不受影响。
  /// 中文标点避头尾由 LineBreakRules.adjustEnd 在本调用之后二次校正。
  int _wordBoundary(String text, int start, int end) {
    if (end >= text.length) return end;
    final bool beforeIsWord = _isAsciiWord(text.codeUnitAt(end - 1));
    final bool afterIsWord = _isAsciiWord(text.codeUnitAt(end));
    if (!beforeIsWord || !afterIsWord) return end;
    for (int i = end - 1; i > start; i--) {
      if (text.codeUnitAt(i) == 0x20) return i + 1;
    }
    return end;
  }

  bool _isAsciiWord(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39);

  List<LaidOutPage> _paginate(List<_BlockGroup> groups, PaginationConfig config) {
    final List<LaidOutPage> pages = <LaidOutPage>[];
    List<LaidOutLine> current = <LaidOutLine>[];
    double used = 0;
    final double cap = config.pageSize.height;

    void flush() {
      if (current.isEmpty) return;
      pages.add(LaidOutPage(index: pages.length, lines: List<LaidOutLine>.unmodifiable(current)));
      current = <LaidOutLine>[];
      used = 0;
    }

    for (final _BlockGroup g in groups) {
      if (g.isBreak) {
        flush();
        continue;
      }
      final double gap = g.isImage ? 0 : config.paragraphGapPx;
      final double groupHeight =
          g.lines.fold<double>(0, (double s, LaidOutLine l) => s + l.height) + gap;

      // 整段放得下就整段放，优先不拆段。
      if (used + groupHeight <= cap) {
        current.addAll(g.lines);
        used += groupHeight;
        continue;
      }

      // 放不下：段落从新页开始（避免段尾孤零零挂在页底）。
      flush();

      if (groupHeight <= cap) {
        current.addAll(g.lines);
        used = groupHeight;
        continue;
      }

      // 超长段必须跨页：保证下页至少 orphanLines 行、本页至少 widowLines 行。
      final int capLines = math.max(1, (cap / config.linePx).floor());
      int offset = 0;
      while (offset < g.lines.length) {
        final int remaining = g.lines.length - offset;
        int take;
        if (remaining <= capLines + config.orphanLines) {
          // 剩余行数不够「本页放满 + 下页留够 orphanLines」：
          // 不拆段，宁可本页略超，也不把段尾孤行留给下一页。
          // 前面已 flush，此处位于新页开头，不会叠加到已有内容上。
          take = remaining;
        } else {
          take = math.min(capLines, remaining - config.orphanLines);
          // widow 控制已在上面「整段放不下就 flush、段落从新页开始」处生效：
          // 那一步保证不会出现段首单独挂在页底。此处已在空页，推无可推，
          // 若可放行数仍不足 widowLines，退化为按容量填满，避免死循环。
          if (take < config.widowLines) take = math.min(capLines, remaining);
        }
        if (take <= 0) take = math.min(capLines, remaining);

        current.addAll(g.lines.sublist(offset, offset + take));
        used = take * config.linePx;
        offset += take;
        if (offset < g.lines.length) flush();
      }
    }
    flush();
    return pages;
  }
}

@immutable
class _BlockGroup {
  const _BlockGroup({
    required this.blockIndex,
    this.lines = const <LaidOutLine>[],
    this.isBreak = false,
    this.isImage = false,
    this.keepWithNext = false,
  });

  final int blockIndex;
  final List<LaidOutLine> lines;
  final bool isBreak;
  final bool isImage;
  final bool keepWithNext;
}
