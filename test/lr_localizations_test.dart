import 'dart:ui' show Locale;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/content/legal_texts.dart';
import 'package:local_reader/core/content/localized_texts.dart';
import 'package:local_reader/core/content/lr_localizations.dart';
import 'package:local_reader/core/content/ui_labels.dart';
import 'package:local_reader/core/state/app_settings.dart';

void main() {
  group('官方 locale 装配模型', () {
    test('supportedLocales 用 fromSubtags 区分中文变体', () {
      expect(LrLocalizations.supportedLocales.length, 2);
      expect(LrLocalizations.supportedLocales.first.scriptCode, 'Hans');
      expect(LrLocalizations.supportedLocales.first.countryCode, 'CN');
      expect(LrLocalizations.supportedLocales.last.languageCode, 'en');
    });

    test('isSupported 按 languageCode', () {
      expect(LrLocalizations.isSupported(const Locale('zh')), isTrue);
      expect(LrLocalizations.isSupported(const Locale('en', 'US')), isTrue);
      expect(LrLocalizations.isSupported(const Locale('fr')), isFalse);
    });

    test('中文变体按官方「最近匹配」回退到 zh_cn', () {
      final LrLocalizations l = LrLocalizations(const Locale.fromSubtags(
          languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'));
      expect(l.isChinese, isTrue);
      expect(l.normalized, const Locale('zh'));
      expect(l.value('appDisclaimer'), LegalTexts.appDisclaimer);
    });

    test('英文取英文 bundle，中文取中文 bundle', () {
      final LrLocalizations zh = LrLocalizations(const Locale('zh'));
      final LrLocalizations en = LrLocalizations(const Locale('en'));
      expect(zh.value('appDisclaimer'), isNot(en.value('appDisclaimer')));
      expect(zh.value('appDisclaimer'), contains('第三方'));
      expect(en.value('appDisclaimer'), contains('third-party'));
    });

    test('未知键抛错，不返回空串', () {
      expect(() => LrLocalizations(const Locale('zh')).value('nope'),
          throwsArgumentError);
    });

    test('列表型文案中英条数对齐', () {
      expect(LrLocalizations(const Locale('zh')).list('aboutParagraphs').length,
          6);
      expect(LrLocalizations(const Locale('en')).list('aboutParagraphs').length,
          6);
    });
  });

  group('delegate', () {
    test('load 同步完成且写入 active', () async {
      const LrLocalizationsDelegate d = LrLocalizationsDelegate();
      final LrLocalizations l = await d.load(const Locale('en'));
      expect(l.isChinese, isFalse);
      expect(LrLocalizations.active, same(l));
    });

    test('shouldReload 恒 false（immutable，语言切换由 MaterialApp 重建）', () {
      const LrLocalizationsDelegate d = LrLocalizationsDelegate();
      expect(d.shouldReload(d), isFalse);
    });

    test('lrText / lrLabel 在 active 未加载时回落中文', () {
      LrLocalizations.active = null;
      expect(lrText('appDisclaimer'), LegalTexts.appDisclaimer);
      expect(lrLabel('书架'), '书架');
      LrLocalizations.active = LrLocalizations(const Locale('en'));
      expect(lrLabel('书架'), 'Shelf');
    });
  });

  group('UI 标签三层查找', () {
    test('中文 locale 原样返回，零误译', () {
      expect(UiLabels.localize('共 12 册', true), '共 12 册');
    });

    test('精确映射', () {
      expect(UiLabels.localize('书架', false), 'Shelf');
      expect(UiLabels.localize('轻小说文库', false), 'Light Novels');
      expect(UiLabels.coverageLevel('书架'), 1);
    });

    test('数值模板按英文语序重排', () {
      expect(UiLabels.localize('共 12 册', false), '12 books');
      expect(UiLabels.localize('第 3 章', false), 'Chapter 3');
      expect(UiLabels.coverageLevel('共 12 册'), 2);
    });

    test('片段兜底', () {
      final String out = UiLabels.localize('当前筛选命中 8 / 11 册；', false);
      expect(out, isNot(contains('当前')));
      expect(UiLabels.coverageLevel('当前筛选命中 8 / 11 册；'), 3);
    });

    test('兜底出口不机翻整句，只替换已登记片段', () {
      expect(UiLabels.coverageLevel('完全未登记的一句话'), 0);
    });

    test('core 枚举标签值也在精确表内', () {
      for (final String v in <String>[
        '竖向连续',
        '横向翻页',
        '安全模式',
        '继续阅读',
        '这本书的摘录'
      ]) {
        expect(UiLabels.zhToEn.containsKey(v), isTrue, reason: v);
      }
    });
  });

  group('语言偏好归一化', () {
    test('默认跟随系统（null），默认中文口径不变', () {
      expect(const AppSettings().appLanguage, isNull);
      expect(const AppSettings().pureLocal, isTrue);
    });

    test('显式语言可设置、可清空，copyWith 不把 null 当成「没传」', () {
      const AppSettings a = AppSettings();
      final AppSettings b = a.copyWith(appLanguage: AppLanguage.en);
      expect(b.appLanguage, AppLanguage.en);
      expect(b.copyWith(appLanguage: AppLanguage.zhCN).appLanguage,
          AppLanguage.zhCN);
      expect(b.copyWith(clearAppLanguage: true).appLanguage, isNull);
    });

    test('序列化往返保留语言，缺省回落 null', () {
      final AppSettings a =
          const AppSettings().copyWith(appLanguage: AppLanguage.en);
      final AppSettings back = AppSettings.fromMap(a.toMap());
      expect(back.appLanguage, AppLanguage.en);
      expect(AppSettings.fromMap(<String, Object?>{}).appLanguage, isNull);
      expect(
          AppSettings.fromMap(<String, Object?>{'appLanguage': 'bogus'})
              .appLanguage,
          isNull);
    });

    test('值语义包含语言字段', () {
      const AppSettings a = AppSettings();
      final AppSettings b = a.copyWith(appLanguage: AppLanguage.en);
      expect(a == b, isFalse);
      expect(a.copyWith(appLanguage: AppLanguage.en), b);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('normalized() 不动语言字段', () {
      final AppSettings s =
          const AppSettings(pureLocal: false, onlineDirectory: true)
              .copyWith(appLanguage: AppLanguage.en);
      expect(s.normalized().appLanguage, AppLanguage.en);
      expect(s.normalized().onlineDirectory, isFalse);
    });
  });

  group('200 键覆盖度', () {
    test('两份 bundle 各 200 键、零缺项零多余键', () {
      expect(LegalTexts.keys.length, 200);
      for (final Locale l in LocalizedLegalTexts.supportedLocales) {
        expect(LocalizedLegalTexts.missingKeys(l), isEmpty);
        expect(LocalizedLegalTexts.extraKeys(l), isEmpty);
      }
      expect(LocalizedLegalTexts.paragraphsAligned(), isTrue);
    });
  });
}
