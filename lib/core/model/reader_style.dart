import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'comic/comic_spread.dart';
import 'comic/comic_toc.dart';
import 'pagination/page_layout.dart';

/// 阅读背景：对应原项目「纸白 / 米黄 / 夜间 / 护眼」四档。
enum ReaderBackground { paper, cream, night, eyeCare }

/// 翻页动效：平移 / 仿真（伪 3D 绕书脊）/ 无动画。
enum ReaderPageTurn { slide, simulation, none }

/// 阅读排版设置。与 AppSettings 一起持久化（静态阶段为内存），
/// 阅读器 / 排版面板 / 「我的」页读同一份，不允许页面各自存半套字号。
@immutable
class ReaderStyle {
  const ReaderStyle({
    this.fontSize = 17,
    this.lineHeight = 1.75,
    this.firstLineIndentEm = 2,
    this.paragraphSpacing = 0.45,
    this.orphanLines = 2,
    this.widowLines = 2,
    this.background = ReaderBackground.paper,
    this.pageTurn = ReaderPageTurn.slide,
    this.ttsRate = 1.0,
    this.ttsPitch = 1.0,
    this.keepScreenOn = false,
    this.volumeKeyTurnPage = false,
    this.comicReadMode = ComicReadMode.vertical,
    this.comicSpreadMode = ComicSpreadMode.single,
    this.comicDirection = ComicReadingDirection.ltr,
    this.widePageSolo = true,
  });

  final double fontSize;
  final double lineHeight;
  final double firstLineIndentEm;
  final double paragraphSpacing;
  final int orphanLines;
  final int widowLines;
  final ReaderBackground background;
  final ReaderPageTurn pageTurn;
  final double ttsRate;
  final double ttsPitch;

  /// 以下两项需要平台能力；静态交付模式下只记录偏好，不声称已生效。
  final bool keepScreenOn;
  final bool volumeKeyTurnPage;

  /// 漫画阅读模式：竖向连续 / 横向跨页翻页。**不进 layoutKey**——
  /// 换模式不该触发小说章节重新分页。
  final ComicReadMode comicReadMode;

  /// 双页跨页偏好：单页 / 双页 / 自动（横屏自动双页）。
  /// **只在 paged 模式生效**；竖向连续没有左右概念，由 AppSettings.normalized() 锁回单页。
  final ComicSpreadMode comicSpreadMode;

  /// 翻页方向：左→右 / 右→左（日漫）。同样只在 paged 模式生效。
  final ComicReadingDirection comicDirection;

  /// 第十九轮：宽幅页（横幅 / 跨页彩图）是否独占一跨，不与邻页并排。
  /// **只在双页 paged 模式有意义**；竖向 / 单页模式每页本来就独占，保留偏好但不生效。
  /// 与另三个漫画字段一样刻意不进 layoutKey——换一次设置不该重排整章小说。
  final bool widePageSolo;

  static const Map<ReaderBackground, Color> backgroundColors = <ReaderBackground, Color>{
    ReaderBackground.paper: Color(0xFFF7F5EF),
    ReaderBackground.cream: Color(0xFFF2E5C6),
    ReaderBackground.night: Color(0xFF191B21),
    ReaderBackground.eyeCare: Color(0xFFDCE7D4),
  };

  static const Map<ReaderBackground, String> backgroundLabels = <ReaderBackground, String>{
    ReaderBackground.paper: '纸白',
    ReaderBackground.cream: '米黄',
    ReaderBackground.night: '夜间',
    ReaderBackground.eyeCare: '护眼',
  };

  static const Map<ReaderPageTurn, String> pageTurnLabels = <ReaderPageTurn, String>{
    ReaderPageTurn.slide: '平移',
    ReaderPageTurn.simulation: '仿真',
    ReaderPageTurn.none: '无动画',
  };

  Color get backgroundColor => backgroundColors[background]!;
  String get backgroundLabel => backgroundLabels[background]!;
  String get pageTurnLabel => pageTurnLabels[pageTurn]!;

