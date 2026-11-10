import 'lr_localizations.dart';

/// 业务文案的**键名 API**（第二十八轮起）。
///
/// 中文 / 英文文案已全部迁到 `lib/l10n/app_zh.arb` / `app_en.arb`，
class LegalTexts {
  const LegalTexts._();

  static String get appDisclaimer => lrText('appDisclaimer');
  static String get nonOfficial => lrText('nonOfficial');
  static String get freeStatement => lrText('freeStatement');
  static String get sources => lrText('sources');
  static String get contentRights => lrText('contentRights');
  static String get thirdPartyService => lrText('thirdPartyService');
  static String get onlineAvailability => lrText('onlineAvailability');
  static String get issueGuidance => lrText('issueGuidance');
  static String get onlineEntryNote => lrText('onlineEntryNote');
  static String get localOnlyNote => lrText('localOnlyNote');
  static String get importFormats => lrText('importFormats');
  static String get archiveNotice => lrText('archiveNotice');
  static String get permissionNotice => lrText('permissionNotice');
  static String get importChannels => lrText('importChannels');
  static String get importBody => lrText('importBody');
  static String get importTitle => lrText('importTitle');
  static String get importWizardTitle => lrText('importWizardTitle');
  static String get importWizardStaticNote => lrText('importWizardStaticNote');
  static String get importRar5Reason => lrText('importRar5Reason');
  static String get importEncryptedReason => lrText('importEncryptedReason');
  static String get importUnsupportedReason => lrText('importUnsupportedReason');
  static String get importNoModeHint => lrText('importNoModeHint');
  static String get importNoGrantHint => lrText('importNoGrantHint');
  static String get importScanEmpty => lrText('importScanEmpty');
  static String get importNoAcceptedHint => lrText('importNoAcceptedHint');
  static String get importConflictNote => lrText('importConflictNote');
  static String get importDoneNote => lrText('importDoneNote');
  static String get importWizardEntry => lrText('importWizardEntry');
  static String get emptyLibraryTitle => lrText('emptyLibraryTitle');
  static String get emptyLibraryBody => lrText('emptyLibraryBody');
  static String get noResultTitle => lrText('noResultTitle');
  static String get noResultBody => lrText('noResultBody');
  static String get demoDataNote => lrText('demoDataNote');
  static String get excerptLocalNote => lrText('excerptLocalNote');
  static String get excerptExportNote => lrText('excerptExportNote');
  static String get excerptReadOnlyNote => lrText('excerptReadOnlyNote');
  static String get excerptEmptyTitle => lrText('excerptEmptyTitle');
  static String get excerptEmptyBody => lrText('excerptEmptyBody');
  static String get excerptNoResultTitle => lrText('excerptNoResultTitle');
  static String get excerptNoResultBody => lrText('excerptNoResultBody');
  static String get comicPlaceholderNote => lrText('comicPlaceholderNote');
  static String get comicTocNote => lrText('comicTocNote');
  static String get comicLocalNote => lrText('comicLocalNote');
  static String get favoriteLocalNote => lrText('favoriteLocalNote');
  static String get favoriteEmptyTitle => lrText('favoriteEmptyTitle');
  static String get favoriteEmptyBody => lrText('favoriteEmptyBody');
  static String get favoritesOnlyHint => lrText('favoritesOnlyHint');
  static String get screenshotNote => lrText('screenshotNote');
  static String get keepsakeTitle => lrText('keepsakeTitle');
  static String get calendarMonthTitle => lrText('calendarMonthTitle');
  static String get keepsakeStaticNote => lrText('keepsakeStaticNote');
  static String get calendarStaticNote => lrText('calendarStaticNote');
  static String get keepsakeEmptyTitle => lrText('keepsakeEmptyTitle');
  static String get keepsakeEmptyBody => lrText('keepsakeEmptyBody');
  static String get calendarNoRecordNote => lrText('calendarNoRecordNote');
  static String get calendarOutOfRangeNote => lrText('calendarOutOfRangeNote');
  static String get calendarOpenMonth => lrText('calendarOpenMonth');
  static String get calendarBackToThisMonth => lrText('calendarBackToThisMonth');
  static String get calendarAllMonths => lrText('calendarAllMonths');
  static String get localizationTitle => lrText('localizationTitle');
  static String get localizationPreviewTitle => lrText('localizationPreviewTitle');
  static String get localizationDefaultNote => lrText('localizationDefaultNote');
  static String get localizationStaticNote => lrText('localizationStaticNote');
  static String get comicSpreadTitle => lrText('comicSpreadTitle');
  static String get comicBlankSlotNote => lrText('comicBlankSlotNote');
  static String get comicVerticalLockNote => lrText('comicVerticalLockNote');
  static String get comicSpreadStaticNote => lrText('comicSpreadStaticNote');
  static String get bookExcerptTitle => lrText('bookExcerptTitle');
  static String get bookExcerptEmptyTitle => lrText('bookExcerptEmptyTitle');
  static String get bookExcerptEmptyBody => lrText('bookExcerptEmptyBody');
  static String get bookExcerptScopedNote => lrText('bookExcerptScopedNote');
  static String get bookExcerptPinnedNote => lrText('bookExcerptPinnedNote');
  static String get bookExcerptStaticNote => lrText('bookExcerptStaticNote');
  static String get bookExcerptMissingNote => lrText('bookExcerptMissingNote');
  static String get excerptSearchTitleNote => lrText('excerptSearchTitleNote');
  static String get excerptExportSnapshotNote => lrText('excerptExportSnapshotNote');
  static String get keepsakeAllKinds => lrText('keepsakeAllKinds');
  static String get keepsakeOpenLibrary => lrText('keepsakeOpenLibrary');
  static String get keepsakeLibraryTitle => lrText('keepsakeLibraryTitle');
  static String get keepsakeFilterHint => lrText('keepsakeFilterHint');
  static String get keepsakeKindEmptyTitle => lrText('keepsakeKindEmptyTitle');
  static String get keepsakeKindEmptyBody => lrText('keepsakeKindEmptyBody');
  static String get keepsakeNoResultTitle => lrText('keepsakeNoResultTitle');
  static String get keepsakeNoResultBody => lrText('keepsakeNoResultBody');
  static String get keepsakeFilterStaticNote => lrText('keepsakeFilterStaticNote');
  static String get keepsakeWidgetKindNote => lrText('keepsakeWidgetKindNote');
  static String get keepsakeMonthPreviewNote => lrText('keepsakeMonthPreviewNote');
  static String get keepsakeMonthPreviewOpen => lrText('keepsakeMonthPreviewOpen');
  static String get keepsakeMonthEmptyBody => lrText('keepsakeMonthEmptyBody');
  static String get keepsakeMonthKindEmptyBody => lrText('keepsakeMonthKindEmptyBody');
  static String get keepsakeMonthNoResultBody => lrText('keepsakeMonthNoResultBody');
  static String get comicWideSoloTitle => lrText('comicWideSoloTitle');
  static String get comicWideSoloNote => lrText('comicWideSoloNote');
  static String get comicWideSoloSingleNote => lrText('comicWideSoloSingleNote');
  static String get excerptAnchorRestoreNote => lrText('excerptAnchorRestoreNote');
  static String get keepsakeDayEmptyTitle => lrText('keepsakeDayEmptyTitle');
  static String get keepsakeDayEmptyBody => lrText('keepsakeDayEmptyBody');
  static String get keepsakeDayFilterNote => lrText('keepsakeDayFilterNote');
  static String get calendarOpenMonthKeepsakes => lrText('calendarOpenMonthKeepsakes');
  static String get calendarOpenDayKeepsakes => lrText('calendarOpenDayKeepsakes');
  static String get calendarCrossMonthNote => lrText('calendarCrossMonthNote');
  static String get calendarInvalidDateNote => lrText('calendarInvalidDateNote');
  static String get keepsakeOpenCalendarDay => lrText('keepsakeOpenCalendarDay');
  static String get keepsakeOpenCalendarMonth => lrText('keepsakeOpenCalendarMonth');
  static String get comicSpineGutterTitle => lrText('comicSpineGutterTitle');
  static String get comicSpineGutterNote => lrText('comicSpineGutterNote');
  static String get comicSpineShadeTitle => lrText('comicSpineShadeTitle');
  static String get comicSpineShadeNote => lrText('comicSpineShadeNote');
  static String get keepsakeDateRangeTitle => lrText('keepsakeDateRangeTitle');
  static String get keepsakeDateRangeHint => lrText('keepsakeDateRangeHint');
  static String get keepsakeDateRangeNote => lrText('keepsakeDateRangeNote');
  static String get keepsakeDateRangeInvalid => lrText('keepsakeDateRangeInvalid');
  static String get keepsakeDateRangeFilterNote => lrText('keepsakeDateRangeFilterNote');
  static String get keepsakeDateRangeAll => lrText('keepsakeDateRangeAll');
  static String get keepsakeDateRangeThisMonth => lrText('keepsakeDateRangeThisMonth');
  static String get keepsakeDateRangeLast7 => lrText('keepsakeDateRangeLast7');
  static String get keepsakeRangeEmptyTitle => lrText('keepsakeRangeEmptyTitle');
  static String get keepsakeRangeEmptyBody => lrText('keepsakeRangeEmptyBody');
  static String get calendarOpenDayExcerpts => lrText('calendarOpenDayExcerpts');
  static String get excerptDayFilterNote => lrText('excerptDayFilterNote');
  static String get excerptDayEmptyTitle => lrText('excerptDayEmptyTitle');
  static String get excerptDayEmptyBody => lrText('excerptDayEmptyBody');
  static String get excerptDayScopedTitle => lrText('excerptDayScopedTitle');
  static String get wenkuOnlySources => lrText('wenkuOnlySources');
  static String get wenkuContentOwnership => lrText('wenkuContentOwnership');
  static String get wenkuNoWithdrawn => lrText('wenkuNoWithdrawn');
  static String get wenkuNoCircumvention => lrText('wenkuNoCircumvention');
  static String get wenkuThirdParty => lrText('wenkuThirdParty');
  static String get wenkuNoCredentials => lrText('wenkuNoCredentials');
  static String get wenkuSourceNote => lrText('wenkuSourceNote');
  static String get wenkuLocalSourceNote => lrText('wenkuLocalSourceNote');
  static String get wenkuCustomSourceNote => lrText('wenkuCustomSourceNote');
  static String get wenkuShelfTabLocal => lrText('wenkuShelfTabLocal');
  static String get wenkuShelfTabCloud => lrText('wenkuShelfTabCloud');
  static String get wenkuCloudTitle => lrText('wenkuCloudTitle');
  static String get wenkuCloudSubtitle => lrText('wenkuCloudSubtitle');
  static String get wenkuSourceNavTitle => lrText('wenkuSourceNavTitle');
  static String get wenkuFeedTitle => lrText('wenkuFeedTitle');
  static String get wenkuSearchHint => lrText('wenkuSearchHint');
  static String get wenkuStatusNote => lrText('wenkuStatusNote');
  static String get wenkuLockedTitle => lrText('wenkuLockedTitle');
  static String get wenkuLockedBody => lrText('wenkuLockedBody');
  static String get wenkuUnlockButton => lrText('wenkuUnlockButton');
  static String get wenkuBookAdd => lrText('wenkuBookAdd');
  static String get wenkuBookAdded => lrText('wenkuBookAdded');
  static String get wenkuDetailTitle => lrText('wenkuDetailTitle');
  static String get wenkuDetailSynopsis => lrText('wenkuDetailSynopsis');
  static String get wenkuDetailToc => lrText('wenkuDetailToc');
  static String get wenkuDetailChapterNote => lrText('wenkuDetailChapterNote');
  static String get wenkuDetailStaticNote => lrText('wenkuDetailStaticNote');
  static String get wenkuEmptyTitle => lrText('wenkuEmptyTitle');
  static String get wenkuEmptyBody => lrText('wenkuEmptyBody');
  static String get wenkuRefresh => lrText('wenkuRefresh');
  static String get wenkuAddedNote => lrText('wenkuAddedNote');
  static String get feedbackTitle => lrText('feedbackTitle');
  static String get feedbackSubtitle => lrText('feedbackSubtitle');
  static String get feedbackPreviewTitle => lrText('feedbackPreviewTitle');
  static String get feedbackMissing => lrText('feedbackMissing');
  static String get feedbackStaticNote => lrText('feedbackStaticNote');
  static String get supportTitle => lrText('supportTitle');
  static String get supportBody => lrText('supportBody');
  static String get profileHeroTitle => lrText('profileHeroTitle');
  static String get profileHeroSubtitle => lrText('profileHeroSubtitle');
  static String get profileSectionAppearance => lrText('profileSectionAppearance');
  static String get profileSectionSources => lrText('profileSectionSources');
  static String get profileSectionLibrary => lrText('profileSectionLibrary');
  static String get profileSectionFavorites => lrText('profileSectionFavorites');
  static String get profileSectionSupport => lrText('profileSectionSupport');
  static String get profileSectionAbout => lrText('profileSectionAbout');
  static String get cloudChannelsTitle => lrText('cloudChannelsTitle');
  static String get cloudChannelsNote => lrText('cloudChannelsNote');
  static String get mergeRecordsNote => lrText('mergeRecordsNote');
  static String get wenkuFormatsNote => lrText('wenkuFormatsNote');
  static String get unlockModeTitle => lrText('unlockModeTitle');
  static String get unlockModeBody => lrText('unlockModeBody');
  static String get wenkuRealSourceNote => lrText('wenkuRealSourceNote');
  static String get wenkuEndpointNote => lrText('wenkuEndpointNote');
  static String get wenkuChallengeNote => lrText('wenkuChallengeNote');
  static String get wenkuWithdrawnNote => lrText('wenkuWithdrawnNote');
  static String get wenkuRateLimitNote => lrText('wenkuRateLimitNote');
  static String get wenkuUnavailableNote => lrText('wenkuUnavailableNote');
  static String get wenkuUpstreamChangedNote => lrText('wenkuUpstreamChangedNote');
  static String get wenkuNoRelayNote => lrText('wenkuNoRelayNote');
  static String get wenkuChapterNote => lrText('wenkuChapterNote');
  static String get wenkuLocalVerifyNote => lrText('wenkuLocalVerifyNote');
  static String get wenkuSdkAbsentNote => lrText('wenkuSdkAbsentNote');
  static String get wenkuPlatformPermissionNote => lrText('wenkuPlatformPermissionNote');
  static String get wenkuLoginTitle => lrText('wenkuLoginTitle');
  static String get wenkuLoginUsername => lrText('wenkuLoginUsername');
  static String get wenkuLoginPassword => lrText('wenkuLoginPassword');
  static String get wenkuLoginAction => lrText('wenkuLoginAction');
  static String get wenkuLogoutAction => lrText('wenkuLogoutAction');
  static String get wenkuLoginCredentialNote => lrText('wenkuLoginCredentialNote');
  static String get wenkuLoginLoggedOut => lrText('wenkuLoginLoggedOut');
  static String get wenkuLoginFailed => lrText('wenkuLoginFailed');
  static String get wenkuLoginSessionExpired => lrText('wenkuLoginSessionExpired');
  static String get wenkuLoginHostNote => lrText('wenkuLoginHostNote');
  static String get wenkuSourceClosedNote => lrText('wenkuSourceClosedNote');
  static String get wenkuEndpointsPendingNote => lrText('wenkuEndpointsPendingNote');
  static String get wenkuLoginNoSession => lrText('wenkuLoginNoSession');
  /// 列表型文案：成员键由 `kCatalogLists` 登记，逐条从 ARB 取值。
  static List<String> get aboutParagraphs => lrList('aboutParagraphs');

