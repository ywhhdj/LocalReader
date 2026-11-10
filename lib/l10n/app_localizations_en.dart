// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Local Reader';

  @override
  String get feedbackNoCredentials => '';

  @override
  String get aboutParagraph1 =>
      'Supports Android, iOS and HarmonyOS. This is not an official Wenku8 app.';

  @override
  String get aboutParagraph2 =>
      'The app is entirely free and voluntarily supported. All features are free; no memberships, activation codes or feature unlocks are sold. Beware of anyone charging for access in the name of this project or its developer.';

  @override
  String get aboutParagraph3 =>
      'Only Wenku8 and local imports are supported. Other sources and custom book sources are not supported.';

  @override
  String get aboutParagraph4 =>
      'Novels, covers and illustrations belong to their respective rights holders; the source-code license does not grant rights to that content. Access only content you are entitled to use and follow the source website\'s rules. Do not bypass access restrictions, break DRM, or copy, distribute or sell content without permission.';

  @override
  String get aboutParagraph5 =>
      'When reporting an issue, include the app version, device, OS version and steps to reproduce. Never include passwords, cookies or tokens in issue reports.';

  @override
  String get aboutParagraph6 =>
      'Third-party services may change, rate-limit requests, or become unavailable.';

  @override
  String get appDisclaimer =>
      'This is a third-party reading client for reading and managing local books. It does not operate an online library, publish novels, or bundle novel files. Online content and availability are determined by Wenku8; the app does not provide online access to books withdrawn for copyright reasons.';

  @override
  String get nonOfficial =>
      'Supports Android, iOS and HarmonyOS. This is not an official Wenku8 app.';

  @override
  String get freeStatement =>
      'The app is entirely free and voluntarily supported. All features are free; no memberships, activation codes or feature unlocks are sold. Beware of anyone charging for access in the name of this project or its developer.';

  @override
  String get sources =>
      'Only Wenku8 and local imports are supported. Other sources and custom book sources are not supported.';

  @override
  String get contentRights =>
      'Novels, covers and illustrations belong to their respective rights holders; the source-code license does not grant rights to that content. Access only content you are entitled to use and follow the source website\'s rules. Do not bypass access restrictions, break DRM, or copy, distribute or sell content without permission.';

  @override
  String get thirdPartyService =>
      'Third-party services may change, rate-limit requests, or become unavailable.';

  @override
  String get onlineAvailability =>
      'Online content and availability are determined by Wenku8; third-party services may change, rate-limit requests, or become unavailable.';

  @override
  String get issueGuidance =>
      'When reporting an issue, include the app version, device, OS version and steps to reproduce. Never include passwords, cookies or tokens in issue reports.';

  @override
  String get onlineEntryNote =>
      'Only online listings, details and table-of-contents metadata are shown here. Reading content must be imported into the local library by the user. The app does not bundle, package or distribute novel files, and does not provide online access to books withdrawn for copyright reasons.';

  @override
  String get localOnlyNote =>
      'Pure-local mode is on by default; when enabled the app makes no network requests. Online listings and WebDAV are off by default.';

  @override
  String get importFormats =>
      'TXT (encoding detection + chapter splitting), EPUB, CBZ/ZIP, image folders, PDF (page rendering), RAR4 and earlier.';

  @override
  String get archiveNotice =>
      'RAR5 and encrypted archives are not supported; convert them to CBZ/ZIP.';

  @override
  String get permissionNotice =>
      'Permissions: on Android 13+ only image-read access is requested. Document-type books are not covered by the media store and still require directory authorization through the system file picker or \'All files access\'. No audio, video or notification permissions are requested. The import dialog clearly reports the current state when permission is missing.';

  @override
  String get importChannels =>
      'Import through OpenList / WebDAV or Quark Drive (experimental); OneDrive, Google Drive and similar services are reachable through the system document picker. Authorization is persisted and can be rescanned after restart.';

  @override
  String get importBody =>
      'TXT (encoding detection + chapter splitting), EPUB, CBZ/ZIP, image folders, PDF (page rendering), RAR4 and earlier.\nRAR5 and encrypted archives are not supported; convert them to CBZ/ZIP.\n\nPermissions: on Android 13+ only image-read access is requested. Document-type books are not covered by the media store and still require directory authorization through the system file picker or \'All files access\'. No audio, video or notification permissions are requested. The import dialog clearly reports the current state when permission is missing.\n\nImport through OpenList / WebDAV or Quark Drive (experimental); OneDrive, Google Drive and similar services are reachable through the system document picker. Authorization is persisted and can be rescanned after restart.\n\nPure-local mode is on by default; when enabled the app makes no network requests. Online listings and WebDAV are off by default.';

  @override
  String get importTitle => 'Import books';

  @override
  String get importWizardTitle => 'Import wizard';

  @override
  String get importWizardStaticNote =>
      'Static delivery mode: authorization and scanning use local demo data only. No system file picker is opened, no file bytes are read, nothing is extracted, and no network request is made. Real SAF persistence and file scanning require platform implementations (frozen).';

  @override
  String get importRar5Reason =>
      'RAR5 is not supported; convert to CBZ/ZIP and scan again.';

  @override
  String get importEncryptedReason =>
      'Encrypted archives are not supported; convert to CBZ/ZIP and scan again.';

  @override
  String get importUnsupportedReason =>
      'Unregistered format; the static build does not guess file contents. Please check the extension.';

  @override
  String get importNoModeHint =>
      'Choose an authorization method before continuing.';

  @override
  String get importNoGrantHint =>
      'Authorization is not confirmed. In the static build this only records your choice; no system permission is requested.';

  @override
  String get importScanEmpty =>
      'No importable book files were found in this directory.';

  @override
  String get importNoAcceptedHint =>
      'No importable files. Handle unsupported formats first, then scan again.';

  @override
  String get importConflictNote =>
      'A book with the same title already exists. The demo library is read-only, so \'Replace\' and \'Merge records\' are deferred; \'Keep both\' creates a copy.';

  @override
  String get importDoneNote =>
      'Import results are written to the in-memory library only and reset to demo data on restart; the read-only demo books are never modified.';

  @override
  String get importWizardEntry => 'Open import wizard';

  @override
  String get emptyLibraryTitle => 'Your library is empty';

  @override
  String get emptyLibraryBody =>
      'Authorize a directory with the system file picker, then import local books. TXT / EPUB / CBZ / PDF and more are supported. Document-type books are not covered by the media store and need directory authorization or \'All files access\'.';

  @override
  String get noResultTitle => 'No books found';

  @override
  String get noResultBody =>
      'Try a shorter title or author name, or switch keywords. Search runs only against the local library and makes no network requests.';

  @override
  String get demoDataNote =>
      'Demo data is shown; edits are kept in memory and reset on restart.';

  @override
  String get excerptLocalNote =>
      'Excerpts are kept locally in memory only; nothing is uploaded and no network is used. Demo data returns on restart.';

  @override
  String get excerptExportNote =>
      'Export produces a local plain-text preview only: no file is written, no system share is invoked and nothing is uploaded. Writing to disk and sharing require platform capabilities and are not implemented in the static build.';

  @override
  String get excerptReadOnlyNote =>
      'Demo excerpts are read-only; you can edit notes, change highlight colors, or delete entries you captured yourself.';

  @override
  String get excerptEmptyTitle => 'No excerpts yet';

  @override
  String get excerptEmptyBody =>
      'Select one or more lines in the reader, then tap the bookmark icon in the top bar to capture an excerpt.';

  @override
  String get excerptNoResultTitle => 'No matching excerpts';

  @override
  String get excerptNoResultBody =>
      'Try a shorter keyword, or clear the book / highlight / scope filters.';

  @override
  String get comicPlaceholderNote =>
      'Pages are placeholders sized by aspect ratio; real page pixels require the three-platform BookRenderBridge. The static build does not decode images.';

  @override
  String get comicTocNote =>
      'Chapters are recognized from directory and file names inside the archive; nothing is extracted and no file contents are read. Unrecognized pages go to \'Unsorted\' and are never silently dropped. The recognition rate is shown when incomplete.';

  @override
  String get comicLocalNote =>
      'Comic reading and chapter detection are fully local: no network, no upload. Page pixel rendering requires platform capabilities (frozen).';

  @override
  String get favoriteLocalNote =>
      'Favorites are kept locally in memory only; nothing is uploaded and no network is used. Demo favorites return on restart.';

  @override
  String get favoriteEmptyTitle => 'No favorites yet';

  @override
  String get favoriteEmptyBody =>
      'Tap the star on a book detail page or in the reader top bar to add it here.';

  @override
  String get favoritesOnlyHint => 'Favorites only';

  @override
  String get screenshotNote =>
      'The screenshots use demo book data. The app interface is in Chinese.';

  @override
  String get keepsakeTitle => 'Keepsakes';

  @override
  String get calendarMonthTitle => 'Reading calendar - Month';

  @override
  String get keepsakeStaticNote =>
      'Keepsakes are generated from reading stats and excerpts; no demo entries are hand-written. They are kept locally in memory only, with no upload and no network. Five seasonal journal styles can be switched on the shelf; desktop widgets require native implementations on all three platforms (frozen).';

  @override
  String get calendarStaticNote =>
      'The month view aggregates the 35-day demo heatmap and excerpts, starting on Monday with a fixed six-week grid. Cross-month padding cells align the grid only and are excluded from monthly totals. The static build does not read a real reading database.';

  @override
  String get keepsakeEmptyTitle => 'No keepsakes yet';

  @override
  String get keepsakeEmptyBody =>
      'Keep reading, reach a goal, or capture a line, and keepsakes will appear here automatically.';

  @override
  String get calendarNoRecordNote => 'No reading record for this day';

  @override
  String get calendarOutOfRangeNote =>
      'You have reached the edge of the demo data range';

  @override
  String get calendarOpenMonth => 'View month';

  @override
  String get calendarBackToThisMonth => 'Back to this month';

  @override
  String get calendarAllMonths => 'All';

  @override
  String get localizationTitle => 'Text catalog and language preview';

  @override
  String get localizationPreviewTitle => 'Preview texts by language';

  @override
  String get localizationDefaultNote =>
      'Chinese by default - does not follow the system language';

  @override
  String get localizationStaticNote =>
      'The released app interface is in Chinese (see the reference README: The app interface is in Chinese). The static build only validates the multilingual catalog structure and fallback rules: it does not follow the system language and does not switch in-app texts page by page. Pages still read the Chinese default bundle. Full per-page localization is a later candidate.';

  @override
  String get comicSpreadTitle => 'Two-page spreads and reading direction';

  @override
  String get comicBlankSlotNote => 'Blank filler - not a missing page';

  @override
  String get comicVerticalLockNote =>
      'Continuous vertical scrolling has no left/right axis, so it is locked to single-page, left-to-right. Switch to paged spreads to enable two-page and right-to-left preferences.';

  @override
  String get comicSpreadStaticNote =>
      'Two-page spreads only arrange page order and visual slots: the cover occupies its own spread, and odd trailing pages get a labelled blank filler - never a silently dropped page or a fabricated image. Right-to-left changes slot order and the forward paging direction, not reading order. The static build still uses aspect-ratio placeholders: it does not decode images or read file bytes. Page pixels and real gestures require the three-platform BookRenderBridge (frozen).';

  @override
  String get bookExcerptTitle => 'Excerpts from this book';

  @override
  String get bookExcerptEmptyTitle => 'No excerpts for this book yet';

  @override
  String get bookExcerptEmptyBody =>
      'Select one or more lines in the reader, then tap the bookmark icon in the top bar to capture an excerpt; come back here to see it. You can also clear the filter to browse excerpts from every book.';

  @override
  String get bookExcerptScopedNote =>
      'Only this book is shown; tap \"All books\" to browse every excerpt. Filtering uses the bookId, so editing the title on the detail page never breaks the filter.';

  @override
  String get bookExcerptPinnedNote =>
      'This book has no excerpts yet, but it stays in the book filter with a 0 count instead of becoming an invisible active filter.';

  @override
  String get bookExcerptStaticNote =>
      'The detail page passes only a bookId; the excerpt library applies the filter itself, so features never depend on each other. Excerpts stay in memory: no network, no upload, no disk writes. Desktop widgets and persistence remain frozen.';

  @override
  String get bookExcerptMissingNote =>
      'This book is not in the current library (it may have been removed or come from a previous import session). Excerpts are still matched by bookId; tap \"All books\" to browse the rest.';

  @override
  String get excerptSearchTitleNote =>
      'Book-name search matches both the current library title and the title captured with the excerpt, so either the new or the old name still finds it after a rename.';

  @override
  String get excerptExportSnapshotNote =>
      'Exported text keeps the book name captured at the time of the excerpt, so a historical export stays reproducible; on-screen titles, search, sorting and grouping use the current library name.';

  @override
  String get keepsakeAllKinds => 'All types';

  @override
  String get keepsakeOpenLibrary => 'View all keepsakes';

  @override
  String get keepsakeLibraryTitle => 'Keepsake library';

  @override
  String get keepsakeFilterHint =>
      'Type and month filters combine. The count beside each type changes with the month and keyword, not with the type you have selected.';

  @override
  String get keepsakeKindEmptyTitle => 'No keepsakes of this type yet';

  @override
  String get keepsakeKindEmptyBody =>
      'Keepsakes are generated from reading records and excerpts, so this type appears once its condition is met. Clear the filters to browse other types.';

  @override
  String get keepsakeNoResultTitle => 'No keepsakes match these filters';

  @override
  String get keepsakeNoResultBody =>
      'Try another type, month, or keyword, or clear the filters to see every keepsake.';

  @override
  String get keepsakeFilterStaticNote =>
      'Keepsakes are aggregated only from the stats snapshot and excerpts. They live in memory only: no network, no persistence, no list caching. Native home-screen widgets remain frozen.';

  @override
  String get keepsakeWidgetKindNote =>
      'When the content is Keepsakes, each widget can show a single type on its own; leave it unset to show all. Multiple widgets stay independent.';

  @override
  String get keepsakeMonthPreviewNote =>
      '\"This month\" follows the fixed reference day of the stats snapshot, so it stays aligned with the heatmap and keepsake library. Native home-screen widgets remain frozen; this is an in-app preview only.';

  @override
  String get keepsakeMonthPreviewOpen => 'View this month keepsakes';

  @override
  String get keepsakeMonthEmptyBody =>
      'No keepsakes this month yet. They are generated from reading records and excerpts, so this card fills in once a condition is met.';

  @override
  String get keepsakeMonthKindEmptyBody =>
      'This month has keepsakes, but none of the selected type. Clear the type filter to see all of them.';

  @override
  String get keepsakeMonthNoResultBody =>
      'Nothing matches the current filters this month. Try another type or clear the filters.';

  @override
  String get comicWideSoloTitle => 'Wide pages get their own spread';

  @override
  String get comicWideSoloNote =>
      'Panorama and two-page illustration spreads are never paired with a neighbouring page. Neighbouring pages get an explicit blank slot marked as padding, not a missing page.';

  @override
  String get comicWideSoloSingleNote =>
      'In single-page mode every page already has its own spread, so this preference is kept but has no visual effect.';

  @override
  String get excerptAnchorRestoreNote =>
      'After reflow, highlights restore in three tiers: exact position, same position with changed text, then unique text within the chapter. Identical text in several places is never highlighted automatically.';

  @override
  String get keepsakeDayEmptyTitle => 'No keepsakes on this day yet';

  @override
  String get keepsakeDayEmptyBody =>
      'Pick another day in the reading calendar, or clear the day filter to see the whole month.';

  @override
  String get keepsakeDayFilterNote =>
      'This day only - clear it to return to the whole month';

  @override
  String get calendarOpenMonthKeepsakes => 'View this month keepsakes';

  @override
  String get calendarOpenDayKeepsakes => 'View keepsakes on this day';

  @override
  String get calendarCrossMonthNote =>
      'Overflow cells only align the week grid and do not link to another month';

  @override
  String get calendarInvalidDateNote =>
      'Invalid date key: cannot locate the day in the reading calendar';

  @override
  String get keepsakeOpenCalendarDay => 'Open in calendar';

  @override
  String get keepsakeOpenCalendarMonth => 'View the whole month';

  @override
  String get comicSpineGutterTitle => 'Two-page spine gutter';

  @override
  String get comicSpineGutterNote =>
      'The spine is drawn only when two real pages share a spread. The centre gutter scales with slot width and is clamped to 8-28 px; both inner edges get a subtle shade to suggest binding. Cover, wide-page and blank-slot spreads never draw a spine.';

  @override
  String get comicSpineShadeTitle => 'Spine shade strength';

  @override
  String get comicSpineShadeNote =>
      'Strength is derived from slot width (subtle on narrow screens, stronger on wide ones) and the shade colour from background luminance: a black shadow on light backgrounds, a reduced light highlight on dark ones so the spine stays visible in night mode. This is a fixed visual rule, not a user preference. Static delivery models the values only; no on-device tuning has been done.';

  @override
  String get keepsakeDateRangeTitle => 'Date range';

  @override
  String get keepsakeDateRangeHint => 'YYYY-MM-DD';

  @override
  String get keepsakeDateRangeNote =>
      'Inclusive range; either end may be left empty. A start later than the end is swapped automatically. Setting a range clears the single-day and whole-month filters so they cannot contradict each other.';

  @override
  String get keepsakeDateRangeInvalid =>
      'Invalid date format. Use YYYY-MM-DD, for example 2026-11-08';

  @override
  String get keepsakeDateRangeFilterNote =>
      'This range only - clear it to return to all keepsakes';

  @override
  String get keepsakeDateRangeAll => 'All dates';

  @override
  String get keepsakeDateRangeThisMonth => 'This month';

  @override
  String get keepsakeDateRangeLast7 => 'Last 7 days';

  @override
  String get keepsakeRangeEmptyTitle => 'No keepsakes in this range yet';

  @override
  String get keepsakeRangeEmptyBody =>
      'Try another range, clear it, or open the reading calendar to browse day by day.';

  @override
  String get calendarOpenDayExcerpts => 'View excerpts on this day';

  @override
  String get excerptDayFilterNote =>
      'This day only - clear it to return to all excerpts';

  @override
  String get excerptDayEmptyTitle => 'No excerpts on this day yet';

  @override
  String get excerptDayEmptyBody =>
      'Pick another day in the reading calendar, or clear the day filter to see all excerpts.';

  @override
  String get excerptDayScopedTitle => 'Excerpts on this day';

  @override
  String get wenkuOnlySources =>
      'Only Wenku8 listings and user-imported local books are supported. Other sources and custom book sources are not supported.';

  @override
  String get wenkuContentOwnership =>
      'Novels, covers, and illustrations belong to their respective rights holders; the source-code license grants no rights to that content.';

  @override
  String get wenkuNoWithdrawn =>
      'We do not operate an online library, publish novels, or bundle novel files, and we do not provide access to books withdrawn for copyright reasons.';

  @override
  String get wenkuNoCircumvention =>
      'Access only content you are entitled to use and follow the source website rules. Do not bypass access restrictions, break DRM, or copy, distribute, or sell content without permission.';

  @override
  String get wenkuThirdParty =>
      'Third-party services may change, rate-limit requests, or become unavailable. Listing and content availability are determined by Wenku8.';

  @override
  String get wenkuNoCredentials =>
      'Never include passwords, cookies, or tokens in issue reports. Common credential fields are removed automatically when generating a preview.';

  @override
  String get wenkuSourceNote =>
      'The only online source. Reads listings and table-of-contents metadata; chapter text is provided by Wenku8 at use time and is never cached or bundled here.';

  @override
  String get wenkuLocalSourceNote =>
      'Book files are imported by you, with the full local-library format and directory-authorization support.';

  @override
  String get wenkuCustomSourceNote =>
      'Custom book sources are not offered; the source list is fixed to Wenku8 and local imports.';

  @override
  String get wenkuShelfTabLocal => 'Local library';

  @override
  String get wenkuShelfTabCloud => 'Cloud sources';

  @override
  String get wenkuCloudTitle => 'Cloud sources';

  @override
  String get wenkuCloudSubtitle =>
      'Pick a source and see what is there to read';

  @override
  String get wenkuSourceNavTitle => 'Sources';

  @override
  String get wenkuFeedTitle => 'Listings';

  @override
  String get wenkuSearchHint => 'Search title or author';

  @override
  String get wenkuStatusNote =>
      'Only listing and table-of-contents metadata is read; withdrawn titles are hidden and chapter text is not cached in this app.';

  @override
  String get wenkuLockedTitle => 'Online listings are off';

  @override
  String get wenkuLockedBody =>
      'Pure-local mode makes zero network requests and does not even read the demo listing. Once enabled you can browse Wenku8 listings, details, and tables of contents, and add a book to the local library.';

  @override
  String get wenkuUnlockButton => 'Enable online listings';

  @override
  String get wenkuBookAdd => 'Add to local library';

  @override
  String get wenkuBookAdded => 'Already in local library';

  @override
  String get wenkuDetailTitle => 'Book details';

  @override
  String get wenkuDetailSynopsis => 'Synopsis';

  @override
  String get wenkuDetailToc => 'Volumes and chapters';

  @override
  String get wenkuDetailChapterNote =>
      'Chapter text is provided by Wenku8 at use time.';

  @override
  String get wenkuDetailStaticNote =>
      'Static delivery registers a metadata shell only: no download, no cache, no bundled novel text. Once added, it is managed like any other local book.';

  @override
  String get wenkuEmptyTitle => 'Nothing in this listing yet';

  @override
  String get wenkuEmptyBody =>
      'Try another listing or search term; third-party listings may also be temporarily unavailable.';

  @override
  String get wenkuRefresh => 'Refresh listing';

  @override
  String get wenkuAddedNote =>
      'Added to the local library; switch back to the Local library tab to see it.';

  @override
  String get feedbackTitle => 'Report a problem';

  @override
  String get feedbackSubtitle =>
      'Four details make an issue much easier to reproduce';

  @override
  String get feedbackPreviewTitle => 'Issue report - plain text preview';

  @override
  String get feedbackMissing => 'Still needed: ';

  @override
  String get feedbackStaticNote =>
      'Generates plain text for copying only; no upload, no Issue page, no file writes. Please review it before submitting.';

  @override
  String get supportTitle => 'Everything is free';

  @override
  String get supportBody =>
      'All features are free. No memberships, activation codes, or feature unlocks are sold; support is entirely voluntary. Beware of anyone charging for access in the name of this project or its developer.';

  @override
  String get profileHeroTitle => 'Profile';

  @override
  String get profileHeroSubtitle => 'Tune reading to your own taste';

  @override
  String get profileSectionAppearance => 'Appearance and reading';

  @override
  String get profileSectionSources => 'Sources and online';

  @override
  String get profileSectionLibrary => 'Library and import';

  @override
  String get profileSectionFavorites => 'Favorites';

  @override
  String get profileSectionSupport => 'Support and feedback';

  @override
  String get profileSectionAbout => 'About';

  @override
  String get cloudChannelsTitle => 'Cloud import channels';

  @override
  String get cloudChannelsNote =>
      'OpenList, WebDAV, Quark Drive (experimental), and the system document picker for OneDrive, Google Drive, and similar services. Channels are entry points only; no accounts or credentials are built in, and real authorization and file access are frozen in static delivery.';

  @override
  String get mergeRecordsNote =>
      'Strategies for manually merging and syncing original books with reading records are registered in the import wizard; static delivery records them as deferred decisions and does not modify the demo library.';

  @override
  String get wenkuFormatsNote =>
      'Formats now match the reference project: TXT, EPUB, MOBI, AZW, AZW3, PRC, FB2, PDF, DOC, DOCX, RTF, HTML, Markdown, and ZIP. Legacy binary formats are registered as routes only in static delivery; their decoders stay frozen.';

  @override
  String get unlockModeTitle => 'Static delivery unlocked';

  @override
  String get unlockModeBody =>
      'The Wenku8 pipeline now uses a real HTTP source. Pure-local mode is still the default and makes zero requests while locked.';

  @override
  String get wenkuRealSourceNote =>
      'The real source and the demo source share one contract; swapping them at the single injection point leaves pages and compliance untouched.';

  @override
  String get wenkuEndpointNote =>
      'URLs are built only in the site adapter. No official page-structure docs are public, so path templates must be checked against the live site.';

  @override
  String get wenkuChallengeNote =>
      'The source asks for an access check. Please finish it on the Wenku8 website; this app does not bypass verification.';

  @override
  String get wenkuWithdrawnNote =>
      'Content withdrawn for copyright reasons is not listed, cached, or made accessible.';

  @override
  String get wenkuRateLimitNote =>
      'The source is rate-limiting requests. Please try later and do not keep refreshing.';

  @override
  String get wenkuUnavailableNote =>
      'Third-party services may change, rate-limit requests, or become temporarily unavailable.';

  @override
  String get wenkuUpstreamChangedNote =>
      'The source page structure changed. Update the parser against the live public pages; garbled text is never rendered as content.';

  @override
  String get wenkuNoRelayNote =>
      'No relay, proxy, cookie, login, forged appver, or browser-style UA spoofing is implemented. Access restrictions are not bypassed.';

  @override
  String get wenkuChapterNote =>
      'Only the single chapter you open is read. No whole-book download, bundling, or redistribution.';

  @override
  String get wenkuLocalVerifyNote =>
      'Verify locally: flutter pub get, then flutter analyze, flutter test, and flutter run. Check site reachability and page structure first.';

  @override
  String get wenkuSdkAbsentNote =>
      'This delivery environment has no Flutter/Dart SDK. Compilable source and specs are provided; build and device verification run in your environment.';

  @override
  String get wenkuPlatformPermissionNote =>
      'Android INTERNET, iOS ATS, and HarmonyOS INTERNET permission skeletons are in place; check them against each platform project template.';

  @override
  String get wenkuLoginTitle => 'Sign in to Wenku8';

  @override
  String get wenkuLoginUsername => 'Username';

  @override
  String get wenkuLoginPassword => 'Password';

  @override
  String get wenkuLoginAction => 'Sign in';

  @override
  String get wenkuLogoutAction => 'Sign out';

  @override
  String get wenkuLoginCredentialNote =>
      'Credentials stay in memory for this run only. They are never written to disk, logs, or issue reports, and are discarded on sign-out or app close.';

  @override
  String get wenkuLoginLoggedOut =>
      'Not signed in. Public listings remain available; sign in to read your personal bookcase.';

  @override
  String get wenkuLoginFailed =>
      'Sign-in did not complete. Check your account and the source site status; a broken page is never reported as a wrong password.';

  @override
  String get wenkuLoginSessionExpired =>
      'The session expired. Please sign in again.';

  @override
  String get wenkuLoginHostNote =>
      'Switch the source domain between wenku8.net and wenku8.com. Both belong to the source site; no other book sources are offered.';

  @override
  String get wenkuSourceClosedNote =>
      'The source returned a closure notice instead of a login form. The app will not submit your account or password to that page.';

  @override
  String get wenkuEndpointsPendingNote =>
      'Login, bookcase, search, ranking, detail and reader paths are configured from the supplied page list and are not yet verified against live pages. Check them on a device.';

  @override
  String get wenkuLoginNoSession =>
      'The offline demo source has no login session. Switch to the real source to sign in.';

  @override
  String get uiLocalReader => 'Local Reader';

  @override
  String get uiShelf => 'Shelf';

  @override
  String get uiLightNovels => 'Light Novels';

  @override
  String get uiStats => 'Stats';

  @override
  String get uiProfile => 'Profile';

  @override
  String get uiGotIt => 'Got it';

  @override
  String get uiAppLanguage => 'App language';

  @override
  String get uiFollowSystem => 'Follow system';

  @override
  String get uiPhrase008 => '简体中文';

  @override
  String get uiEnglish => 'English';

  @override
  String get uiWhenFollowingTheSystemFlutterResolvesTheLocale =>
      'When following the system, Flutter resolves the locale via supportedLocales; unsupported languages fall back to Simplified Chinese.';

  @override
  String uiMapLocaleLegaltextbundleLanguages(String p0) {
    return 'Map<Locale, LegalTextBundle> · $p0  languages';
  }

  @override
  String uiKeysLists(String p0, String p1) {
    return ' · $p0 keys + $p1 lists';
  }

  @override
  String uiCoverageCheck(String p0) {
    return 'Coverage check · $p0';
  }

  @override
  String uiItems(String p0, String p1) {
    return '缺 items $p0 · 多余键 $p1';
  }

  @override
  String uiChapters(String p0) {
    return '$p0 chapters';
  }

  @override
  String get uiRemoveFavorite => 'Remove favorite';

  @override
  String get uiFavoriteThisBook => 'Favorite this book';

  @override
  String get uiAddedToFavorites => 'Added to favorites';

  @override
  String get uiRemovedFromFavorites => 'Removed from favorites';

  @override
  String get uiEditBookInfo => 'Edit book info';

  @override
  String get uiTableOfContents => 'Table of contents';

  @override
  String get uiContinueReading => 'Continue reading';

  @override
  String get uiStartReading => 'Start reading';

  @override
  String get uiNoVolume => 'No volume';

  @override
  String uiVolume(String p0) {
    return 'Volume $p0';
  }

  @override
  String uiLocalLibrary(String p0) {
    return 'local library · $p0';
  }

  @override
  String get uiReadingProgress => 'Reading progress';

  @override
  String uiChaptersSampleData(String p0) {
    return '上次读到约第 $p0  chapters · Sample data';
  }

  @override
  String get uiNotStartedYet => 'Not started yet';

  @override
  String get uiContents => 'Contents';

  @override
  String uiTotalChapters(String p0) {
    return 'total $p0  chapters';
  }

  @override
  String get uiViewAll => 'View all';

  @override
  String get uiLastRead => 'Last read';

  @override
  String uiItems2(String p0) {
    return '$p0 items';
  }

  @override
  String get uiBookInfo => 'Book info';

  @override
  String get uiSource => 'Source';

  @override
  String get uiImportedLocally => 'Imported locally';

  @override
  String get uiFormat => 'Format';

  @override
  String get uiChapters2 => 'Chapters';

  @override
  String get uiEpisodes => 'Episodes';

  @override
  String uiEpisodesPages(String p0, String p1) {
    return '$p0 episodes · $p1 pages';
  }

  @override
  String get uiAuthorization => 'Authorization';

  @override
  String get uiSystemFilePickerDirectoryAuthorization =>
      'System file-picker directory authorization';

  @override
  String get uiScope => '文档类书籍不在媒体库覆盖scope内，需走系统文件选择器或「所有文件访问」。';

  @override
  String get uiAboutContent => 'About content';

  @override
  String get uiTitle => 'Title';

  @override
  String get uiAuthor => 'Author';

  @override
  String get uiCoverColor => 'Cover color';

  @override
  String get uiVolumeOrder => 'Volume order';

  @override
  String uiVolume2(String p0) {
    return 'Volume $p0';
  }

  @override
  String get uiStaticDemoSaveSampleData =>
      'Static demo：修改仅save在内存，重启后恢复Sample data。';

  @override
  String get uiCancel => 'Cancel';

  @override
  String get uiSave => 'Save';

  @override
  String get uiTitleCannotBeEmpty => 'Title cannot be empty';

  @override
  String uiContents2(String p0) {
    return '$p0 · contents';
  }

  @override
  String get uiSearchChapterTitles => 'Search chapter titles';

  @override
  String uiTotalChapters2(String p0) {
    return 'total $p0  chapters';
  }

  @override
  String get uiTapAChapterToJump => 'Tap a chapter to jump';

  @override
  String get uiNoMatchingChapters => 'No matching chapters';

  @override
  String get uiContentsBodyTextBookdocumentChapters =>
      'contents与body text由同一份 BookDocument 生成，chapters序号与阅读器严格一致。';

  @override
  String get uiCurrentSampleDataTocentryChapters =>
      'current为Sample data；接入真实解析器后由 TocEntry 提供chapters与锚点。';

  @override
  String uiItemscontentBodyText(String p0) {
    return '$p0  itemscontent块 · 演示body text';
  }

  @override
  String get uiCurrentlyReading => 'Currently reading';

  @override
  String get uiEditExcerpt => 'Edit excerpt';

  @override
  String get uiHighlightColor => 'Highlight color';

  @override
  String get uiNote => 'Note';

  @override
  String get uiClearTheFieldToRemoveTheNote =>
      'Clear the field to remove the note';

  @override
  String get uiSaveChanges => 'Save changes';

  @override
  String get uiExportPreview => 'Export preview';

  @override
  String get uiExcerptLibrary => 'Excerpt library';

  @override
  String get uiExportCurrentResultsPlainTextPreview =>
      'Export current results (plain-text preview)';

  @override
  String get uiTextTitleChapterNote => 'Text / title / chapter / note';

  @override
  String get uiAllBooks => 'All books';

  @override
  String uiTotalYours(String p0, String p1) {
    return 'Total $p0 · yours $p1';
  }

  @override
  String uiNoteItemsItems(String p0, String p1) {
    return '有note $p0  items · 命中 $p1  items';
  }

  @override
  String get uiScope2 => 'Scope';

  @override
  String get uiByBook => 'By book';

  @override
  String get uiHighlight => 'Highlight';

  @override
  String get uiAllColors => 'All colors';

  @override
  String get uiSort => 'Sort';

  @override
  String get uiGroup => 'Group';

  @override
  String get uiSelectedBook => 'Selected book';

  @override
  String uiDays(String p0) {
    return '当 days $p0';
  }

  @override
  String uiKeyword(String p0) {
    return 'Keyword \"$p0」';
  }

  @override
  String get uiExcerptDeleted => 'Excerpt deleted';

  @override
  String get uiItemsexcerpts => '这 itemsexcerpts不可删除';

  @override
  String get uiYours => 'Yours';

  @override
  String get uiSampleReadOnly => 'Sample · read-only';

  @override
  String get uiEditNoteHighlight => 'Edit note / highlight';

  @override
  String get uiDeleteExcerpt => 'Delete excerpt';

  @override
  String get uiClearDateFilter => 'Clear date filter';

  @override
  String get uiAllBooks2 => 'All books';

  @override
  String get uiClearFilters => 'Clear filters';

  @override
  String get uiReviewBeforeImporting => 'Review before importing';

  @override
  String get uiSupportedFormats => 'Supported formats';

  @override
  String get uiArchives => 'Archives';

  @override
  String get uiPermissions => 'Permissions';

  @override
  String get uiImportChannels => 'Import channels';

  @override
  String get uiOnline => 'Online';

  @override
  String get uiChooseAnAuthorizationMethod => 'Choose an authorization method';

  @override
  String get uiAuthorizationConfirmed => 'Authorization confirmed';

  @override
  String get uiSimulateAuthorization => 'Simulate authorization';

  @override
  String get uiAuthorizationStaticDemo =>
      'authorization会持久化，重启后可一键重扫（Static demo）';

  @override
  String get uiScanResults => 'Scan results';

  @override
  String get uiScanned => 'Scanned';

  @override
  String get uiImportable => 'Importable';

  @override
  String get uiUnsupported => 'Unsupported';

  @override
  String get uiUnregistered => 'Unregistered';

  @override
  String get uiNameConflict => 'Name conflict';

  @override
  String get uiNoNameConflicts => 'No name conflicts';

  @override
  String get uiResolveDuplicateNames => 'Resolve duplicate names';

  @override
  String uiAll(String p0) {
    return ' all$p0';
  }

  @override
  String uiDuplicateOf(String p0, String p1) {
    return 'Duplicate of 《$p0》 · $p1';
  }

  @override
  String get uiImportSummary => 'Import summary';

  @override
  String get uiScannedFiles => 'Scanned files';

  @override
  String uiItems3(String p0) {
    return '$p0  items';
  }

  @override
  String get uiToBeAdded => 'To be added';

  @override
  String uiBooks(String p0) {
    return '$p0 books';
  }

  @override
  String get uiSkippedUnsupported => 'Skipped / unsupported';

  @override
  String uiItems4(String p0) {
    return '$p0  items';
  }

  @override
  String uiItems5(String p0) {
    return '$p0  items';
  }

  @override
  String get uiDeferred => 'Deferred';

  @override
  String uiItems6(String p0) {
    return '$p0  items';
  }

  @override
  String get uiToBeAdded2 => 'To be added';

  @override
  String get uiBack => 'Back';

  @override
  String get uiWriteToShelfAndClose => 'Write to shelf and close';

  @override
  String get uiNext => 'Next';

  @override
  String get uiReadingFonts => 'Reading & fonts';

  @override
  String get uiMotionReadAloud => 'Motion & read-aloud';

  @override
  String get uiStatsReports => 'Stats & reports';

  @override
  String get uiShelfImport => 'Shelf & import';

  @override
  String get uiBuildCompliance => 'Build & compliance';

  @override
  String get uiFeatureOverview => 'Feature overview';

  @override
  String get uiReferenceRepoFeatureAlignment =>
      'Reference-repo feature alignment · 第二十四轮';

  @override
  String get uiAllGlobalDefaultStaticStageSaveChars =>
      '以下偏好 all挂在全局状态，按书设置与global default分开；Static stage只save选择，不下载 chars体、不发请求、不写文件。';

  @override
  String get uiPerBookLayout => 'Per-book layout';

  @override
  String get uiSaveCharsFontSizeCharsCharsLineHeightNullGloba =>
      '每本书可独立save chars体 / font size /  chars重 /  chars距 / line height / 四边距；null 表示沿用global default。';

  @override
  String get uiLibraryIsEmpty => 'Library is empty';

  @override
  String uiCurrentPt(String p0, String p1) {
    return 'Current: $p0 · $p1 pt · ';
  }

  @override
  String uiLineHeight(String p0) {
    return 'line height $p0 · ';
  }

  @override
  String uiPhrase141(String p0) {
    return '$p0';
  }

  @override
  String get uiUseLargerTextForThisBook => 'Use larger text for this book';

  @override
  String get uiClearPerBookOverrides => 'Clear per-book overrides';

  @override
  String get uiFontCatalog => 'Font catalog';

  @override
  String get uiCharsRemoveCharsChars =>
      '阅读 chars体按需下载、离线可用、可remove、不预装；应用 chars体与阅读器 chars体分开选。';

  @override
  String get uiImportFontSourceHanSans => 'Import font · Source Han Sans';

  @override
  String get uiRegisterImportedTtfOtf => 'Register imported TTF/OTF';

  @override
  String get uiMarkOnDemandPackInstalled => 'Mark on-demand pack installed';

  @override
  String get uiStaticStageFontloaderBooksRemove =>
      'Static stage只登记元数据；FontLoader 注 books、下载与remove文件属平台层（❄️ 冻结）。';

  @override
  String get uiColorSource => 'Color source';

  @override
  String uiContrast1(String p0) {
    return '阅读器独立配色：contrast $p0:1 · ';
  }

  @override
  String uiWcagAaBodyText45(String p0) {
    return '$p0 WCAG AA body text 4.5';
  }

  @override
  String get uiAppFont => 'App font';

  @override
  String get uiReadingFont => 'Reading font';

  @override
  String get uiRemoveCurrentFont => 'Remove current font';

  @override
  String get uiSystemDynamicColorMonet => 'System dynamic color (Monet)';

  @override
  String get uiCustomAccentColor => 'Custom accent color';

  @override
  String get uiPickFromCover => 'Pick from cover';

  @override
  String get uiPageTurnAutoRead => 'Page turn & auto-read';

  @override
  String uiPages(String p0) {
    return '翻 pages速度 ×$p0';
  }

  @override
  String get uiInterfaceMotion => 'Interface motion';

  @override
  String get uiOn => 'On';

  @override
  String get uiOffLocksToNoAnimationAndStopsAutoRead =>
      'Off: locks to no animation and stops auto-read';

  @override
  String get uiAutoRead => 'Auto-read';

  @override
  String uiIntervalMsAutoStopsWhenMotionIsOff(String p0) {
    return 'Interval $p0 ms · Auto-stops when motion is off';
  }

  @override
  String get uiContinuousChapterTransition => 'Continuous chapter transition';

  @override
  String get uiVolumeKeyPaging => 'Volume-key paging';

  @override
  String get uiBilingualReadAloudLanguages =>
      'Bilingual & read-aloud languages';

  @override
  String get uiReadAloudLanguagesItemsVoice =>
      '按书选显示语言；read aloud语言分别选、每 languages一 items voice，没有匹配语音模型的语言直接跳过。';

  @override
  String uiReadAloud(String p0) {
    return '实际会read aloud：$p0';
  }

  @override
  String uiPhrase171(String p0) {
    return '$p0';
  }

  @override
  String get uiStaticStageKeepsakes =>
      'Static stage只维护偏好；真实语音模型 keepsakes举、音色下载与音量键事件属平台层（❄️ 冻结）。';

  @override
  String get uiFiveViews => 'Five views';

  @override
  String get uiPeriodPresetsCustomRange => 'Period (presets / custom range)';

  @override
  String get uiEightReportLayouts => 'Eight report layouts';

  @override
  String uiChars(String p0) {
    return '实际呈现 chars段：$p0';
  }

  @override
  String uiPhrase177(String p0) {
    return '$p0';
  }

  @override
  String get uiTotalContent => '预览与导出total用同一份content：';

  @override
  String get uiStaticStageChars =>
      'Static stage导出只生成 chars符串；写文件与系统分享属平台层（❄️ 冻结）。';

  @override
  String get uiToday => 'Today';

  @override
  String get uiThisWeek => 'This week';

  @override
  String get uiThisMonth => 'This month';

  @override
  String get uiThisYear => 'This year';

  @override
  String get uiAll2 => 'All';

  @override
  String get uiCustom => 'Custom';

  @override
  String get uiShelfViewFilters => 'Shelf view & filters';

  @override
  String get uiMergeLocalLibraryIntoShelf => 'Merge local library into shelf';

  @override
  String uiCurrentBooks(String p0, String p1) {
    return 'current筛选命中 $p0 / $p1  books；';
  }

  @override
  String get uiCarouselParametersLockBackToDefaultInListMode =>
      'Carousel parameters lock back to default in list mode.';

  @override
  String get uiPreImportReviewSeriesVolumeMerge =>
      'Pre-import review & series volume merge';

  @override
  String uiSource2(String p0) {
    return '三种source：$p0；';
  }

  @override
  String uiPolicy(String p0) {
    return 'Policy: $p0。';
  }

  @override
  String uiCurrent(String p0) {
    return 'Current: $p0 → ';
  }

  @override
  String uiPhrase194(String p0) {
    return '$p0 → ';
  }

  @override
  String uiItems7(String p0) {
    return '落到既有冲突策略 $p0 等四 items之一。';
  }

  @override
  String get uiWebdavBackupOffByDefault => 'WebDAV backup (off by default)';

  @override
  String uiContent(String p0) {
    return '备份content：$p0。';
  }

  @override
  String get uiWhenOffEvenTestConnectionMakesNoRequest =>
      'When off, even \"Test connection\" makes no request.';

  @override
  String get uiEnableBackup => 'Enable backup';

  @override
  String get uiStaticDemoNoNetworkRequestWasMade =>
      'Static demo: no network request was made';

  @override
  String get uiStaticStageWebdavclient =>
      'Static stage只演示状态机；WebDavClient、远端列表与导出落盘属平台层（❄️ 冻结）。';

  @override
  String get uiAndroidPermissionTiers => 'Android permission tiers';

  @override
  String uiRemove(String p0) {
    return '已remove：$p0';
  }

  @override
  String get uiCrashLoopProtection => 'Crash-loop protection';

  @override
  String uiMinutes(String p0, String p1) {
    return '阈值 $p0 次 / $p1  minutes内 → ';
  }

  @override
  String uiSkipped(String p0, String p1) {
    return '进$p0 · skipped: $p1。';
  }

  @override
  String get uiStaticDeliveryBoundary => 'Static delivery boundary';

  @override
  String get uiAllDartCharsChars =>
      '本轮新增能力 all为纯 Dart 模型 + 应用内配置：不下载 chars体、不读文件 chars节、';

  @override
  String get uiBooksBooksPages =>
      '不发网络请求、不注 books平台回调、不写相 books。逐 pages接入多语言仍按用户指定预留到最后。';

  @override
  String get uiAppVersion => 'App version';

  @override
  String get uiEG1001 => 'e.g. 1.0.0+1';

  @override
  String get uiDevice => 'Device';

  @override
  String get uiEGPixel8 => 'e.g. Pixel 8';

  @override
  String get uiOsVersion => 'OS version';

  @override
  String get uiEGAndroid15 => 'e.g. Android 15';

  @override
  String get uiStepsToReproduce => 'Steps to reproduce';

  @override
  String get uiAdditionalNotesOptional => 'Additional notes (optional)';

  @override
  String get uiOtherObservations => 'Other observations';

  @override
  String get uiLocalBooks => 'Local books';

  @override
  String get uiFavorites => 'Favorites';

  @override
  String get uiMinutesToday => 'Minutes today';

  @override
  String get uiStreak => 'Streak';

  @override
  String get uiLibrary => 'Library';

  @override
  String get uiPureLocalMode => 'Pure-local mode';

  @override
  String get uiWhenOnTheAppMakesNoNetworkRequests =>
      'When on, the app makes no network requests';

  @override
  String get uiInterfaceMotion2 => 'Interface motion';

  @override
  String get uiPageTurnAnimationShelfParallaxGlassTransitions =>
      'Page-turn animation / shelf parallax / glass transitions';

  @override
  String get uiTtsReadAloud => 'TTS read-aloud';

  @override
  String get uiSentenceQueueRatePitchAutoNextChapter =>
      'Sentence queue · rate & pitch · auto next chapter';

  @override
  String get uiReadingLayout => 'Reading layout';

  @override
  String uiPtPages(String p0, String p1, String p2) {
    return '$p0 pt · $p1 · $p2翻 pages';
  }

  @override
  String uiContrast12(String p0) {
    return ' · contrast $p0:1';
  }

  @override
  String get uiPerBookLayoutFontsReportsBackupPermissions =>
      'Per-book layout · fonts · reports · backup · permissions';

  @override
  String get uiFormLoginBookcaseSessionSourceDomain =>
      'Form login · bookcase · session & source domain';

  @override
  String get uiOnlineDirectoryWenku8 => 'Online directory (Wenku8)';

  @override
  String get uiLockedByPureLocalMode => 'Locked by pure-local mode';

  @override
  String get uiListingsAndTocMetadataOnlyNoBundledNovels =>
      'Listings and TOC metadata only; no bundled novels';

  @override
  String get uiWebdavBackup => 'WebDAV backup';

  @override
  String get uiLibraryMetadataProgressGroupsSessions =>
      'Library metadata / progress / groups / sessions';

  @override
  String get uiPureLocalMode2 => '关闭Pure-local mode后，在线开关才会解锁；关闭态全应用零网络请求。';

  @override
  String get uiFormatsAuthorizationScanConflicts =>
      'Formats · authorization · scan · conflicts';

  @override
  String get uiImportFormats => 'Import formats';

  @override
  String uiItems8(String p0) {
    return '$p0 items';
  }

  @override
  String get uiRemovedBook => 'Removed book';

  @override
  String uiTapToOpen(String p0) {
    return '$p0 · · tap to open';
  }

  @override
  String get uiEpisodeList => 'Episode list';

  @override
  String uiEpisodesPages2(String p0, String p1) {
    return '$p0  episodes · $p1  pages';
  }

  @override
  String uiRecognitionRate(String p0) {
    return 'recognition rate $p0% · ';
  }

  @override
  String uiUnrecognizedPagesEpisodes(String p0) {
    return 'unrecognized的 $p0  pages已归入「未分 episodes」';
  }

  @override
  String get uiAllPagesAreGroupedIntoEpisodes =>
      'All pages are grouped into episodes';

  @override
  String get uiCurrent2 => 'Current';

  @override
  String get uiUnrecognized => 'Unrecognized';

  @override
  String uiPages2(String p0, String p1) {
    return '$p0 · $p1  pages';
  }

  @override
  String get uiCaptureThisPassage => 'Capture this passage';

  @override
  String uiLinesChars(String p0, String p1) {
    return '$p0  lines · $p1  chars';
  }

  @override
  String get uiNoTextAvailableToCapture => '(No text available to capture)';

  @override
  String get uiSpreads => ' ·  spreads段落';

  @override
  String get uiNoteOptional => 'Note (optional)';

  @override
  String get uiWriteSomethingToAppendToTheExcerpt =>
      'Write something to append to the excerpt';

  @override
  String get uiSpreadsLinesSentencesLines =>
      '选区 spreads越了段落，换 lines处已直接拼接；如需分 sentences可少选几 lines。';

  @override
  String get uiStatsPages => '这段已经摘过了，stats pages里可以看到。';

  @override
  String get uiSaveExcerpt => 'Save excerpt';

  @override
  String uiPagesCurrent(String p0) {
    return '本 pages需要原生渲染能力，current平台尚未接入。\n$p0';
  }

  @override
  String get uiDemoPlatform => 'Demo platform';

  @override
  String get uiCaptureSelectedLines => 'Capture selected lines';

  @override
  String get uiReadAloudSentenceQueue => 'Read aloud (sentence queue)';

  @override
  String get uiLayoutSettings => 'Layout settings';

  @override
  String get uiPreviousChapter => 'Previous chapter';

  @override
  String uiChapter(String p0, String p1, String p2, String p3) {
    return '$p0 / $p1 · Chapter $p2 / $p3';
  }

  @override
  String uiLinesSaveexcerpts(String p0) {
    return '已选 $p0  lines · 点顶栏书签saveexcerpts';
  }

  @override
  String get uiNextChapter => 'Next chapter';

  @override
  String get uiIllustrationPlaceholder => 'Illustration placeholder';

  @override
  String get uiPagesLinesexcerptsEpisodeListContents =>
      '漫画 pages暂不支持按 linesexcerpts，Episode list请用旁边「contents」按钮';

  @override
  String get uiSelectOneOrMoreLinesThenTapTheBookmarkToSaveAn =>
      'Select one or more lines, then tap the bookmark to save an excerpt';

  @override
  String get uiStatsPages2 => '这段已经摘过了，stats pages里可以看到';

  @override
  String get uiSavedToExcerptCardsSeeStats =>
      'Saved to excerpt cards · see Stats';

  @override
  String get uiFixedLayoutPage => 'Fixed-layout page';

  @override
  String get uiPdfEpubViaBookrenderbridge =>
      'PDF / 漫画 / 图片型 EPUB via BookRenderBridge：\n';

  @override
  String get uiRenderHandleIndexTargetsizePages4k =>
      '· render(handle, index, targetSize) 按目标像素出 pages，不做 4K 再缩\n';

  @override
  String get uiPagesTextureidTextureTextureid =>
      '· 连续翻 pages用 textureId + Texture(textureId:)\n';

  @override
  String get uiPagesImageMemory => '· 单 pages快照用编码位图 Image.memory\n';

  @override
  String get uiComicprefetchwindowPrefetchEvictSpreadsChannel =>
      '· ComicPrefetchWindow 批量 prefetch / evict，不在滚动回调里逐帧 spreads channel';

  @override
  String uiSize(String p0, String p1) {
    return '目标size：$p0 × $p1 逻辑像素';
  }

  @override
  String get uiTocNavigationIsNotWiredIntoThisPage =>
      'TOC navigation is not wired into this page';

  @override
  String get uiComicsFixedLayoutsHaveNoReflowableTextReadAlou =>
      'Comics / fixed layouts have no reflowable text; read-aloud is for novels only';

  @override
  String uiSentencesSentences(String p0, String p1) {
    return '已暂停在第 $p0 / $p1  sentences；再次点击从该 sentences续播';
  }

  @override
  String uiSentences(String p0, String p1, String p2, String p3) {
    return '$p0 · 从第 $p1 / $p2  sentences开始 · $p3×';
  }

  @override
  String get uiFinishedTheWholeBook => 'Finished the whole book';

  @override
  String get uiResetToDefault => 'Reset to default';

  @override
  String get uiBodyText => 'Body text';

  @override
  String get uiFontSize => 'Font size';

  @override
  String get uiLineHeight2 => 'Line height';

  @override
  String get uiFirstLineIndent => 'First-line indent';

  @override
  String get uiParagraphSpacing => 'Paragraph spacing';

  @override
  String get uiReadingBackground => 'Reading background';

  @override
  String get uiBodyTextCharsCurrentcontrast =>
      'body text与面板文 chars色由背景亮度自动反推 · currentcontrast ';

  @override
  String uiWcagAaBodyText452(String p0) {
    return '$p0 : 1（WCAG AA body text ≥ 4.5）';
  }

  @override
  String get uiPageTurnMotion => 'Page turn & motion';

  @override
  String get uiChooseSlideSimulatedPageTurnWhenEnabled =>
      'Choose slide / simulated page turn when enabled';

  @override
  String get uiMotionIsOffSoPageTurnIsLockedToNone =>
      'Motion is off, so page turn is locked to none';

  @override
  String get uiNormalizationIsCentralizedInAppsettingsNormali =>
      'Normalization is centralized in AppSettings.normalized()：';

  @override
  String get uiTurningMotionOffLocksPageTurnToNonePagesNeverR =>
      'Turning motion off locks page turn to none; pages never reinterpret this rule.';

  @override
  String get uiComicReading => 'Comic reading';

  @override
  String get uiReadAloud2 => 'Read aloud';

  @override
  String get uiRate => 'Rate';

  @override
  String get uiPitch => 'Pitch';

  @override
  String get uiSentenceQueueAutoNextChapter =>
      'Sentence queue · auto next chapter';

  @override
  String get uiReadingAidsPlatformCapability =>
      'Reading aids (platform capability)';

  @override
  String get uiKeepScreenOn => 'Keep screen on';

  @override
  String get uiItems9 => '静态交付模式下，以上两 items只记录偏好，需三端原生能力才能生效（❄️ 冻结）。';

  @override
  String get uiSaveSettingsstore =>
      '修改仅save在内存，重启后恢复默认。接入持久化后由 SettingsStore 统一落库。';

  @override
  String get uiWeak => 'Weak';

  @override
  String get uiMedium => 'Medium';

  @override
  String get uiStrong => 'Strong';

  @override
  String get uiComics => 'Comics';

  @override
  String uiSpread(String p0, String p1) {
    return 'Spread $p0 / $p1';
  }

  @override
  String uiPhrase317(String p0) {
    return '$p0';
  }

  @override
  String get uiSwitchToHorizontalPaging => 'Switch to horizontal paging';

  @override
  String get uiSwitchToVerticalScroll => 'Switch to vertical scroll';

  @override
  String uiSpreadsPages(String p0) {
    return ' spreads pages模式：$p0';
  }

  @override
  String uiPages3(String p0) {
    return '翻 pages方向：$p0';
  }

  @override
  String uiPAspectRatioPlaceholder(String p0, String p1) {
    return 'P$p0 · aspect ratio $p1 placeholder';
  }

  @override
  String uiVolumes(String p0, String p1) {
    return '$p0 · $p1  volumes';
  }

  @override
  String get uiSearchLocalLibrary => 'Search local library';

  @override
  String get uiTitleAuthorFormatGroup => 'Title / author / format / group';

  @override
  String uiAllBooks3(String p0) {
    return 'All $p0 books';
  }

  @override
  String uiFoundBooks(String p0, String p1) {
    return 'Found $p0 books · \"$p1\"';
  }

  @override
  String uiBooks2(String p0) {
    return '$p0 books';
  }

  @override
  String uiVolumes2(String p0) {
    return ' · 第 $p0  volumes';
  }

  @override
  String get uiHowImportingWorks => 'How importing works';

  @override
  String get uiClearKeyword => 'Clear keyword';

  @override
  String get uiShelf2 => 'Shelf';

  @override
  String get uiKeepWhatYouWantToReadWithinReach =>
      'Keep what you want to read within reach';

  @override
  String uiTotalBooksBooks(String p0, String p1) {
    return '—  total $p0  books · 收藏 $p1  books · ';
  }

  @override
  String uiItemsgroupVolumeOrder(String p0) {
    return '$p0  itemsgroup · 按volume order';
  }

  @override
  String get uiSearchTitleAuthor => 'Search title / author';

  @override
  String get uiViewAllResults => 'View all results';

  @override
  String uiBooks3(String p0) {
    return '只看已收藏的 $p0  books';
  }

  @override
  String get uiTapTheStarOnTheDetailOrReaderPageToFavorite =>
      'Tap the star on the detail or reader page to favorite';

  @override
  String get uiSearchNavigationIsNotWiredIntoThisPage =>
      'Search navigation is not wired into this page';

  @override
  String get uiDetailNavigationIsNotWiredIntoThisPage =>
      'Detail navigation is not wired into this page';

  @override
  String get uiImportEntryIsNotWiredIntoThisPage =>
      'Import entry is not wired into this page';

  @override
  String get uiVisualStyle => 'Visual style';

  @override
  String uiTotalBooksVolumeOrder(String p0) {
    return 'total $p0  books · 按volume order';
  }

  @override
  String uiVolume3(String p0) {
    return 'Volume $p0';
  }

  @override
  String get uiViewAllBooks => 'View all books';

  @override
  String get uiPreviousMonth => 'Previous month';

  @override
  String get uiNextMonth => 'Next month';

  @override
  String get uiThisMonth2 => 'This month';

  @override
  String get uiReadingDays => 'Reading days';

  @override
  String uiDays2(String p0) {
    return '$p0 days';
  }

  @override
  String get uiKeepsakes => 'Keepsakes';

  @override
  String uiKeepsakes2(String p0) {
    return '$p0 keepsakes';
  }

  @override
  String get uiExcerpts => 'Excerpts';

  @override
  String uiItems10(String p0) {
    return '$p0 items';
  }

  @override
  String get uiLow => 'Low';

  @override
  String get uiHigh => 'High';

  @override
  String get uiAdjacentMonthCells => 'Adjacent-month cells';

  @override
  String get uiKeepsakesThatDay => 'Keepsakes that day';

  @override
  String get uiExcerptsThatDay => 'Excerpts that day';

  @override
  String get uiPreviousKeepsake => 'Previous keepsake';

  @override
  String get uiNextKeepsake => 'Next keepsake';

  @override
  String get uiYours2 => 'Yours';

  @override
  String get uiTitleNoteTypeBook => 'Title / note / type / book';

  @override
  String get uiType => 'Type';

  @override
  String get uiMonth => 'Month';

  @override
  String uiTotalKeepsakesItems(String p0, String p1) {
    return 'total $p0  keepsakes · $p1  items月 · ';
  }

  @override
  String uiKeepsakesKeepsakes(String p0, String p1) {
    return '来自你摘的 $p0  keepsakes · 命中 $p1  keepsakes';
  }

  @override
  String uiKeepsakes3(String p0, String p1) {
    return '$p0 · $p1  keepsakes';
  }

  @override
  String get uiReadingStats => 'Reading stats';

  @override
  String get uiWidgets => 'Widgets';

  @override
  String get uiTurnReadingTimeIntoPagesYouCanFlipBackThrough =>
      'Turn reading time into pages you can flip back through';

  @override
  String uiGoalminutesMinutes(String p0) {
    return '今日阅读 · 目标 $p0.goalMinutes  minutes';
  }

  @override
  String get uiMinutes2 => 'minutes';

  @override
  String uiDaysThisWeek(String p0, String p1) {
    return '连续 $p0  days ·  this week $p1 · ';
  }

  @override
  String uiBooksExcerptsItems(String p0, String p1) {
    return '书库 $p0  books · excerpts $p1  items';
  }

  @override
  String uiContinueReading2(String p0) {
    return 'Continue reading《$p0》';
  }

  @override
  String get uiReadingHeatmap => 'Reading heatmap';

  @override
  String uiDays3(String p0) {
    return '近 5 周 · $p0  days';
  }

  @override
  String get uiReadingCalendar => 'Reading calendar';

  @override
  String get uiExcerpts2 => 'Excerpts';

  @override
  String uiTotalItemsItems(String p0, String p1) {
    return 'total $p0  items · 你摘的 $p1  items';
  }

  @override
  String get uiManage => 'Manage';

  @override
  String get uiNoExcerptsYetSelectAFewLinesInTheReaderToStart =>
      'No excerpts yet. Select a few lines in the reader to start.';

  @override
  String get uiSampleData => 'Sample data';

  @override
  String get uiPrevious => 'Previous';

  @override
  String get uiNextExcerpt => 'Next excerpt';

  @override
  String get uiDeleteThisExcerpt => 'Delete this excerpt';

  @override
  String uiItemswidgets(String p0) {
    return '已配置 $p0  itemswidgets';
  }

  @override
  String uiMinutes3(String p0, String p1) {
    return '$p0 · $p1  minutes';
  }

  @override
  String get uiWidgets2 => 'widgets配置';

  @override
  String uiTotalItemsItemsItems(String p0) {
    return 'total $p0  items · 可同时放置多 items · 每 items独立配置';
  }

  @override
  String get uiDarkPreview => 'Dark preview';

  @override
  String get uiLightPreview => 'Light preview';

  @override
  String get uiAddAWidget => 'Add a widget';

  @override
  String get uiAboutDesktopWidgets => 'About desktop widgets';

  @override
  String get uiSaveWidgetsFlutter =>
      '本面板只save应用内配置与预览。桌面widgets本体不是 Flutter 能绘制的：';

  @override
  String get uiAndroidUsesInAppConfigIosUsesWidgetkitEditCont =>
      'Android uses in-app config, iOS uses WidgetKit edit controls, HarmonyOS uses card config,';

  @override
  String get uiAllThreePlatformsNeedNativeImplementationsRead =>
      'All three platforms need native implementations reading the serialized data here.';

  @override
  String get uiShowProgress => ' · show progress';

  @override
  String get uiContent2 => 'Content';

  @override
  String get uiKeepsakeTypePerWidget => 'Keepsake type (per widget)';

  @override
  String get uiSize2 => 'Size';

  @override
  String get uiSeasonStyleIndependentOfAppTheme =>
      'Season style (independent of app theme)';

  @override
  String get uiShowProgress2 => 'Show progress';

  @override
  String get uiRemove2 => 'Remove';

  @override
  String get uiThisMonthKeepsakePreview => 'This month keepsake preview';

  @override
  String get uiOnlineDirectoryIsOffNoRequestWasMade =>
      'Online directory is off; no request was made.';

  @override
  String uiItemsShelfBooks(String p0, String p1) {
    return ' items人shelf：$p0  books · $p1';
  }

  @override
  String get uiSourceDomain => 'Source domain';

  @override
  String get uiPleaseWait => 'Please wait…';

  @override
  String get uiReadPersonalBookcase => 'Read personal bookcase';

  @override
  String get uiWorking => 'Working…';

  @override
  String get uiSignedInLaterRequestsCarryTheSessionCookieIssu =>
      'Signed in; later requests carry the session cookie issued by the source.';

  @override
  String get uiOnlineDirectoryAndLocalLibraryStayIndependent =>
      'Online directory and local library stay independent';

  @override
  String get uiEnableOnlineDirectoryWenku8 =>
      'Enable online directory (Wenku8)';

  @override
  String get uiPureLocalModeIsOnTheAppMakesNoNetworkRequests =>
      'Pure-local mode is on; the app makes no network requests.';

  @override
  String get uiTurnOffPureLocalModeOnTheProfilePageFirst =>
      'Turn off pure-local mode on the Profile page first.';

  @override
  String get uiWhenOffTheAppStaysFullyLocalAndMakesNoNetworkR =>
      'When off the app stays fully local and makes no network requests.';

  @override
  String get uiWhenOnOnlyWenku8ListingsAndTocMetadataAreRead =>
      'When on, only Wenku8 listings and TOC metadata are read.';

  @override
  String get uiItemsShelfSource => '表单登录 ·  items人shelf · source域名切换';

  @override
  String get uiImportIntoLocalLibrary => 'Import into local library';

  @override
  String get uiTxtEpubCbzPdfImageFolders =>
      'TXT / EPUB / CBZ / PDF / image folders';

  @override
  String get uiSampleWorkTocPreview => 'Sample work · TOC preview';

  @override
  String get uiSampleData2 => 'Sample data';

  @override
  String get uiSampleWorkVolumeList => 'Sample work · volume list';

  @override
  String get uiSampleWorkDetail => 'Sample work · detail';

  @override
  String get uiMetadata => 'Metadata';

  @override
  String get uiAboutContentAndSources => 'About content and sources';

  @override
  String get uiBookOverride => 'book override';

  @override
  String get uiGlobalDefault => 'global default';

  @override
  String get uiMeetsMinimum => 'meets';

  @override
  String get uiBelowMinimum => 'below';

  @override
  String get uiNoVoiceSkipped => ' (no voice, skipped)';

  @override
  String get uiNoDataOmitted => ' (no data, all omitted)';

  @override
  String get uiAligned => ' (aligned)';

  @override
  String get uiMisaligned => ' (misaligned)';

  @override
  String get uiEnabled => 'On';

  @override
  String get uiDisabled => 'Off';

  @override
  String get uiLightInnerHighlight => 'light inner highlight';

  @override
  String get uiBlackShadow => 'black shadow';

  @override
  String get uiSpecialEpisode => 'special';

  @override
  String get uiSpine => 'spine';

  @override
  String get uiWideSolo => 'wide solo';

  @override
  String uiPhrase000(String p0) {
    return '多：$p0';
  }

  @override
  String uiPhrase001(String p0) {
    return '缺：$p0';
  }

  @override
  String uiSampleDataN1(String p0) {
    return '$p0 · Sample data';
  }

  @override
  String uiPhrase003(String p0) {
    return '$p0';
  }

  @override
  String uiCurrentContents(String p0) {
    return '$p0 · current在线contents：';
  }

  @override
  String uiPhrase005(String p0, String p1) {
    return '$p0\n关键词：「$p1」';
  }

  @override
  String uiCurrentN1(String p0, String p1) {
    return '$p0\ncurrent关键词：「$p1」';
  }

  @override
  String uiPhrase007(String p0) {
    return '$p0';
  }

  @override
  String uiAboutParagraphsItems(String p0) {
    return ' · about paragraphs $p0  items';
  }

  @override
  String uiShade(String p0, String p1) {
    return 'shade $p0 · $p1';
  }

  @override
  String uiPhrase010(String p0) {
    return '$p0';
  }

  @override
  String uiPhrase011(String p0) {
    return '$p0';
  }

  @override
  String uiPhrase012(String p0) {
    return '$p0';
  }

  @override
  String uiPhrase013(String p0) {
    return '$p0';
  }

  @override
  String uiKeepsakesN1(String p0, String p1) {
    return '$p0  keepsakes$p1';
  }

  @override
  String uiDaysTotalPages(String p0, String p1) {
    return '近 7  days · total $p0  pages · $p1';
  }

  @override
  String uiItemsN1(String p0, String p1, String p2) {
    return '$p0 · 《$p1》 · $p2  items';
  }

  @override
  String uiPhrase017(String p0) {
    return '$p0';
  }

  @override
  String uiChaptersN1(String p0, String p1) {
    return '$p0  chapters · $p1';
  }

  @override
  String uiBooksN1(String p0, String p1) {
    return '已写入 $p0  books$p1';
  }

  @override
  String uiVolumesChapters(String p0, String p1, String p2) {
    return '$p0 · $p1  volumes / $p2  chapters';
  }

  @override
  String uiPhrase021(String p0) {
    return '$p0';
  }

  @override
  String uiExcerptCaptureSource(String p0, String p1, String p2) {
    return '《$p0》· $p1$p2';
  }

  @override
  String uiBookMetaLine(String p0, String p1, String p2) {
    return '$p0 · $p1$p2';
  }

  @override
  String uiWidgetSpecLine(String p0, String p1, String p2, String p3) {
    return '$p0 · $p1$p2$p3';
  }

  @override
  String uiVolumeN(String p0) {
    return 'Volume $p0';
  }

  @override
  String uiVolumePrefixN(String p0) {
    return ' · Volume $p0';
  }

  @override
  String uiDeferredN(String p0) {
    return ' · $p0 deferred';
  }

  @override
  String get uiSpecialEpisodePrefix => ' · Special';

  @override
  String uiWideSoloN(String p0) {
    return ' · $p0 wide spreads';
  }

  @override
  String uiSpineN(String p0) {
    return ' · $p0 spines';
  }

  @override
  String get uiSimplifiedChinese => 'Simplified Chinese';

  @override
  String get uiArbSourceNote =>
      'Source: lib/l10n/app_zh.arb and app_en.arb. Edit only these two files, then run tool/sync_arb.py.';

  @override
  String uiArbStats(String p0, String p1, String p2) {
    return '$p0 keys · $p1 templates · $p2 to review';
  }
}
