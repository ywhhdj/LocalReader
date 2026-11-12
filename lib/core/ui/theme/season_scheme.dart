import 'package:flutter/material.dart';

import '../../common/design_tokens.dart';

/// 五种季节手账的**明暗对照表**。
@immutable
class SeasonScheme {
  const SeasonScheme({required this.light, required this.dark});

  final SeasonPalette light;
  final SeasonPalette dark;

  SeasonPalette resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

class SeasonSchemes {
  const SeasonSchemes._();

  static const Map<SeasonStyle, SeasonScheme> all = <SeasonStyle, SeasonScheme>{
    SeasonStyle.paper: SeasonScheme(
      light: SeasonPalette(
        label: '纸白',
        seed: Color(0xFFF4F1EA),
        accent: Color(0xFF8A6A4F),
        shelfWood: <Color>[Color(0xFFD9C7AE), Color(0xFFB99A78)],
        glassTint: <Color>[Color(0xCCFFFFFF), Color(0x99F4F1EA)],
      ),
      dark: SeasonPalette(
        label: '纸白 · 夜',
        seed: Color(0xFF1C1B18),
        accent: Color(0xFFCDA97E),
        shelfWood: <Color>[Color(0xFF4A4034), Color(0xFF2E2820)],
        glassTint: <Color>[Color(0x26FFFFFF), Color(0x331C1B18)],
      ),
    ),
    SeasonStyle.sakura: SeasonScheme(
      light: SeasonPalette(
        label: '春樱',
        seed: Color(0xFFF7E8EC),
        accent: Color(0xFFB4677C),
        shelfWood: <Color>[Color(0xFFE7C6CD), Color(0xFFC99AA6)],
        glassTint: <Color>[Color(0xCCFFFFFF), Color(0x99F7E8EC)],
      ),
      dark: SeasonPalette(
        label: '春樱 · 夜',
        seed: Color(0xFF201A1D),
        accent: Color(0xFFE2A2B4),
        shelfWood: <Color>[Color(0xFF4A333A), Color(0xFF2E2126)],
        glassTint: <Color>[Color(0x26FFFFFF), Color(0x33201A1D)],
      ),
    ),
    SeasonStyle.summer: SeasonScheme(
      light: SeasonPalette(
        label: '夏汐',
        seed: Color(0xFFE4F0EF),
        accent: Color(0xFF3F8079),
        shelfWood: <Color>[Color(0xFFBBD8D3), Color(0xFF8FBDB6)],
        glassTint: <Color>[Color(0xCCFFFFFF), Color(0x99E4F0EF)],
      ),
      dark: SeasonPalette(
        label: '夏汐 · 夜',
        seed: Color(0xFF16211F),
        accent: Color(0xFF7FC7BE),
        shelfWood: <Color>[Color(0xFF2C4540), Color(0xFF1D302C)],
        glassTint: <Color>[Color(0x26FFFFFF), Color(0x3316211F)],
      ),
    ),
    SeasonStyle.autumn: SeasonScheme(
      light: SeasonPalette(
        label: '秋笺',
        seed: Color(0xFFF5E7D3),
        accent: Color(0xFFA96433),
        shelfWood: <Color>[Color(0xFFDFC29C), Color(0xFFBC9463)],
        glassTint: <Color>[Color(0xCCFFFFFF), Color(0x99F5E7D3)],
      ),
      dark: SeasonPalette(
        label: '秋笺 · 夜',
        seed: Color(0xFF211C15),
        accent: Color(0xFFD9A16C),
        shelfWood: <Color>[Color(0xFF4A3822), Color(0xFF2E2315)],
        glassTint: <Color>[Color(0x26FFFFFF), Color(0x33211C15)],
      ),
    ),
    SeasonStyle.winter: SeasonScheme(
      light: SeasonPalette(
        label: '冬寂',
        seed: Color(0xFFE9EDF3),
        accent: Color(0xFF4A6180),
        shelfWood: <Color>[Color(0xFFC6CEDA), Color(0xFF98A5B8)],
        glassTint: <Color>[Color(0xCCFFFFFF), Color(0x99E9EDF3)],
      ),
      dark: SeasonPalette(
        label: '冬寂 · 夜',
        seed: Color(0xFF171A20),
        accent: Color(0xFFA1B6D8),
        shelfWood: <Color>[Color(0xFF333B48), Color(0xFF212732)],
        glassTint: <Color>[Color(0x26FFFFFF), Color(0x33171A20)],
      ),
    ),
  };

  static SeasonScheme of(SeasonStyle style) => all[style]!;

  static SeasonPalette resolve(SeasonStyle style, Brightness brightness) =>
      of(style).resolve(brightness);

  /// 供配置面板预览：不跟随系统，强制指定明暗。
  static SeasonPalette preview(SeasonStyle style, {Brightness brightness = Brightness.light}) =>
      resolve(style, brightness);

  static List<SeasonStyle> get styles => SeasonStyle.values;
}
