import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 阅读器按行划线与摘录采集的纯 Dart 模型。
///
/// 对应原 README：「keepsakes, and excerpt cards」+ 参考仓库「cycle to another excerpt」。
/// 第八轮把摘录卡做成了可切换的展示，但摘录本身仍是演示数据；
/// 本轮补上「从阅读器选行 → 归一化 → 去重 → 写入 → 统计页立即出现」的闭环。
///
/// **静态口径**：采用「按行点选」而非字符级拖选手势。真正的拖选需要
/// `TextPainter` 命中测试与跨行选区渲染，留到接 SDK 后实现（❄️ 冻结）。
/// 行锚点与归一化规则在这里一次定义，页面只调用，不自己拼字符串。

// ---------------------------------------------------------------- 划线色

enum HighlightColor { amber, rose, sage, blue }

class HighlightPalette {
  const HighlightPalette._();

  static const Map<HighlightColor, String> labels = <HighlightColor, String>{
    HighlightColor.amber: '琥珀',
    HighlightColor.rose: '胭脂',
    HighlightColor.sage: '青苔',
    HighlightColor.blue: '靛蓝',
  };

  static const Map<HighlightColor, Color> colors = <HighlightColor, Color>{
    HighlightColor.amber: Color(0xFFD9A441),
    HighlightColor.rose: Color(0xFFC8707C),
    HighlightColor.sage: Color(0xFF6E9B78),
    HighlightColor.blue: Color(0xFF6C8FC0),
  };

  /// 行底色：低 alpha，保证正文仍可读；不随阅读背景反推，四种色板本身
  /// 在纸白/米黄/护眼/夜间四档上都有足够区分。
  static Color lineTint(HighlightColor c) => colors[c]!.withOpacity(0.22);

  static Color spine(HighlightColor c) => colors[c]!;
}

// ---------------------------------------------------------------- 行锚点

/// 一行正文的位置。分页会因字号/行高/屏宽变化而重排，所以
/// **pageIndex 只是提示，不算身份**：`matches()` 比较 bookId / chapterIndex /
/// blockIndex / lineInBlock，页码漂移不影响已存摘录的高亮还原。
/// 万一连 blockIndex 都变了（解析器版本升级），再用文本兜底匹配。
@immutable
class LineRef {
  const LineRef({
    required this.bookId,
    required this.chapterIndex,
    required this.pageIndex,
    required this.blockIndex,
    required this.lineInBlock,
    required this.text,
  });

  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final int blockIndex;
  final int lineInBlock;
  final String text;

  bool matches(LineRef other) =>
      other.bookId == bookId &&
      other.chapterIndex == chapterIndex &&
      other.blockIndex == blockIndex &&
      other.lineInBlock == lineInBlock;

  /// 重排后的兜底：同章内按行文本精确相等匹配。
  bool matchesByText(LineRef other) =>
      other.bookId == bookId &&
      other.chapterIndex == chapterIndex &&
      other.text.trim() == text.trim();

  @override
  bool operator ==(Object other) =>
      other is LineRef &&
      other.bookId == bookId &&
      other.chapterIndex == chapterIndex &&
      other.pageIndex == pageIndex &&
      other.blockIndex == blockIndex &&
      other.lineInBlock == lineInBlock;

  @override
  int get hashCode =>
      Object.hash(bookId, chapterIndex, pageIndex, blockIndex, lineInBlock);
}

// ---------------------------------------------------------------- 选区

@immutable
class SelectedLine {
  const SelectedLine(this.ref);
  final LineRef ref;

  String get text => ref.text;
}

/// 单页内的选区：点一行加入、再点移除，转换成有序选区后做归一化。
@immutable
class SelectionDraft {
  const SelectionDraft({
    required this.bookId,
    required this.chapterIndex,
    required this.pageIndex,
    this.lines = const <SelectedLine>[],
  });

  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final List<SelectedLine> lines;

  static const int maxExcerptLength = 200;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
  int get count => lines.length;

  SelectionDraft toggle(LineRef ref) {
    final bool exists = lines.any((SelectedLine l) => l.ref == ref);
    final List<SelectedLine> next = List<SelectedLine>.of(lines);
    if (exists) {
      next.removeWhere((SelectedLine l) => l.ref == ref);
    } else {
      next.add(SelectedLine(ref));
    }
    return SelectionDraft(
      bookId: bookId,
      chapterIndex: chapterIndex,
      pageIndex: pageIndex,
      lines: List<SelectedLine>.unmodifiable(next),
    );
  }

  SelectionDraft clear() => SelectionDraft(
        bookId: bookId,
        chapterIndex: chapterIndex,
        pageIndex: pageIndex,
      );

  /// 翻页 / 换章时选区必须清空：一行锚点只在它所在的那一页有意义。
  SelectionDraft switchTo(
          {required int chapterIndex, required int pageIndex}) =>
      SelectionDraft(
        bookId: bookId,
        chapterIndex: chapterIndex,
        pageIndex: pageIndex,
      );

