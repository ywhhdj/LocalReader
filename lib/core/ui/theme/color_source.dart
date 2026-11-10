import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../../model/reader_style.dart';

/// 配色来源（第二十四轮）。
///
/// 参考仓库 README：「Use system Monet colors, choose an accent, or extract colors
/// from an image. Set reader-specific colors and backgrounds.」
///
/// 三种来源只在这里裁决，**应用配色与阅读器配色分开**：选了强调色不会把
/// 阅读背景改掉（第六轮已定「阅读背景独立于 Material 明暗主题」）。
enum ColorSourceKind { systemDynamic, customAccent, fromCover }

@immutable
class ColorSource {
  const ColorSource({
    this.kind = ColorSourceKind.systemDynamic,
    this.accent = const Color(0xFF6E8CA8),
    this.coverSeed = const Color(0xFF6E8CA8),
  });

  final ColorSourceKind kind;
  final Color accent;
  final Color coverSeed;

  /// 唯一出口：给 `GlassTheme` 的 seed。系统动态色在静态阶段回落内置 seed，
  /// 真机接入 `DynamicColorBuilder` 时由平台层注入，页面不解释规则。
  Color seedFor({Color? platformDynamicSeed}) {
    switch (kind) {
      case ColorSourceKind.systemDynamic:
        return platformDynamicSeed ?? const Color(0xFF6E8CA8);
      case ColorSourceKind.customAccent:
        return accent;
      case ColorSourceKind.fromCover:
        return coverSeed;
    }
  }

  ColorSource copyWith({
    ColorSourceKind? kind,
    Color? accent,
    Color? coverSeed,
  }) =>
      ColorSource(
        kind: kind ?? this.kind,
        accent: accent ?? this.accent,
        coverSeed: coverSeed ?? this.coverSeed,
      );

  @override
  bool operator ==(Object other) =>
      other is ColorSource &&
      other.kind == kind &&
      other.accent == accent &&
      other.coverSeed == coverSeed;

  @override
  int get hashCode => Object.hash(kind, accent, coverSeed);
}

/// 阅读器独立色与背景。文字色沿用 `ReaderStyle.onColor` 的亮度反推，
/// 不在这里写第二份映射，避免「面板显示对比度」与「实际文字色」分裂。
@immutable
class ReaderColorScheme {
  const ReaderColorScheme({
    required this.background,
    required this.textColor,
    required this.opacity,
  });

  factory ReaderColorScheme.derive(Color background, {double opacity = 1.0}) =>
      ReaderColorScheme(
        background: background,
        textColor: ReaderContrast.onColor(background),
        opacity: opacity.clamp(0.5, 1.0).toDouble(),
      );

  final Color background;
  final Color textColor;
  final double opacity;

  double get contrast => ReaderContrast.ratio(background, textColor);

  bool get meetsMinimum => contrast >= 4.5;
}

/// 对比度计算**复用** `ReaderStyle` 的静态实现，不写第二份公式，
/// 否则「排版面板显示 5.2:1」和「阅读器实际配色」会悄悄分裂。
class ReaderContrast {
  const ReaderContrast._();

  static Color onColor(Color bg) => ReaderStyle.onColor(bg);

  static double ratio(Color a, Color b) => ReaderStyle.contrastRatio(a, b);
}
