import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/content/legal_texts.dart';
import 'package:local_reader/core/content/localized_texts.dart';
import 'package:local_reader/core/data/book_repository.dart';
import 'package:local_reader/core/state/app_scope.dart';
import 'package:local_reader/core/state/app_settings.dart';

/// 中文单一源对照表：逐键指向 `LegalTexts` 静态常量，
/// 用来证明 zh bundle 是「委托」而不是又复制了一份中文。
const Map<String, String> _zhSource = <String, String>{
  'appDisclaimer': LegalTexts.appDisclaimer,
  'nonOfficial': LegalTexts.nonOfficial,
  'freeStatement': LegalTexts.freeStatement,
  'sources': LegalTexts.sources,
  'contentRights': LegalTexts.contentRights,
  'thirdPartyService': LegalTexts.thirdPartyService,
  'onlineAvailability': LegalTexts.onlineAvailability,
  'issueGuidance': LegalTexts.issueGuidance,
  'onlineEntryNote': LegalTexts.onlineEntryNote,
  'localOnlyNote': LegalTexts.localOnlyNote,
  'importFormats': LegalTexts.importFormats,
  'archiveNotice': LegalTexts.archiveNotice,
  'permissionNotice': LegalTexts.permissionNotice,
  'importChannels': LegalTexts.importChannels,
  'importBody': LegalTexts.importBody,
  'importTitle': LegalTexts.importTitle,
  'importWizardTitle': LegalTexts.importWizardTitle,
  'importWizardStaticNote': LegalTexts.importWizardStaticNote,
  'importRar5Reason': LegalTexts.importRar5Reason,
  'importEncryptedReason': LegalTexts.importEncryptedReason,
  'importUnsupportedReason': LegalTexts.importUnsupportedReason,
  'importNoModeHint': LegalTexts.importNoModeHint,
  'importNoGrantHint': LegalTexts.importNoGrantHint,
  'importScanEmpty': LegalTexts.importScanEmpty,
  'importNoAcceptedHint': LegalTexts.importNoAcceptedHint,
  'importConflictNote': LegalTexts.importConflictNote,
  'importDoneNote': LegalTexts.importDoneNote,
  'importWizardEntry': LegalTexts.importWizardEntry,
  'emptyLibraryTitle': LegalTexts.emptyLibraryTitle,
  'emptyLibraryBody': LegalTexts.emptyLibraryBody,
  'noResultTitle': LegalTexts.noResultTitle,
  'noResultBody': LegalTexts.noResultBody,
  'demoDataNote': LegalTexts.demoDataNote,
  'excerptLocalNote': LegalTexts.excerptLocalNote,
  'excerptExportNote': LegalTexts.excerptExportNote,
  'excerptReadOnlyNote': LegalTexts.excerptReadOnlyNote,
  'excerptEmptyTitle': LegalTexts.excerptEmptyTitle,
  'excerptEmptyBody': LegalTexts.excerptEmptyBody,
  'excerptNoResultTitle': LegalTexts.excerptNoResultTitle,
  'excerptNoResultBody': LegalTexts.excerptNoResultBody,
  'comicPlaceholderNote': LegalTexts.comicPlaceholderNote,
  'comicTocNote': LegalTexts.comicTocNote,
  'comicLocalNote': LegalTexts.comicLocalNote,
  'favoriteLocalNote': LegalTexts.favoriteLocalNote,
  'favoriteEmptyTitle': LegalTexts.favoriteEmptyTitle,
  'favoriteEmptyBody': LegalTexts.favoriteEmptyBody,
  'favoritesOnlyHint': LegalTexts.favoritesOnlyHint,
  'screenshotNote': LegalTexts.screenshotNote,
  'keepsakeTitle': LegalTexts.keepsakeTitle,
  'calendarMonthTitle': LegalTexts.calendarMonthTitle,
  'keepsakeStaticNote': LegalTexts.keepsakeStaticNote,
  'calendarStaticNote': LegalTexts.calendarStaticNote,
  'keepsakeEmptyTitle': LegalTexts.keepsakeEmptyTitle,
  'keepsakeEmptyBody': LegalTexts.keepsakeEmptyBody,
  'calendarNoRecordNote': LegalTexts.calendarNoRecordNote,
  'calendarOutOfRangeNote': LegalTexts.calendarOutOfRangeNote,
  'calendarOpenMonth': LegalTexts.calendarOpenMonth,
  'calendarBackToThisMonth': LegalTexts.calendarBackToThisMonth,
  'calendarAllMonths': LegalTexts.calendarAllMonths,
  'localizationTitle': LegalTexts.localizationTitle,
  'localizationPreviewTitle': LegalTexts.localizationPreviewTitle,
  'localizationDefaultNote': LegalTexts.localizationDefaultNote,
  'localizationStaticNote': LegalTexts.localizationStaticNote,
  'comicSpreadTitle': LegalTexts.comicSpreadTitle,
  'comicBlankSlotNote': LegalTexts.comicBlankSlotNote,
  'comicVerticalLockNote': LegalTexts.comicVerticalLockNote,
  'comicSpreadStaticNote': LegalTexts.comicSpreadStaticNote,
  'bookExcerptTitle': LegalTexts.bookExcerptTitle,
  'bookExcerptEmptyTitle': LegalTexts.bookExcerptEmptyTitle,
  'bookExcerptEmptyBody': LegalTexts.bookExcerptEmptyBody,
  'bookExcerptScopedNote': LegalTexts.bookExcerptScopedNote,
  'bookExcerptPinnedNote': LegalTexts.bookExcerptPinnedNote,
  'bookExcerptStaticNote': LegalTexts.bookExcerptStaticNote,
  'bookExcerptMissingNote': LegalTexts.bookExcerptMissingNote,
  'excerptSearchTitleNote': LegalTexts.excerptSearchTitleNote,
  'excerptExportSnapshotNote': LegalTexts.excerptExportSnapshotNote,
  'keepsakeAllKinds': LegalTexts.keepsakeAllKinds,
  'keepsakeOpenLibrary': LegalTexts.keepsakeOpenLibrary,
  'keepsakeLibraryTitle': LegalTexts.keepsakeLibraryTitle,
  'keepsakeFilterHint': LegalTexts.keepsakeFilterHint,
  'keepsakeKindEmptyTitle': LegalTexts.keepsakeKindEmptyTitle,
  'keepsakeKindEmptyBody': LegalTexts.keepsakeKindEmptyBody,
  'keepsakeNoResultTitle': LegalTexts.keepsakeNoResultTitle,
  'keepsakeNoResultBody': LegalTexts.keepsakeNoResultBody,
  'keepsakeFilterStaticNote': LegalTexts.keepsakeFilterStaticNote,
  'keepsakeWidgetKindNote': LegalTexts.keepsakeWidgetKindNote,
  'keepsakeMonthPreviewNote': LegalTexts.keepsakeMonthPreviewNote,
  'keepsakeMonthPreviewOpen': LegalTexts.keepsakeMonthPreviewOpen,
  'keepsakeMonthEmptyBody': LegalTexts.keepsakeMonthEmptyBody,
  'keepsakeMonthKindEmptyBody': LegalTexts.keepsakeMonthKindEmptyBody,
  'keepsakeMonthNoResultBody': LegalTexts.keepsakeMonthNoResultBody,
  'comicWideSoloTitle': LegalTexts.comicWideSoloTitle,
  'comicWideSoloNote': LegalTexts.comicWideSoloNote,
  'comicWideSoloSingleNote': LegalTexts.comicWideSoloSingleNote,
  'excerptAnchorRestoreNote': LegalTexts.excerptAnchorRestoreNote,
  'keepsakeDayEmptyTitle': LegalTexts.keepsakeDayEmptyTitle,
  'keepsakeDayEmptyBody': LegalTexts.keepsakeDayEmptyBody,
  'keepsakeDayFilterNote': LegalTexts.keepsakeDayFilterNote,
  'calendarOpenMonthKeepsakes': LegalTexts.calendarOpenMonthKeepsakes,
  'calendarOpenDayKeepsakes': LegalTexts.calendarOpenDayKeepsakes,
  'calendarCrossMonthNote': LegalTexts.calendarCrossMonthNote,
  'calendarInvalidDateNote': LegalTexts.calendarInvalidDateNote,
  'keepsakeOpenCalendarDay': LegalTexts.keepsakeOpenCalendarDay,
  'keepsakeOpenCalendarMonth': LegalTexts.keepsakeOpenCalendarMonth,
  'comicSpineGutterTitle': LegalTexts.comicSpineGutterTitle,
  'comicSpineGutterNote': LegalTexts.comicSpineGutterNote,
  'comicSpineShadeTitle': LegalTexts.comicSpineShadeTitle,
  'comicSpineShadeNote': LegalTexts.comicSpineShadeNote,
  'keepsakeDateRangeTitle': LegalTexts.keepsakeDateRangeTitle,
  'keepsakeDateRangeHint': LegalTexts.keepsakeDateRangeHint,
  'keepsakeDateRangeNote': LegalTexts.keepsakeDateRangeNote,
  'keepsakeDateRangeInvalid': LegalTexts.keepsakeDateRangeInvalid,
  'keepsakeDateRangeFilterNote': LegalTexts.keepsakeDateRangeFilterNote,
  'keepsakeDateRangeAll': LegalTexts.keepsakeDateRangeAll,
  'keepsakeDateRangeThisMonth': LegalTexts.keepsakeDateRangeThisMonth,
  'keepsakeDateRangeLast7': LegalTexts.keepsakeDateRangeLast7,
  'keepsakeRangeEmptyTitle': LegalTexts.keepsakeRangeEmptyTitle,
  'keepsakeRangeEmptyBody': LegalTexts.keepsakeRangeEmptyBody,
  'calendarOpenDayExcerpts': LegalTexts.calendarOpenDayExcerpts,
  'excerptDayFilterNote': LegalTexts.excerptDayFilterNote,
  'excerptDayEmptyTitle': LegalTexts.excerptDayEmptyTitle,
  'excerptDayEmptyBody': LegalTexts.excerptDayEmptyBody,
  'excerptDayScopedTitle': LegalTexts.excerptDayScopedTitle,
  'wenkuOnlySources': LegalTexts.wenkuOnlySources,
  'wenkuContentOwnership': LegalTexts.wenkuContentOwnership,
  'wenkuNoWithdrawn': LegalTexts.wenkuNoWithdrawn,
  'wenkuNoCircumvention': LegalTexts.wenkuNoCircumvention,
  'wenkuThirdParty': LegalTexts.wenkuThirdParty,
  'wenkuNoCredentials': LegalTexts.wenkuNoCredentials,
  'wenkuSourceNote': LegalTexts.wenkuSourceNote,
  'wenkuLocalSourceNote': LegalTexts.wenkuLocalSourceNote,
  'wenkuCustomSourceNote': LegalTexts.wenkuCustomSourceNote,
  'wenkuShelfTabLocal': LegalTexts.wenkuShelfTabLocal,
  'wenkuShelfTabCloud': LegalTexts.wenkuShelfTabCloud,
  'wenkuCloudTitle': LegalTexts.wenkuCloudTitle,
  'wenkuCloudSubtitle': LegalTexts.wenkuCloudSubtitle,
  'wenkuSourceNavTitle': LegalTexts.wenkuSourceNavTitle,
  'wenkuFeedTitle': LegalTexts.wenkuFeedTitle,
  'wenkuSearchHint': LegalTexts.wenkuSearchHint,
  'wenkuStatusNote': LegalTexts.wenkuStatusNote,
  'wenkuLockedTitle': LegalTexts.wenkuLockedTitle,
  'wenkuLockedBody': LegalTexts.wenkuLockedBody,
  'wenkuUnlockButton': LegalTexts.wenkuUnlockButton,
  'wenkuBookAdd': LegalTexts.wenkuBookAdd,
  'wenkuBookAdded': LegalTexts.wenkuBookAdded,
  'wenkuDetailTitle': LegalTexts.wenkuDetailTitle,
  'wenkuDetailSynopsis': LegalTexts.wenkuDetailSynopsis,
  'wenkuDetailToc': LegalTexts.wenkuDetailToc,
  'wenkuDetailChapterNote': LegalTexts.wenkuDetailChapterNote,
  'wenkuDetailStaticNote': LegalTexts.wenkuDetailStaticNote,
  'wenkuEmptyTitle': LegalTexts.wenkuEmptyTitle,
  'wenkuEmptyBody': LegalTexts.wenkuEmptyBody,
  'wenkuRefresh': LegalTexts.wenkuRefresh,
  'wenkuAddedNote': LegalTexts.wenkuAddedNote,
  'feedbackTitle': LegalTexts.feedbackTitle,
  'feedbackSubtitle': LegalTexts.feedbackSubtitle,
  'feedbackPreviewTitle': LegalTexts.feedbackPreviewTitle,
  'feedbackMissing': LegalTexts.feedbackMissing,
  'feedbackStaticNote': LegalTexts.feedbackStaticNote,
  'supportTitle': LegalTexts.supportTitle,
  'supportBody': LegalTexts.supportBody,
  'profileHeroTitle': LegalTexts.profileHeroTitle,
  'profileHeroSubtitle': LegalTexts.profileHeroSubtitle,
  'profileSectionAppearance': LegalTexts.profileSectionAppearance,
  'profileSectionSources': LegalTexts.profileSectionSources,
  'profileSectionLibrary': LegalTexts.profileSectionLibrary,
  'profileSectionFavorites': LegalTexts.profileSectionFavorites,
  'profileSectionSupport': LegalTexts.profileSectionSupport,
  'profileSectionAbout': LegalTexts.profileSectionAbout,
  'cloudChannelsTitle': LegalTexts.cloudChannelsTitle,
  'cloudChannelsNote': LegalTexts.cloudChannelsNote,
  'mergeRecordsNote': LegalTexts.mergeRecordsNote,
  'wenkuFormatsNote': LegalTexts.wenkuFormatsNote,
  'unlockModeTitle': LegalTexts.unlockModeTitle,
  'unlockModeBody': LegalTexts.unlockModeBody,
  'wenkuRealSourceNote': LegalTexts.wenkuRealSourceNote,
  'wenkuEndpointNote': LegalTexts.wenkuEndpointNote,
  'wenkuChallengeNote': LegalTexts.wenkuChallengeNote,
  'wenkuWithdrawnNote': LegalTexts.wenkuWithdrawnNote,
  'wenkuRateLimitNote': LegalTexts.wenkuRateLimitNote,
  'wenkuUnavailableNote': LegalTexts.wenkuUnavailableNote,
  'wenkuUpstreamChangedNote': LegalTexts.wenkuUpstreamChangedNote,
  'wenkuNoRelayNote': LegalTexts.wenkuNoRelayNote,
  'wenkuChapterNote': LegalTexts.wenkuChapterNote,
  'wenkuLocalVerifyNote': LegalTexts.wenkuLocalVerifyNote,
  'wenkuSdkAbsentNote': LegalTexts.wenkuSdkAbsentNote,
  'wenkuPlatformPermissionNote': LegalTexts.wenkuPlatformPermissionNote,
};

