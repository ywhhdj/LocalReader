import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'l10n_catalog.g.dart';

/// 应用文案的唯一运行时出口（第二十八轮起）。
///
/// **所有可翻译文案只在 `lib/l10n/app_zh.arb` / `app_en.arb` 里维护**；
/// `l10n_catalog.g.dart` 是 `tool/sync_arb.py` 从 ARB 生成的 Dart 镜像，
/// 本文件只做「按 locale 选表 + placeholder 替换 + 三级回退」，不含任何译文。
///
/// 框架侧（Material / Cupertino / RTL）仍由 `flutter_localizations` 的
/// Global*Localizations 负责，官方 `AppLocalizations` 由 `flutter pub get`
/// 依 `l10n.yaml` 生成；两条链路共用同一个 `MaterialApp.locale`。
@immutable
class LrLocalizations {
  LrLocalizations(this.locale)
      : normalized = _normalize(locale),
        catalog = _catalogFor(locale);

  final Locale locale;
  final Locale normalized;
  final Map<String, String> catalog;

  /// 由 `LrLocalizationsDelegate.load()` 写入。只给「没有 BuildContext 的
  /// 静态数据 / 纯 helper」兜底用；页面主体一律走 `context.t` / `context.tArgs`。
  static LrLocalizations? active;

  static const List<Locale> supportedLocales = <Locale>[
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN'),
    Locale.fromSubtags(languageCode: 'en'),
  ];

  static const Locale defaultLocale = Locale('zh', 'CN');

  static bool isSupported(Locale locale) =>
      locale.languageCode == 'zh' || locale.languageCode == 'en';

  /// 三级回退：精确 → 按 languageCode（zh_TW → zh_CN、en_US → en）→ 中文默认。
  static Locale _normalize(Locale locale) {
    if (locale.languageCode == 'zh') return defaultLocale;
    if (locale.languageCode == 'en') return const Locale('en');
    return defaultLocale;
  }

  static Map<String, String> _catalogFor(Locale locale) =>
      _normalize(locale).languageCode == 'zh' ? kZhCatalog : kEnCatalog;

  bool get isChinese => normalized.languageCode == 'zh';

  /// 未知键直接抛错，绝不返回空串掩盖 ARB 缺项。
  String value(String key) {
    final String? v = catalog[key];
    if (v == null || v.isEmpty) {
      throw ArgumentError.value(key, 'key', 'ARB 文案表缺项或空值');
    }
    return v;
  }

  /// ARB 里的 `{p0}` / `{p1}` ... 按参数顺序替换。
  String valueArgs(String key, List<Object?> args) => formatCatalog(value(key), args);

  /// 列表型文案：`kCatalogLists` 给出成员键顺序，逐条取当前语言的值。
  List<String> list(String key) {
    final List<String>? members = kCatalogLists[key];
    if (members == null || members.isEmpty) {
      throw ArgumentError.value(key, 'key', 'ARB 文案表缺列表或为空');
    }
    return members.map(value).toList(growable: false);
  }

  static LrLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<LrLocalizations>(context, LrLocalizations);

  static LrLocalizations of(BuildContext context) {
    final LrLocalizations? l = maybeOf(context);
    assert(l != null, 'LrLocalizationsDelegate 未挂到 MaterialApp.localizationsDelegates');
    return l!;
  }
}

/// 顶层纯函数：把 ARB 模板里的 `{pN}` 替换成实际值。
/// `LrLocalizations.valueArgs` 与全局兜底出口共用，避免两套替换口径。
String formatCatalog(String template, List<Object?> args) {
  String out = template;
  for (int i = 0; i < args.length; i++) {
    out = out.replaceAll('{p$i}', args[i]?.toString() ?? '');
  }
  return out;
}

/// `shouldReload` 恒 false：catalog 与 locale 都是 immutable，
/// 切换语言由 MaterialApp 重建 Localizations widget 完成（官方机制）。
class LrLocalizationsDelegate extends LocalizationsDelegate<LrLocalizations> {
  const LrLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => LrLocalizations.isSupported(locale);

  @override
  Future<LrLocalizations> load(Locale locale) {
    final LrLocalizations l = LrLocalizations(locale);
    LrLocalizations.active = l;
    return SynchronousFuture<LrLocalizations>(l);
  }

  @override
  bool shouldReload(covariant LrLocalizationsDelegate old) => false;
}

/// 页面唯一的文案出口。**feature 层不得直接引用 `LegalTexts` 的中文值，
/// 不得留裸中文字面量，也不得再写 `label('中文')`**——静态自检会拦。
extension LrTextX on BuildContext {
  LrLocalizations get l10n => LrLocalizations.of(this);

  /// 业务 / 合规 / 空状态 / UI 短标签，统一按 ARB 键取值。
  String t(String key) => l10n.value(key);

  /// 带 `{pN}` placeholder 的 ARB 模板。
  String tArgs(String key, List<Object?> args) => l10n.valueArgs(key, args);

  /// 列表型文案。
  List<String> tList(String key) => l10n.list(key);

  Locale get l10nLocale => l10n.locale;
}

/// 没有 BuildContext 的静态数据 / 纯 helper 用的兜底出口。
/// delegate 尚未 load 时回落中文 catalog，绝不返回空串或英文占位符。
String lrText(String key) {
  final LrLocalizations? l = LrLocalizations.active;
  if (l != null) return l.value(key);
  final String? v = kZhCatalog[key];
  if (v == null || v.isEmpty) {
    throw ArgumentError.value(key, 'key', 'ARB 文案表缺项或空值');
  }
  return v;
}

String lrTextArgs(String key, List<Object?> args) => formatCatalog(lrText(key), args);

List<String> lrList(String key) {
  final LrLocalizations? l = LrLocalizations.active;
  if (l != null) return l.list(key);
  final List<String>? members = kCatalogLists[key];
  if (members == null || members.isEmpty) {
    throw ArgumentError.value(key, 'key', 'ARB 文案表缺列表或为空');
  }
  return members.map((String k) => kZhCatalog[k] ?? '').toList(growable: false);
}
