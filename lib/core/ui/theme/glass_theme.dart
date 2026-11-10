import 'package:flutter/material.dart';

import '../../common/design_tokens.dart';
import 'season_scheme.dart';

/// 编辑式排版：衬线标题 + 无衬线正文，固定字阶与行高，靠留白和细规则线建立层级。
class GlassTheme {
  const GlassTheme._();

  static const String _serif = 'Noto Serif SC';
  static const String _sans = 'Noto Sans SC';
  static const List<String> _serifFallback = <String>['Songti SC', 'SimSun', 'serif'];
  static const List<String> _sansFallback = <String>['PingFang SC', 'Microsoft YaHei', 'sans-serif'];

  /// 季节样式由 AppScope 注入：MaterialApp 的 theme 随季节重建，
  /// 四个 tab 都能通过 Theme.extension<LrSeasonTheme>() 拿到同一套色板。
  /// 明暗各取该季节自己的变体（SeasonSchemes），五种手账在深色下不再长得一样。
  static ThemeData light([SeasonStyle style = SeasonStyle.paper]) =>
      _base(Brightness.light, SeasonSchemes.resolve(style, Brightness.light));

  static ThemeData dark([SeasonStyle style = SeasonStyle.winter]) =>
      _base(Brightness.dark, SeasonSchemes.resolve(style, Brightness.dark));

  static ThemeData _base(Brightness brightness, SeasonPalette palette) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      surface: isDark ? const Color(0xFF15171C) : palette.seed,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      textTheme: editorialTextTheme(isDark ? const Color(0xFFF2F2F4) : const Color(0xFF25231F)),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _serifStyle(22, isDark ? const Color(0xFFF2F2F4) : const Color(0xFF25231F), FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        thickness: 1,
        space: 1,
      ),
      extensions: <ThemeExtension<dynamic>>[LrSeasonTheme(palette: palette)],
    );
  }

  /// 让页面可通过 Theme.of(context).extension<LrSeasonTheme>() 读取季节色板。
  static TextTheme editorialTextTheme(Color onSurface) {
    final Color secondary = onSurface.withOpacity(0.62);
    return TextTheme(
      displayLarge: _serifStyle(40, onSurface, FontWeight.w700, height: 1.25),
      displayMedium: _serifStyle(32, onSurface, FontWeight.w700, height: 1.3),
      headlineLarge: _serifStyle(28, onSurface, FontWeight.w600, height: 1.35),
      headlineMedium: _serifStyle(22, onSurface, FontWeight.w600, height: 1.4),
      titleLarge: _serifStyle(18, onSurface, FontWeight.w600, height: 1.45),
      titleMedium: _sansStyle(16, onSurface, FontWeight.w600, height: 1.5),
      bodyLarge: _sansStyle(16, onSurface, FontWeight.w400, height: 1.75),
      bodyMedium: _sansStyle(14, onSurface, FontWeight.w400, height: 1.7),
      bodySmall: _sansStyle(12, secondary, FontWeight.w400, height: 1.6),
      labelLarge: _sansStyle(14, onSurface, FontWeight.w600, letterSpacing: 0.4),
      labelMedium: _sansStyle(12, secondary, FontWeight.w500),
      labelSmall: _sansStyle(11, secondary, FontWeight.w500, letterSpacing: 1.2),
    );
  }

  static TextStyle _serifStyle(double size, Color color, FontWeight weight,
          {double? height, double? letterSpacing}) =>
      TextStyle(
        fontFamily: _serif,
        fontFamilyFallback: _serifFallback,
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle _sansStyle(double size, Color color, FontWeight weight,
          {double? height, double? letterSpacing}) =>
      TextStyle(
        fontFamily: _sans,
        fontFamilyFallback: _sansFallback,
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      );
}

/// 季节主题扩展：切换时只需重建 MaterialApp 的 theme，组件结构不动。
@immutable
class LrSeasonTheme extends ThemeExtension<LrSeasonTheme> {
  final SeasonPalette palette;

  const LrSeasonTheme({required this.palette});

  @override
  LrSeasonTheme copyWith({SeasonPalette? palette}) => LrSeasonTheme(palette: palette ?? this.palette);

  @override
  LrSeasonTheme lerp(ThemeExtension<LrSeasonTheme>? other, double t) {
    if (other is! LrSeasonTheme) return this;
    return LrSeasonTheme(palette: t < 0.5 ? palette : other.palette);
  }
}
