import 'dart:ui' show Locale;

import 'package:Local_reader/l10n/l10n_catalog.g.dart';
import 'package:flutter/foundation.dart';

import 'legal_texts.dart';
import 'lr_localizations.dart';

const Map<String, List<String>> kCatalogLists = <String, List<String>>{
  "aboutParagraphs": <String>[
    "aboutParagraph1",
    "aboutParagraph2",
    "aboutParagraph3",
    "aboutParagraph4",
    "aboutParagraph5",
    "aboutParagraph6"
  ],
};

/// ARB 实体键数量（自检 / 预览面板读取）。
const int kCatalogKeyCount = 898;

/// 带 placeholder 的键数量。
const int kCatalogPlaceholderKeyCount = 127;

/// 英文仍含中文片段、建议在 ARB 里人工润色的键数量（如实统计，不隐藏）。
const int kCatalogReviewKeyCount = 83;

enum AppLanguage { zhCN, en }

extension AppLanguageX on AppLanguage {
  Locale get locale {
    switch (this) {
      case AppLanguage.zhCN:
        return const Locale('zh');
      case AppLanguage.en:
        return const Locale('en');
    }
  }

  String get label {
    switch (this) {
      case AppLanguage.zhCN:
        return lrText('uiSimplifiedChinese');
      case AppLanguage.en:
        return lrText('uiEnglish');
    }
  }

  bool get isDefault => this == AppLanguage.zhCN;
}

/// 一份语言的完整文案。值直接引用 ARB 生成的 catalog（const 引用合法），
/// 因此「键集合」仍可被机器逐键校验，而译文只在 ARB 里有一份。
@immutable
class LegalTextBundle {
  const LegalTextBundle({
    required this.values,
    required this.lists,
    required this.locale,
  });

  final Map<String, String> values;
  final Map<String, List<String>> lists;
  final Locale locale;

  bool has(String key) => values.containsKey(key) || lists.containsKey(key);

  /// 未知键直接抛错，绝不静默返回空串掩盖 ARB 缺项。
  String value(String key) {
    final String? v = values[key];
    if (v == null || v.isEmpty) {
      throw ArgumentError.value(key, 'key', 'ARB 文案表缺项或空值');
    }
    return v;
  }

  /// 列表型文案：`kCatalogLists` 存成员键，逐条从当前语言 catalog 取值。
  List<String> list(String key) {
    final List<String>? members = lists[key];
    if (members == null || members.isEmpty) {
      throw ArgumentError.value(key, 'key', 'ARB 文案表缺列表或为空');
    }
    return members.map(value).toList(growable: false);
  }

  Map<String, String> snapshot() => Map<String, String>.unmodifiable(values);
}


const LegalTextBundle kLegalTextsZh = LegalTextBundle(
  values: kZhCatalog,
  lists: kCatalogLists,
  locale: Locale('zh'),
);

const LegalTextBundle kLegalTextsEn = LegalTextBundle(
  values: kEnCatalog,
  lists: kCatalogLists,
  locale: Locale('en'),
);

class LocalizedLegalTexts {
  const LocalizedLegalTexts._();

  static const Locale defaultLocale = Locale('zh');

  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  static const Map<Locale, LegalTextBundle> bundles = <Locale, LegalTextBundle>{
    Locale('zh'): kLegalTextsZh,
    Locale('en'): kLegalTextsEn,
  };

  static Locale normalize(Locale locale) {
    if (bundles.containsKey(locale)) return locale;
    for (final Locale supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
    return defaultLocale;
  }

  static LegalTextBundle of(Locale locale) => bundles[normalize(locale)]!;

  static String value(Locale locale, String key) => of(locale).value(key);

  static Map<String, String> snapshot(Locale locale) => of(locale).snapshot();

  static AppLanguage languageOf(Locale locale) =>
      normalize(locale).languageCode == 'en'
          ? AppLanguage.en
          : AppLanguage.zhCN;

  static Locale localeOf(AppLanguage language) => language.locale;

  /// ARB 全量实体键数量（不再是「业务键子集」）。
  static int get keyCount => kCatalogKeyCount;

  static int get listCount => kCatalogLists.length;

  static int get placeholderKeyCount => kCatalogPlaceholderKeyCount;

  /// 英文仍含中文片段、建议在 ARB 里人工润色的键数（如实统计，不隐藏）。
  static int get reviewKeyCount => kCatalogReviewKeyCount;

  /// `LegalTexts.keys` 必须在两份 catalog 里都有值；`aboutParagraphs`
  /// 是列表键，走 `kCatalogLists` 校验。
  static List<String> missingKeys(Locale locale) {
    final LegalTextBundle bundle = of(locale);
    final List<String> out = <String>[];
    for (final String key in LegalTexts.keys) {
      if (key == 'aboutParagraphs') {
        if (!bundle.lists.containsKey(key)) out.add(key);
      } else if (!bundle.values.containsKey(key) ||
          bundle.values[key]!.isEmpty) {
        out.add(key);
      }
    }
    return out;
  }

  /// 保留 API：现在 ARB 是唯一源，不再存在「bundle 里多出来的键」。
  static List<String> extraKeys(Locale locale) => const <String>[];

  /// `aboutParagraphs` 中英条数必须一致，否则「关于与问题反馈」会缺条。
  static bool paragraphsAligned() {
    final List<String>? members = kCatalogLists['aboutParagraphs'];
    if (members == null || members.isEmpty) return false;
    final int zh =
        members.where((String k) => (kZhCatalog[k] ?? '').isNotEmpty).length;
    final int en =
        members.where((String k) => (kEnCatalog[k] ?? '').isNotEmpty).length;
    return zh == en && zh == members.length;
  }
}
