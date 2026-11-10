import 'package:flutter/foundation.dart';

import 'excerpt_capture.dart';
import 'reading_stats.dart';

/// 阅读器划线在**重排后**的还原策略（第十九轮）。
///
/// 第九轮采集闭环里，页面直接手写了一段双重循环：
/// `for (e in highlights) if (origin.matches(ref) || origin.matchesByText(ref))`
/// 取第一个命中就高亮。它有三个问题：
/// 1. 每行对全部摘录做 O(n·m) 扫描，没有索引；
/// 2. 「重排后行号漂移」和「同章里出现两句一模一样的话」被混成同一种兜底，
///    后者会被随机高亮到错误的位置；
/// 3. 没有任何置信度概念，页面无法告诉用户「这行是精确还原还是猜的」。
///
/// 本层把策略收口成纯 Dart 模型，**页面只调 `resolve()`**。判定顺序：
///
/// | 优先级 | 条件 | 置信度 | 是否自动高亮 |
/// | --- | --- | --- | --- |
/// | 1 | 书 / 章 / 块 / 行号相同 **且** 行文本相同 | `exact` | ✅ |
/// | 2 | 书 / 章 / 块 / 行号相同、文本已变 | `structural` | ✅（标「位置一致、文字已变」） |
/// | 3 | 行号漂移，但该文本在**本章**只被一条摘录引用 | `textUnique` | ✅（标「按文本还原」） |
/// | 4 | 同一文本在本章被多条摘录引用，或多个锚点抢同一位置 | `ambiguous` | ❌ 显式不自动高亮 |
/// | 5 | 无匹配 | `none` | — |
///
/// **pageIndex 永不参与身份**（与 `LineRef.matches` 一致）：字号、行高、屏宽
/// 一变就整章重排，页码只是提示。这是整个模型成立的前提。
///
/// **静态边界**：不承诺跨重排 100% 还原。歧义明确返回 `ambiguous` 且不自动
/// 高亮，宁可少画一笔也不画错位置；字符级拖选、`TextPainter` 命中测试、
/// 摘录持久化仍 ❄️ 冻结。跨段落摘录目前只保存首行锚点，因此只还原首行，
/// 多行锚点留待接 SDK 后扩展——文档与规格单测都写明这条口径。
enum AnchorConfidence { exact, structural, textUnique, ambiguous, none }

class AnchorConfidenceLabels {
  const AnchorConfidenceLabels._();

  static const Map<AnchorConfidence, String> labels = <AnchorConfidence, String>{
    AnchorConfidence.exact: '精确还原',
    AnchorConfidence.structural: '位置一致 · 文字已变',
    AnchorConfidence.textUnique: '重排后按文本还原',
    AnchorConfidence.ambiguous: '多处相同文本 · 待确认',
    AnchorConfidence.none: '未匹配',
  };

  static const Map<AnchorConfidence, bool> shouldHighlight = <AnchorConfidence, bool>{
    AnchorConfidence.exact: true,
    AnchorConfidence.structural: true,
    AnchorConfidence.textUnique: true,
    AnchorConfidence.ambiguous: false,
    AnchorConfidence.none: false,
  };
}

@immutable
class LineAnchorMatch {
  const LineAnchorMatch({
    required this.excerptId,
    required this.highlight,
    required this.confidence,
    required this.candidateCount,
  });

  final String excerptId;
  final HighlightColor highlight;
  final AnchorConfidence confidence;
  final int candidateCount;

  bool get shouldHighlight =>
      AnchorConfidenceLabels.shouldHighlight[confidence]!;

  String get note => AnchorConfidenceLabels.labels[confidence]!;

  @override
  bool operator ==(Object other) =>
      other is LineAnchorMatch &&
      other.excerptId == excerptId &&
      other.highlight == highlight &&
      other.confidence == confidence &&
      other.candidateCount == candidateCount;

  @override
  int get hashCode => Object.hash(excerptId, highlight, confidence, candidateCount);
}

@immutable
class _AnchorEntry {
  const _AnchorEntry(this.excerptId, this.highlight, this.anchor);

  final String excerptId;
  final HighlightColor highlight;
  final LineRef anchor;
}

/// 按「书 + 章」建索引的还原器。构造一次，整章复用；列表变化必须重建。
class LineAnchorResolver {
  LineAnchorResolver._(this._byScope);

  /// 唯一构造口。无锚点的摘录（演示种子）直接跳过，不参与索引。
  factory LineAnchorResolver.from(Iterable<Excerpt> excerpts) {
    final Map<String, List<_AnchorEntry>> byScope = <String, List<_AnchorEntry>>{};
    for (final Excerpt e in excerpts) {
      final LineRef? anchor = e.origin;
      if (anchor == null) continue;
      final String key = scopeKeyOf(anchor);
      byScope.putIfAbsent(key, () => <_AnchorEntry>[]).add(
            _AnchorEntry(e.id, e.highlight, anchor),
          );
    }
    return LineAnchorResolver._(
      Map<String, List<_AnchorEntry>>.unmodifiable(byScope),
    );
  }

  final Map<String, List<_AnchorEntry>> _byScope;

  static String scopeKeyOf(LineRef ref) => '${ref.bookId}|${ref.chapterIndex}';

  int get anchorCount =>
      _byScope.values.fold<int>(0, (int n, List<_AnchorEntry> v) => n + v.length);

  /// 解析一行的还原结果；返回 null 表示完全没有候选锚点。
  LineAnchorMatch? resolve(LineRef line) {
    final List<_AnchorEntry>? entries = _byScope[scopeKeyOf(line)];
    if (entries == null || entries.isEmpty) return null;

    final String trimmed = line.text.trim();

    // ① 位置 + 文本全等。
    final List<_AnchorEntry> exact = entries
        .where((_AnchorEntry e) =>
            e.anchor.matches(line) && e.anchor.text.trim() == trimmed)
        .toList();
    if (exact.isNotEmpty) return _pick(exact, AnchorConfidence.exact);

    // ② 位置相同、文本已变（解析器改了空白 / 标点，或用户换了版本）。
    final List<_AnchorEntry> structural =
        entries.where((_AnchorEntry e) => e.anchor.matches(line)).toList();
    if (structural.isNotEmpty) return _pick(structural, AnchorConfidence.structural);

    // ③ 行号漂移，按行文本兜底。复用 LineRef.matchesByText，不另写一份口径。
    final List<_AnchorEntry> byText =
        entries.where((_AnchorEntry e) => e.anchor.matchesByText(line)).toList();
    if (byText.isEmpty) return null;
    return _pick(byText, AnchorConfidence.textUnique);
  }

  /// 多条摘录引用同一位置 / 同一文本时不猜，返回 ambiguous 且不自动高亮。
  LineAnchorMatch _pick(List<_AnchorEntry> candidates, AnchorConfidence success) {
    final Set<String> ids =
        candidates.map<String>((_AnchorEntry e) => e.excerptId).toSet();
    final AnchorConfidence confidence =
        ids.length > 1 ? AnchorConfidence.ambiguous : success;
    return LineAnchorMatch(
      excerptId: candidates.first.excerptId,
      highlight: candidates.first.highlight,
      confidence: confidence,
      candidateCount: candidates.length,
    );
  }

  /// 整章批量解析，保持输入顺序。页面可一次拿到结果再渲染，避免逐行重复扫描。
  List<LineAnchorMatch?> resolveLines(Iterable<LineRef> lines) =>
      List<LineAnchorMatch?>.unmodifiable(
        lines.map<LineAnchorMatch?>(resolve),
      );
}