  /// 按 blockIndex / lineInBlock 排序：用户倒着点选也能拼成通顺的一段。
  List<SelectedLine> get ordered {
    final List<SelectedLine> out = List<SelectedLine>.of(lines);
    out.sort((SelectedLine a, SelectedLine b) {
      final int byBlock = a.ref.blockIndex.compareTo(b.ref.blockIndex);
      return byBlock != 0
          ? byBlock
          : a.ref.lineInBlock.compareTo(b.ref.lineInBlock);
    });
    return List<SelectedLine>.unmodifiable(out);
  }

  /// 相邻选行是否连续（同一 block 内行号递增 1）。
  /// 跨段落选区允许，但会在采集面板里提示「跨段落摘录」。
  bool get isContiguous {
    final List<SelectedLine> o = ordered;
    for (int i = 1; i < o.length; i++) {
      final LineRef a = o[i - 1].ref;
      final LineRef b = o[i].ref;
      if (a.blockIndex == b.blockIndex && b.lineInBlock - a.lineInBlock != 1)
        return false;
    }
    return true;
  }

  bool get spansParagraphs {
    final List<SelectedLine> o = ordered;
    if (o.length < 2) return false;
    return o.first.ref.blockIndex != o.last.ref.blockIndex;
  }

  /// 归一化正文：每行 trim、丢掉空行与纯标点行、直接拼接（中文正文不插空格）。
  /// 不做截断——截断会破坏去重签名；长度越界由 isValid 拦下并让面板提示。
  String normalizedText() {
    final StringBuffer buf = StringBuffer();
    for (final SelectedLine l in ordered) {
      final String t = l.text.trim();
      if (t.isEmpty || _isPunctuationOnly(t)) continue;
      buf.write(t);
    }
    return buf.toString();
  }

  static bool _isPunctuationOnly(String s) {
    const String punct = '，。、；：？！「」『』（）《》〈〉…—·,.;:?!"\'()[]{}<>~ \t\r\n';
    for (final int unit in s.codeUnits) {
      if (!punct.codeUnits.contains(unit)) return false;
    }
    return true;
  }

  /// 去重签名：同一本书、同一章里，去掉空白与标点后相同的一句只存一次。
  /// 不依赖 hashCode（不同进程会变），直接拼可读字符串。
  String signature() {
    final String norm = normalizedText();
    final String stripped = norm
        .replaceAll(
            RegExp(r'[\s，。、；：？！「」『』（）《》〈〉…—·,.;:?!\u0022\u0027()\[\]{}<>~]'),
            '')
        .toLowerCase();
    final String head =
        stripped.length > 80 ? stripped.substring(0, 80) : stripped;
    return '$bookId|$chapterIndex|$head';
  }

  bool get isValid {
    final String t = normalizedText();
    return t.isNotEmpty && t.length <= maxExcerptLength && lines.isNotEmpty;
  }

  String? get validationMessage {
    if (lines.isEmpty) return '先点选正文中的一行或多行';
    final String t = normalizedText();
    if (t.isEmpty) return '选中的行没有可摘录的文字';
    if (t.length > maxExcerptLength) {
      return '摘录最长 $maxExcerptLength 字，当前 ${t.length} 字，请少选几行';
    }
    return null;
  }

  ExcerptDraft toDraft({
    required HighlightColor highlight,
    String note = '',
  }) {
    final List<SelectedLine> o = ordered;
    return ExcerptDraft(
      bookId: bookId,
      chapterIndex: chapterIndex,
      pageIndex: pageIndex,
      text: normalizedText(),
      signature: signature(),
      highlight: highlight,
      note: note.trim(),
      origin: o.isEmpty ? null : o.first.ref,
      crossParagraph: spansParagraphs,
    );
  }
}

// ---------------------------------------------------------------- 草稿

/// 从阅读器交给 AppState 的写入请求。刻意不引用 `Excerpt` 类型，
/// 避免 excerpt_capture.dart 反向依赖 reading_stats.dart。
@immutable
class ExcerptDraft {
  const ExcerptDraft({
    required this.bookId,
    required this.chapterIndex,
    required this.pageIndex,
    required this.text,
    required this.signature,
    required this.highlight,
    this.note = '',
    this.origin,
    this.crossParagraph = false,
  });

  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final String text;
  final String signature;
  final HighlightColor highlight;
  final String note;
  final LineRef? origin;
  final bool crossParagraph;

  ExcerptDraft copyWith({
    String? bookId,
    int? chapterIndex,
    int? pageIndex,
    String? text,
    String? signature,
    HighlightColor? highlight,
    String? note,
    LineRef? origin,
    bool? crossParagraph,
  }) =>
      ExcerptDraft(
        bookId: bookId ?? this.bookId,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        pageIndex: pageIndex ?? this.pageIndex,
        text: text ?? this.text,
        signature: signature ?? this.signature,
        highlight: highlight ?? this.highlight,
        note: note ?? this.note,
        origin: origin ?? this.origin,
        crossParagraph: crossParagraph ?? this.crossParagraph,
      );
}
