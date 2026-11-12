import 'package:flutter/material.dart';

/// 统一设计 token：页面里禁止硬编码圆角 / 模糊 / 间距 / 颜色。
class LrSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class LrRadius {
  static const double card = 8;
  static const double panel = 16;
  static const double pill = 999;
  static const double spine = 5;
}

class LrBlur {
  static const double sigmaX = 18;
  static const double sigmaY = 18;
}

/// 对应参考仓库的「五种视觉样式 / 季节手账」：换肤只换色板，不改组件结构。
enum SeasonStyle { paper, sakura, summer, autumn, winter }

class SeasonPalette {
  final String label;
  final Color seed;
  final Color accent;
  final List<Color> shelfWood;
  final List<Color> glassTint;

  const SeasonPalette({
    required this.label,
    required this.seed,
    required this.accent,
    required this.shelfWood,
    required this.glassTint,
  });

  static const Map<SeasonStyle, SeasonPalette> all =
      <SeasonStyle, SeasonPalette>{
    SeasonStyle.paper: SeasonPalette(
      label: '纸白',
      seed: Color(0xFFF4F1EA),
      accent: Color(0xFF8A6A4F),
      shelfWood: <Color>[Color(0xFFD9C7AE), Color(0xFFB99A78)],
      glassTint: <Color>[Color(0xCCFFFFFF), Color(0x99F4F1EA)],
    ),
    SeasonStyle.sakura: SeasonPalette(
      label: '春樱',
      seed: Color(0xFFF7E8EC),
      accent: Color(0xFFB4677C),
      shelfWood: <Color>[Color(0xFFE7C6CD), Color(0xFFC99AA6)],
      glassTint: <Color>[Color(0xCCFFFFFF), Color(0x99F7E8EC)],
    ),
    SeasonStyle.summer: SeasonPalette(
      label: '夏汐',
      seed: Color(0xFFE4F0EF),
      accent: Color(0xFF3F8079),
      shelfWood: <Color>[Color(0xFFBBD8D3), Color(0xFF8FBDB6)],
      glassTint: <Color>[Color(0xCCFFFFFF), Color(0x99E4F0EF)],
    ),
    SeasonStyle.autumn: SeasonPalette(
      label: '秋笺',
      seed: Color(0xFFF5E7D3),
      accent: Color(0xFFA96433),
      shelfWood: <Color>[Color(0xFFDFC29C), Color(0xFFBC9463)],
      glassTint: <Color>[Color(0xCCFFFFFF), Color(0x99F5E7D3)],
    ),
    SeasonStyle.winter: SeasonPalette(
      label: '冬寂',
      seed: Color(0xFFE9EDF3),
      accent: Color(0xFF4A6180),
      shelfWood: <Color>[Color(0xFFC6CEDA), Color(0xFF98A5B8)],
      glassTint: <Color>[Color(0xCCFFFFFF), Color(0x99E9EDF3)],
    ),
  };
}

class LrFontSize {
  static const double samll = 11;
  static const double noraml = 14;
  static const double big = 16;
}
