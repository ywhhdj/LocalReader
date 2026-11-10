import 'package:flutter/foundation.dart';

import 'reader_style.dart';

/// 每本书独立保存的排版覆盖（第二十四轮）。
///
/// 参考仓库 README：「Save fonts, size, weight, letter spacing, line height,
/// and all four margins per book」。之前 `ReaderStyle` 是**全局**的，改一本
/// 会波及全部书；本模型把「按书保存」与「全局默认」分开，且只有一个裁决点
/// `effectiveStyle()`。
///
/// 字段全部 nullable：null = 沿用全局 `ReaderStyle`，不复制第二份默认值。
/// 这样全局改字号时，没有单独设置过的书会跟着变，符合「默认 + 覆盖」语义。
@immutable
class PerBookStyle {
  const PerBookStyle({
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.letterSpacing,
    this.lineHeight,
    this.marginLeft,
    this.marginTop,
    this.marginRight,
    this.marginBottom,
    this.alignment,
  });

  final String? fontFamily;
  final double? fontSize;
  final double? fontWeight;
  final double? letterSpacing;
  final double? lineHeight;
  final double? marginLeft;
  final double? marginTop;
  final double? marginRight;
  final double? marginBottom;
  final ReaderTextAlignment? alignment;

  static const PerBookStyle empty = PerBookStyle();

  bool get isEmpty =>
      fontFamily == null &&
      fontSize == null &&
      fontWeight == null &&
      letterSpacing == null &&
      lineHeight == null &&
      marginLeft == null &&
      marginTop == null &&
      marginRight == null &&
      marginBottom == null &&
      alignment == null;

  /// 只有真正设置的字段才写进覆盖，避免把「沿用的全局值」固化成书级快照。
  PerBookStyle withOverrides({
    String? fontFamily,
    double? fontSize,
    double? fontWeight,
    double? letterSpacing,
    double? lineHeight,
    double? marginLeft,
    double? marginTop,
    double? marginRight,
    double? marginBottom,
    ReaderTextAlignment? alignment,
  }) =>
      PerBookStyle(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        fontWeight: fontWeight ?? this.fontWeight,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        lineHeight: lineHeight ?? this.lineHeight,
        marginLeft: marginLeft ?? this.marginLeft,
        marginTop: marginTop ?? this.marginTop,
        marginRight: marginRight ?? this.marginRight,
        marginBottom: marginBottom ?? this.marginBottom,
        alignment: alignment ?? this.alignment,
      );

  PerBookStyle cleared() => empty;

  Map<String, Object> toMap() => <String, Object>{
        if (fontFamily != null) 'fontFamily': fontFamily!,
        if (fontSize != null) 'fontSize': fontSize!,
        if (fontWeight != null) 'fontWeight': fontWeight!,
        if (letterSpacing != null) 'letterSpacing': letterSpacing!,
        if (lineHeight != null) 'lineHeight': lineHeight!,
        if (marginLeft != null) 'marginLeft': marginLeft!,
        if (marginTop != null) 'marginTop': marginTop!,
        if (marginRight != null) 'marginRight': marginRight!,
        if (marginBottom != null) 'marginBottom': marginBottom!,
        if (alignment != null) 'alignment': alignment!.name,
      };

  static PerBookStyle fromMap(Map<dynamic, dynamic> m) {
    double? number(String key) {
      final Object? v = m[key];
      return v is num ? v.toDouble() : null;
    }

    // nullable 语义：toMap 只在 alignment != null 时写键。缺键 / 非法值
    // 必须回落 null（沿用全局），不能给个 justify 默认值 —— 那会把
    // 「沿用全局默认」悄悄固化成书级快照（第二十四轮口径）。
    ReaderTextAlignment? alignmentOrNull(Object? raw) {
      if (raw is! String) return null;
      for (final ReaderTextAlignment a in ReaderTextAlignment.values) {
        if (a.name == raw) return a;
      }
      return null;
    }

    return PerBookStyle(
      fontFamily: m['fontFamily'] is String ? m['fontFamily'] as String : null,
      fontSize: number('fontSize'),
      fontWeight: number('fontWeight'),
      letterSpacing: number('letterSpacing'),
      lineHeight: number('lineHeight'),
      marginLeft: number('marginLeft'),
      marginTop: number('marginTop'),
      marginRight: number('marginRight'),
      marginBottom: number('marginBottom'),
      alignment: alignmentOrNull(m['alignment']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PerBookStyle &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.fontWeight == fontWeight &&
      other.letterSpacing == letterSpacing &&
      other.lineHeight == lineHeight &&
      other.marginLeft == marginLeft &&
      other.marginTop == marginTop &&
      other.marginRight == marginRight &&
      other.marginBottom == marginBottom &&
      other.alignment == alignment;

  @override
  int get hashCode => Object.hash(
        fontFamily, fontSize, fontWeight, letterSpacing, lineHeight,
        marginLeft, marginTop, marginRight, marginBottom, alignment,
      );
}

/// 对齐方式。参考仓库提到「preview indentation, alignment」，独立成枚举避免
/// 页面里散写字符串。
enum ReaderTextAlignment { left, justify, center }

/// **唯一裁决点**：书级覆盖 → 全局默认。页面 / 排版引擎都只认这个出口，
/// 不自己拼 `TextStyle`，也不各自解释「null 是什么意思」。
@immutable
class EffectiveReaderStyle {
  const EffectiveReaderStyle({
    required this.global,
    required this.override,
    required this.bookId,
  });

  final ReaderStyle global;
  final PerBookStyle override;
  final String bookId;

  static EffectiveReaderStyle resolve(
    ReaderStyle global,
    Map<String, PerBookStyle> overrides,
    String bookId,
  ) =>
      EffectiveReaderStyle(
        global: global,
        override: overrides[bookId] ?? PerBookStyle.empty,
        bookId: bookId,
      );

  String get fontFamily => override.fontFamily ?? 'NotoSerifSC';
  double get fontSize => override.fontSize ?? global.fontSize;
  double get fontWeight => override.fontWeight ?? 400;
  double get letterSpacing => override.letterSpacing ?? 0;
  double get lineHeight => override.lineHeight ?? global.lineHeight;
  double get marginLeft => override.marginLeft ?? 20;
  double get marginTop => override.marginTop ?? 16;
  double get marginRight => override.marginRight ?? 20;
  double get marginBottom => override.marginBottom ?? 16;
  ReaderTextAlignment get alignment =>
      override.alignment ?? ReaderTextAlignment.justify;

  bool get isBookSpecific => !override.isEmpty;

  /// 与 `ReaderStyle.layoutKey` 同构：书级排版变了才重排，换背景不重排。
  String get layoutKey => 'pb|$fontSize|${lineHeight.toStringAsFixed(2)}|'
      '$fontWeight|$letterSpacing|$marginLeft|$marginTop|$marginRight|'
      '$marginBottom|$fontFamily|${alignment.name}';
}