  /// 正文与面板文字色由背景亮度自动反推，任意背景下都保证对比度。
  /// 阈值 0.42 是亮度而非「是否夜间」，所以护眼绿会取深色字、夜间取浅色字。
  static Color onColor(Color bg) => relativeLuminance(bg) > 0.42
      ? const Color(0xFF23262D)
      : const Color(0xFFECE9E1);

  Color get textColor => onColor(backgroundColor);
  Color get subtleTextColor => textColor.withOpacity(0.62);

  /// WCAG 相对亮度（sRGB gamma 展开），纯 Dart 可单测，不依赖 SDK 运行。
  static double relativeLuminance(Color c) {
    double channel(int shift) {
      final double v = ((c.value >> shift) & 0xFF) / 255.0;
      return v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }
    return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
  }

  static double contrastRatio(Color a, Color b) {
    final double la = relativeLuminance(a);
    final double lb = relativeLuminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// 正文对比度；WCAG AA 正文要求 ≥ 4.5。面板里也展示这个值，
  /// 让「自动反推」不是一句空话，而是可验证的约束。
  double get bodyContrast => contrastRatio(backgroundColor, textColor);

  /// 分页缓存键：**只包含影响排版的字段**。
  /// 换背景 / 换翻页动效 / 改语速都不该触发重新分页，否则翻一页就重排一次。
  String get layoutKey => 'fs${fontSize.toStringAsFixed(2)}|'
      'lh${lineHeight.toStringAsFixed(2)}|'
      'ind${firstLineIndentEm.toStringAsFixed(2)}|'
      'ps${paragraphSpacing.toStringAsFixed(2)}|'
      'orphan$orphanLines|widow$widowLines';
  // comicReadMode 刻意不在此；comicSpreadMode / comicDirection / widePageSolo 同理：
  // 四者只影响漫画页的跨页编排，换一次设置就重排整章小说是最典型的误伤。

  /// 唯一出口：把阅读偏好翻译成分页引擎的配置。
  /// 文字色在这里注入，页面层不再自己拼 TextStyle，避免主题与排版各说各话。
  PaginationConfig toPaginationConfig(Size pageSize, TextStyle base) => PaginationConfig(
        pageSize: pageSize,
        textStyle: base.copyWith(
          fontSize: fontSize,
          height: lineHeight,
          color: textColor,
        ),
        firstLineIndentEm: firstLineIndentEm,
        lineHeight: lineHeight,
        paragraphSpacing: paragraphSpacing,
        orphanLines: orphanLines,
        widowLines: widowLines,
      );

  ReaderStyle copyWith({
    double? fontSize,
    double? lineHeight,
    double? firstLineIndentEm,
    double? paragraphSpacing,
    int? orphanLines,
    int? widowLines,
    ReaderBackground? background,
    ReaderPageTurn? pageTurn,
    double? ttsRate,
    double? ttsPitch,
    bool? keepScreenOn,
    bool? volumeKeyTurnPage,
    ComicReadMode? comicReadMode,
    ComicSpreadMode? comicSpreadMode,
    ComicReadingDirection? comicDirection,
    bool? widePageSolo,
  }) =>
      ReaderStyle(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        firstLineIndentEm: firstLineIndentEm ?? this.firstLineIndentEm,
        paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
        orphanLines: orphanLines ?? this.orphanLines,
        widowLines: widowLines ?? this.widowLines,
        background: background ?? this.background,
        pageTurn: pageTurn ?? this.pageTurn,
        ttsRate: ttsRate ?? this.ttsRate,
        ttsPitch: ttsPitch ?? this.ttsPitch,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        volumeKeyTurnPage: volumeKeyTurnPage ?? this.volumeKeyTurnPage,
        comicReadMode: comicReadMode ?? this.comicReadMode,
        comicSpreadMode: comicSpreadMode ?? this.comicSpreadMode,
        comicDirection: comicDirection ?? this.comicDirection,
        widePageSolo: widePageSolo ?? this.widePageSolo,
      );

  Map<String, Object> toMap() => <String, Object>{
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'firstLineIndentEm': firstLineIndentEm,
        'paragraphSpacing': paragraphSpacing,
        'orphanLines': orphanLines,
        'widowLines': widowLines,
        'background': background.name,
        'pageTurn': pageTurn.name,
        'ttsRate': ttsRate,
        'ttsPitch': ttsPitch,
        'keepScreenOn': keepScreenOn,
        'volumeKeyTurnPage': volumeKeyTurnPage,
        'comicReadMode': comicReadMode.name,
        'comicSpreadMode': comicSpreadMode.name,
        'comicDirection': comicDirection.name,
        'widePageSolo': widePageSolo,
      };

  static ReaderStyle fromMap(Map<dynamic, dynamic> m) {
    T enumValue<T extends Enum>(String key, List<T> values, T fallback) {
      final Object? raw = m[key];
      if (raw is! String) return fallback;
      for (final T v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    double numAsDouble(String key, double fallback) {
      final Object? v = m[key];
      return v is num ? v.toDouble() : fallback;
    }

    int numAsInt(String key, int fallback) {
      final Object? v = m[key];
      return v is num ? v.toInt() : fallback;
    }

    bool boolValue(String key, bool fallback) {
      final Object? v = m[key];
      return v is bool ? v : fallback;
    }

    return ReaderStyle(
      fontSize: numAsDouble('fontSize', 17),
      lineHeight: numAsDouble('lineHeight', 1.75),
      firstLineIndentEm: numAsDouble('firstLineIndentEm', 2),
      paragraphSpacing: numAsDouble('paragraphSpacing', 0.45),
      orphanLines: numAsInt('orphanLines', 2),
      widowLines: numAsInt('widowLines', 2),
      background: enumValue<ReaderBackground>('background', ReaderBackground.values, ReaderBackground.paper),
      pageTurn: enumValue<ReaderPageTurn>('pageTurn', ReaderPageTurn.values, ReaderPageTurn.slide),
      ttsRate: numAsDouble('ttsRate', 1.0),
      ttsPitch: numAsDouble('ttsPitch', 1.0),
      keepScreenOn: boolValue('keepScreenOn', false),
      volumeKeyTurnPage: boolValue('volumeKeyTurnPage', false),
      comicReadMode: enumValue<ComicReadMode>(
        'comicReadMode', ComicReadMode.values, ComicReadMode.vertical),
      comicSpreadMode: enumValue<ComicSpreadMode>(
        'comicSpreadMode', ComicSpreadMode.values, ComicSpreadMode.single),
      comicDirection: enumValue<ComicReadingDirection>(
        'comicDirection', ComicReadingDirection.values, ComicReadingDirection.ltr),
      widePageSolo: boolValue('widePageSolo', true),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderStyle &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.firstLineIndentEm == firstLineIndentEm &&
      other.paragraphSpacing == paragraphSpacing &&
      other.orphanLines == orphanLines &&
      other.widowLines == widowLines &&
      other.background == background &&
      other.pageTurn == pageTurn &&
      other.ttsRate == ttsRate &&
      other.ttsPitch == ttsPitch &&
      other.keepScreenOn == keepScreenOn &&
      other.volumeKeyTurnPage == volumeKeyTurnPage &&
      other.comicReadMode == comicReadMode &&
      other.comicSpreadMode == comicSpreadMode &&
      other.comicDirection == comicDirection &&
      other.widePageSolo == widePageSolo;

  @override
  int get hashCode => Object.hash(
        fontSize,
        lineHeight,
        firstLineIndentEm,
        paragraphSpacing,
        orphanLines,
        widowLines,
        background,
        pageTurn,
        ttsRate,
        ttsPitch,
        keepScreenOn,
        volumeKeyTurnPage,
        comicReadMode,
        comicSpreadMode,
        comicDirection,
        widePageSolo,
      );
}