const RegExp _han = RegExp(r'[\u4e00-\u9fff]');

void main() {
  group('文案键集合单一源', () {
    test('187 个 String 键 + 1 个列表键', () {
      expect(LegalTexts.keys.length, 187);
      expect(LegalTexts.listKeys, <String>['aboutParagraphs']);
      expect(LocalizedLegalTexts.keyCount, 187);
      expect(LocalizedLegalTexts.listCount, 1);
    });

    test('键无重复，且每个键都能在 zh bundle 找到非空值', () {
      expect(LegalTexts.keys.toSet().length, LegalTexts.keys.length);
      for (final String key in LegalTexts.keys) {
        expect(kLegalTextsZh.has(key), isTrue, reason: key);
        expect(kLegalTextsZh.value(key), isNotEmpty, reason: key);
      }
    });

    test('每个键都在 LegalTexts 里有对应的静态常量', () {
      expect(_zhSource.length, LegalTexts.keys.length);
      for (final String key in LegalTexts.keys) {
        expect(_zhSource.containsKey(key), isTrue, reason: key);
        expect(_zhSource[key], isNotEmpty, reason: key);
      }
    });

    test('中文 bundle 是委托而非复制：逐键与 LegalTexts 常量完全相等', () {
      for (final MapEntry<String, String> e in _zhSource.entries) {
        expect(kLegalTextsZh.value(e.key), e.value, reason: e.key);
      }
    });
  });

  group('多语言表结构与回退', () {
    test('Map<Locale, LegalTextBundle> 恰好两种语言，默认中文', () {
      expect(LocalizedLegalTexts.bundles.length, 2);
      expect(LocalizedLegalTexts.supportedLocales.length, 2);
      expect(LocalizedLegalTexts.defaultLocale, const Locale('zh'));
      expect(LocalizedLegalTexts.bundles[LocalizedLegalTexts.defaultLocale],
          kLegalTextsZh);
      expect(LocalizedLegalTexts.bundles[const Locale('en')], kLegalTextsEn);
    });

    test('normalize 精确匹配', () {
      expect(LocalizedLegalTexts.normalize(const Locale('zh')),
          const Locale('zh'));
      expect(LocalizedLegalTexts.normalize(const Locale('en')),
          const Locale('en'));
    });

    test('normalize 按 languageCode 回退：en_US → en，zh_TW → zh', () {
      expect(LocalizedLegalTexts.normalize(const Locale('en', 'US')),
          const Locale('en'));
      expect(LocalizedLegalTexts.normalize(const Locale('zh', 'TW')),
          const Locale('zh'));
    });

    test('未知语言回退中文，绝不静默切成英文', () {
      expect(LocalizedLegalTexts.normalize(const Locale('fr', 'FR')),
          LocalizedLegalTexts.defaultLocale);
      expect(LocalizedLegalTexts.of(const Locale('ja')), kLegalTextsZh);
      expect(
          LocalizedLegalTexts.languageOf(const Locale('de')), AppLanguage.zhCN);
    });

    test('AppLanguage 与 Locale 往返一致', () {
      for (final AppLanguage l in AppLanguage.values) {
        expect(LocalizedLegalTexts.localeOf(l), l.locale);
        expect(LocalizedLegalTexts.languageOf(l.locale), l);
        expect(l.label, isNotEmpty);
      }
      expect(AppLanguage.zhCN.isDefault, isTrue);
      expect(AppLanguage.en.isDefault, isFalse);
    });

    test('value(locale, key) 按语言取正确文案', () {
      expect(
        LocalizedLegalTexts.value(const Locale('zh'), 'importTitle'),
        LegalTexts.importTitle,
      );
      expect(
        LocalizedLegalTexts.value(const Locale('en'), 'importTitle'),
        'Import books',
      );
    });

    test('未知键抛 ArgumentError，不静默返回空串', () {
      expect(() => kLegalTextsZh.value('not_a_key'), throwsArgumentError);
      expect(() => kLegalTextsEn.value('not_a_key'), throwsArgumentError);
      expect(() => kLegalTextsZh.list('not_a_list'), throwsArgumentError);
    });

    test('snapshot 长度 63 且不可变', () {
      final Map<String, String> s =
          LocalizedLegalTexts.snapshot(const Locale('en'));
      expect(s.length, 187);
      expect(() => s['x'] = 'y', throwsUnsupportedError);
    });
  });

  group('键覆盖度', () {
    test('两种语言都无缺项、无多余键', () {
      for (final Locale l in LocalizedLegalTexts.supportedLocales) {
        expect(LocalizedLegalTexts.missingKeys(l), isEmpty, reason: '$l 有缺项');
        expect(LocalizedLegalTexts.extraKeys(l), isEmpty, reason: '$l 有多余键');
      }
    });

    test('中英键集合完全一致', () {
      expect(
          kLegalTextsZh.values.keys.toSet(), kLegalTextsEn.values.keys.toSet());
      expect(
          kLegalTextsZh.lists.keys.toSet(), kLegalTextsEn.lists.keys.toSet());
    });

    test('英文每条都非空，且不混入中文字符', () {
      for (final MapEntry<String, String> e in kLegalTextsEn.values.entries) {
        expect(e.value, isNotEmpty, reason: e.key);
        expect(_han.hasMatch(e.value), isFalse,
            reason: '${e.key} 的英文文案混入中文：${e.value}');
      }
      for (final String p in kLegalTextsEn.list('aboutParagraphs')) {
        expect(_han.hasMatch(p), isFalse);
      }
    });

    test('组合串 importBody 独立拼装，英文不夹中文片段', () {
      expect(_han.hasMatch(LegalTexts.importBody), isTrue);
      expect(_han.hasMatch(kLegalTextsEn.value('importBody')), isFalse);
      expect(kLegalTextsEn.value('importBody'), contains('CBZ/ZIP'));
      expect(kLegalTextsEn.value('importBody'), contains('Pure-local mode'));
    });

    test('aboutParagraphs 中英各 6 条且顺序对齐', () {
      expect(LegalTexts.aboutParagraphs.length, 6);
      expect(kLegalTextsZh.list('aboutParagraphs'), LegalTexts.aboutParagraphs);
      expect(kLegalTextsEn.list('aboutParagraphs').length, 6);
      expect(LocalizedLegalTexts.paragraphsAligned(), isTrue);
    });
  });

  group('英文合规句与上游 README 口径对齐', () {
    test('第三方客户端 / 不运营在线书库 / 不下架内容', () {
      final String d = kLegalTextsEn.value('appDisclaimer');
      expect(d, contains('third-party reading client'));
      expect(d, contains('does not operate an online library'));
      expect(d, contains('withdrawn for copyright reasons'));
    });

    test('全功能免费、自愿支持、警惕收费', () {
      final String f = kLegalTextsEn.value('freeStatement');
      expect(f, contains('entirely free'));
      expect(f, contains('voluntarily supported'));
      expect(f, contains('no memberships, activation codes'));
    });

    test('仅 Wenku8 与本地导入 / 非官方 / 三端', () {
      expect(kLegalTextsEn.value('sources'),
          contains('Only Wenku8 and local imports'));
      expect(kLegalTextsEn.value('nonOfficial'),
          contains('not an official Wenku8 app'));
      expect(kLegalTextsEn.value('nonOfficial'), contains('HarmonyOS'));
    });

    test('权利归属与不绕过 DRM', () {
      final String c = kLegalTextsEn.value('contentRights');
      expect(c, contains('respective rights holders'));
      expect(c, contains('break DRM'));
    });

    test('问题反馈不带凭据', () {
      expect(
          kLegalTextsEn.value('issueGuidance'), contains('cookies or tokens'));
    });

    test('截图口径明确写「界面为中文」', () {
      expect(kLegalTextsEn.value('screenshotNote'),
          'The screenshots use demo book data. The app interface is in Chinese.');
    });

    test('静态说明明确不跟随系统语言、不逐页切换', () {
      final String zh = LegalTexts.localizationStaticNote;
      final String en = kLegalTextsEn.value('localizationStaticNote');
      expect(zh, contains('不自动跟随系统语言'));
      expect(zh, contains('不逐页切换'));
      expect(en, contains('does not follow the system language'));
      expect(en, contains('does not switch in-app texts page by page'));
      expect(LegalTexts.localizationDefaultNote, contains('不跟随系统语言'));
    });
  });

  group('静态交付边界', () {
    test('多语言表不影响纯本地 master switch', () {
      final AppState state = AppState(
        settingsStore: InMemorySettingsStore(),
        books: const DemoBookRepository(),
      );
      expect(state.settings.pureLocal, isTrue);
      expect(state.networkingAllowed, isFalse);
      expect(state.settings, const AppSettings().normalized());
    });

    test('预览语言默认值是中文，切换枚举不产生第三种状态', () {
      expect(AppLanguage.values.length, 2);
      expect(AppLanguage.zhCN.isDefault, isTrue);
      expect(LocalizedLegalTexts.of(AppLanguage.zhCN.locale), kLegalTextsZh);
      expect(LocalizedLegalTexts.of(AppLanguage.en.locale), kLegalTextsEn);
    });

    test('回退链末端始终有完整中文文案', () {
      for (final Locale l in <Locale>[
        const Locale('fr'),
        const Locale('ja', 'JP'),
        const Locale('en', 'GB'),
        const Locale('zh', 'HK'),
      ]) {
        final LegalTextBundle b = LocalizedLegalTexts.of(l);
        for (final String key in LegalTexts.keys) {
          expect(b.value(key), isNotEmpty, reason: '$l / $key 回退后仍缺项');
        }
      }
    });
  });
}