  /// 列表型文案键（值由 catalog 的 `kCatalogLists` 提供成员）。
  static const List<String> listKeys = <String>['aboutParagraphs'];

  /// 全部文案键：ARB、catalog、覆盖度自检与规格单测的**唯一键集合**。
  /// 新增 ARB 键必须同步登记，否则 `LocalizedLegalTexts.missingKeys()`
  /// 与静态自检会立刻报缺项。
  static const List<String> keys = <String>[
    'appDisclaimer',
    'nonOfficial',
    'freeStatement',
    'sources',
    'contentRights',
    'thirdPartyService',
    'onlineAvailability',
    'issueGuidance',
    'onlineEntryNote',
    'localOnlyNote',
    'importFormats',
    'archiveNotice',
    'permissionNotice',
    'importChannels',
    'importBody',
    'importTitle',
    'importWizardTitle',
    'importWizardStaticNote',
    'importRar5Reason',
    'importEncryptedReason',
    'importUnsupportedReason',
    'importNoModeHint',
    'importNoGrantHint',
    'importScanEmpty',
    'importNoAcceptedHint',
    'importConflictNote',
    'importDoneNote',
    'importWizardEntry',
    'emptyLibraryTitle',
    'emptyLibraryBody',
    'noResultTitle',
    'noResultBody',
    'demoDataNote',
    'excerptLocalNote',
    'excerptExportNote',
    'excerptReadOnlyNote',
    'excerptEmptyTitle',
    'excerptEmptyBody',
    'excerptNoResultTitle',
    'excerptNoResultBody',
    'comicPlaceholderNote',
    'comicTocNote',
    'comicLocalNote',
    'favoriteLocalNote',
    'favoriteEmptyTitle',
    'favoriteEmptyBody',
    'favoritesOnlyHint',
    'screenshotNote',
    'keepsakeTitle',
    'calendarMonthTitle',
    'keepsakeStaticNote',
    'calendarStaticNote',
    'keepsakeEmptyTitle',
    'keepsakeEmptyBody',
    'calendarNoRecordNote',
    'calendarOutOfRangeNote',
    'calendarOpenMonth',
    'calendarBackToThisMonth',
    'calendarAllMonths',
    'localizationTitle',
    'localizationPreviewTitle',
    'localizationDefaultNote',
    'localizationStaticNote',
    'comicSpreadTitle',
    'comicBlankSlotNote',
    'comicVerticalLockNote',
    'comicSpreadStaticNote',
    'bookExcerptTitle',
    'bookExcerptEmptyTitle',
    'bookExcerptEmptyBody',
    'bookExcerptScopedNote',
    'bookExcerptPinnedNote',
    'bookExcerptStaticNote',
    'bookExcerptMissingNote',
    'excerptSearchTitleNote',
    'excerptExportSnapshotNote',
    'keepsakeAllKinds',
    'keepsakeOpenLibrary',
    'keepsakeLibraryTitle',
    'keepsakeFilterHint',
    'keepsakeKindEmptyTitle',
    'keepsakeKindEmptyBody',
    'keepsakeNoResultTitle',
    'keepsakeNoResultBody',
    'keepsakeFilterStaticNote',
    'keepsakeWidgetKindNote',
    'keepsakeMonthPreviewNote',
    'keepsakeMonthPreviewOpen',
    'keepsakeMonthEmptyBody',
    'keepsakeMonthKindEmptyBody',
    'keepsakeMonthNoResultBody',
    'comicWideSoloTitle',
    'comicWideSoloNote',
    'comicWideSoloSingleNote',
    'excerptAnchorRestoreNote',
    'keepsakeDayEmptyTitle',
    'keepsakeDayEmptyBody',
    'keepsakeDayFilterNote',
    'calendarOpenMonthKeepsakes',
    'calendarOpenDayKeepsakes',
    'calendarCrossMonthNote',
    'calendarInvalidDateNote',
    'keepsakeOpenCalendarDay',
    'keepsakeOpenCalendarMonth',
    'comicSpineGutterTitle',
    'comicSpineGutterNote',
    'comicSpineShadeTitle',
    'comicSpineShadeNote',
    'keepsakeDateRangeTitle',
    'keepsakeDateRangeHint',
    'keepsakeDateRangeNote',
    'keepsakeDateRangeInvalid',
    'keepsakeDateRangeFilterNote',
    'keepsakeDateRangeAll',
    'keepsakeDateRangeThisMonth',
    'keepsakeDateRangeLast7',
    'keepsakeRangeEmptyTitle',
    'keepsakeRangeEmptyBody',
    'calendarOpenDayExcerpts',
    'excerptDayFilterNote',
    'excerptDayEmptyTitle',
    'excerptDayEmptyBody',
    'excerptDayScopedTitle',
    'wenkuOnlySources',
    'wenkuContentOwnership',
    'wenkuNoWithdrawn',
    'wenkuNoCircumvention',
    'wenkuThirdParty',
    'wenkuNoCredentials',
    'wenkuSourceNote',
    'wenkuLocalSourceNote',
    'wenkuCustomSourceNote',
    'wenkuShelfTabLocal',
    'wenkuShelfTabCloud',
    'wenkuCloudTitle',
    'wenkuCloudSubtitle',
    'wenkuSourceNavTitle',
    'wenkuFeedTitle',
    'wenkuSearchHint',
    'wenkuStatusNote',
    'wenkuLockedTitle',
    'wenkuLockedBody',
    'wenkuUnlockButton',
    'wenkuBookAdd',
    'wenkuBookAdded',
    'wenkuDetailTitle',
    'wenkuDetailSynopsis',
    'wenkuDetailToc',
    'wenkuDetailChapterNote',
    'wenkuDetailStaticNote',
    'wenkuEmptyTitle',
    'wenkuEmptyBody',
    'wenkuRefresh',
    'wenkuAddedNote',
    'feedbackTitle',
    'feedbackSubtitle',
    'feedbackPreviewTitle',
    'feedbackMissing',
    'feedbackStaticNote',
    'supportTitle',
    'supportBody',
    'profileHeroTitle',
    'profileHeroSubtitle',
    'profileSectionAppearance',
    'profileSectionSources',
    'profileSectionLibrary',
    'profileSectionFavorites',
    'profileSectionSupport',
    'profileSectionAbout',
    'cloudChannelsTitle',
    'cloudChannelsNote',
    'mergeRecordsNote',
    'wenkuFormatsNote',
    'unlockModeTitle',
    'unlockModeBody',
    'wenkuRealSourceNote',
    'wenkuEndpointNote',
    'wenkuChallengeNote',
    'wenkuWithdrawnNote',
    'wenkuRateLimitNote',
    'wenkuUnavailableNote',
    'wenkuUpstreamChangedNote',
    'wenkuNoRelayNote',
    'wenkuChapterNote',
    'wenkuLocalVerifyNote',
    'wenkuSdkAbsentNote',
    'wenkuPlatformPermissionNote',
    'wenkuLoginTitle',
    'wenkuLoginUsername',
    'wenkuLoginPassword',
    'wenkuLoginAction',
    'wenkuLogoutAction',
    'wenkuLoginCredentialNote',
    'wenkuLoginLoggedOut',
    'wenkuLoginFailed',
    'wenkuLoginSessionExpired',
    'wenkuLoginHostNote',
    'wenkuSourceClosedNote',
    'wenkuEndpointsPendingNote',
    'wenkuLoginNoSession',
  ];
}
