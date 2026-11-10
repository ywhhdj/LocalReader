import 'package:flutter/material.dart';

import '../../../core/model/webdav_backup.dart';
import '../../../domain/repositories/book_repository.dart';
import '../../../core/model/shelf_prefs.dart';
import '../../../domain/usecases/import_review.dart';
import '../../../core/model/android_permissions.dart';
import '../../../crash_guard.dart';
import '../../../core/model/bilingual_prefs.dart';
import '../../../assembly/app_scope.dart';
import '../../../core/model/font_catalog.dart';
import '../../../core/model/per_book_style.dart';
import '../../../core/model/reader_motion.dart';
import '../../../core/model/stats/stats_views.dart';
import '../../../core/ui/theme/color_source.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/components/glass.dart';
import '../../../l10n/lr_localizations.dart';

/// 功能总览
class FeatureMatrixPage extends StatefulWidget {
  const FeatureMatrixPage({super.key, this.initialTab = 0});

  /// 由 `FeatureMatrixArgs.normalizedTab` 传入，便于以后从别处直达某个分组。
  final int initialTab;

  @override
  State<FeatureMatrixPage> createState() => _FeatureMatrixPageState();
}

class _FeatureMatrixPageState extends State<FeatureMatrixPage> {
  late int _tab = widget.initialTab;
  String? _bookId;

  // 导入前审阅是一次性交互，属局部 UI 状态；跨页设置仍全部走 AppState。
  VolumeMergePolicy _policy = VolumeMergePolicy.askEach;
  ImportSourceKind _importSource = ImportSourceKind.multipleFiles;

  static List<String> get _tabs => <String>[
    lrText('uiReadingFonts'), lrText('uiMotionReadAloud'), lrText('uiStatsReports'), lrText('uiShelfImport'), lrText('uiBuildCompliance'),
  ];

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<BookSummary> books = state.allBooks;
    final String bookId = _bookId ?? (books.isEmpty ? '' : books.first.id);

    return Scaffold(
      appBar: AppBar(title: Text(context.t('uiFeatureOverview'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(LrSpacing.l, LrSpacing.m, LrSpacing.l, 96),
        children: <Widget>[
          Text(context.t('uiReferenceRepoFeatureAlignment'), style: text.headlineSmall),
          const SizedBox(height: LrSpacing.xs),
          Text(
            context.t('uiAllGlobalDefaultStaticStageSaveChars'),
            style: text.bodySmall,
          ),
          const SizedBox(height: LrSpacing.m),
          Wrap(
            spacing: LrSpacing.s,
            children: <Widget>[
              for (int i = 0; i < _tabs.length; i++)
                ChoiceChip(
                  label: Text(_tabs[i]),
                  selected: _tab == i,
                  onSelected: (_) => setState(() => _tab = i),
                ),
            ],
          ),
          const SizedBox(height: LrSpacing.m),
          GlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(LrSpacing.m),
              child: <Widget>[
                _readingPane(context, state, books, bookId),
                _motionPane(context, state),
                _reportPane(context, state),
                _shelfPane(context, state),
                _engineeringPane(context),
              ][_tab],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- ① 阅读与字体
  Widget _readingPane(BuildContext context, AppState state,
      List<BookSummary> books, String bookId) {
    final TextTheme text = Theme.of(context).textTheme;
    final EffectiveReaderStyle effective = state.effectiveReaderStyleFor(bookId);
    final PerBookStyle override = state.perBookStyles[bookId] ?? PerBookStyle.empty;
    final FontCatalog fonts = state.fontCatalog;
    final ColorSource colors = state.colorSource;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _title(text, lrText('uiPerBookLayout')),
        Text(
          lrText('uiSaveCharsFontSizeCharsCharsLineHeightNullGloba'),
          style: text.bodySmall,
        ),
        const SizedBox(height: LrSpacing.s),
        DropdownButton<String>(
          isExpanded: true,
          value: books.any((BookSummary b) => b.id == bookId) ? bookId : null,
          hint: Text(lrText('uiLibraryIsEmpty')),
          items: <DropdownMenuItem<String>>[
            for (final BookSummary b in books)
              DropdownMenuItem<String>(value: b.id, child: Text(b.title)),
          ],
          onChanged: (String? v) => setState(() => _bookId = v),
        ),
        const SizedBox(height: LrSpacing.s),
        Text(
          lrTextArgs('uiCurrentPt', <Object?>[effective.fontFamily, effective.fontSize.toStringAsFixed(1)]) +
          lrTextArgs('uiLineHeight', <Object?>[effective.lineHeight.toStringAsFixed(2)]) +
          lrTextArgs('uiPhrase141', <Object?>[effective.isBookSpecific ? lrText('uiBookOverride') : lrText('uiGlobalDefault')]),
          style: text.bodyMedium,
        ),
        const SizedBox(height: LrSpacing.s),
        Wrap(
          spacing: LrSpacing.s,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: books.isEmpty
                  ? null
                  : () => state.updatePerBookStyle(
                        bookId,
                        override.withOverrides(fontSize: 20.0, lineHeight: 1.8),
                      ),
              child: Text(lrText('uiUseLargerTextForThisBook')),
            ),
            OutlinedButton(
              onPressed: override.isEmpty
                  ? null
                  : () => state.clearPerBookStyle(bookId),
              child: Text(lrText('uiClearPerBookOverrides')),
            ),
          ],
        ),
        const Divider(height: 28),
        _title(text, lrText('uiFontCatalog')),
        Text(
          lrText('uiCharsRemoveCharsChars'),
          style: text.bodySmall,
        ),
        const SizedBox(height: LrSpacing.s),
        for (final FontRole role in FontRole.values)
          _fontRoleRow(context, state, fonts, role),
        const SizedBox(height: LrSpacing.s),
        Wrap(
          spacing: LrSpacing.s,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: () => state.updateFontCatalog(
                    fonts.addImported(lrText('uiImportFontSourceHanSans'), <String>['otf']),
                  ),
              child: Text(lrText('uiRegisterImportedTtfOtf')),
            ),
            OutlinedButton(
              onPressed: () => state.updateFontCatalog(
                    fonts.withState('dl-serif-sc', FontInstallState.installed),
                  ),
              child: Text(lrText('uiMarkOnDemandPackInstalled')),
            ),
          ],
        ),
        Text(
          lrText('uiStaticStageFontloaderBooksRemove'),
          style: text.bodySmall,
        ),
        const Divider(height: 28),
        _title(text, lrText('uiColorSource')),
        for (final ColorSourceKind k in ColorSourceKind.values)
          RadioListTile<ColorSourceKind>(
            contentPadding: EdgeInsets.zero,
            value: k,
            groupValue: colors.kind,
            title: Text(_colorLabel(k)),
            onChanged: (ColorSourceKind? v) =>
                state.updateColorSource(colors.copyWith(kind: v)),
          ),
        const SizedBox(height: LrSpacing.s),
        Builder(builder: (BuildContext context) {
          final ReaderColorScheme scheme = ReaderColorScheme.derive(
            state.settings.reader.backgroundColor,
          );
          return Text(
            context.tArgs('uiContrast1', <Object?>[scheme.contrast.toStringAsFixed(2)]) +
            context.tArgs('uiWcagAaBodyText45', <Object?>[scheme.meetsMinimum ? lrText('uiMeetsMinimum') : lrText('uiBelowMinimum')]),
            style: text.bodySmall,
          );
        }),
      ],
    );
  }

  Widget _fontRoleRow(
      BuildContext context, AppState state, FontCatalog fonts, FontRole role) {
    final String current = fonts.selection.forRole(role);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 84,
          child: Text(role == FontRole.app ? context.t('uiAppFont') : context.t('uiReadingFont')),
        ),
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            value: fonts.byId(current) == null ? 'builtin-sans' : current,
            items: <DropdownMenuItem<String>>[
              for (final FontResource f in fonts.selectable(role))
                DropdownMenuItem<String>(value: f.id, child: Text(f.name)),
            ],
            onChanged: (String? v) => v == null
                ? null
                : state.updateFontCatalog(
                    fonts.withSelection(fonts.selection.withRole(role, v)),
                  ),
          ),
        ),
        IconButton(
          tooltip: context.t('uiRemoveCurrentFont'),
          onPressed: () => state.updateFontCatalog(fonts.remove(current)),
          icon: const Icon(Icons.delete_outline, size: 18),
        ),
      ],
    );
  }

  String _colorLabel(ColorSourceKind k) {
    switch (k) {
      case ColorSourceKind.systemDynamic:
        return lrText('uiSystemDynamicColorMonet');
      case ColorSourceKind.customAccent:
        return lrText('uiCustomAccentColor');
      case ColorSourceKind.fromCover:
        return lrText('uiPickFromCover');
    }
  }

  // ---------------------------------------------------------------- ② 动效与朗读
  Widget _motionPane(BuildContext context, AppState state) {
    final TextTheme text = Theme.of(context).textTheme;
    final ReaderMotion m = state.readerMotion;
    final BilingualPrefs b = state.bilingual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _title(text, context.t('uiPageTurnAutoRead')),
        DropdownButton<ReaderTransition>(
          isExpanded: true,
          value: m.normalized().transition,
          items: <DropdownMenuItem<ReaderTransition>>[
            for (final ReaderTransition t in ReaderTransition.values)
              DropdownMenuItem<ReaderTransition>(
                  value: t, child: Text(ReaderMotion.labels[t]!)),
          ],
          onChanged: (ReaderTransition? v) =>
              state.updateReaderMotion(m.copyWith(transition: v)),
        ),
        const SizedBox(height: LrSpacing.s),
        Text(context.tArgs('uiPages', <Object?>[m.turnSpeed.toStringAsFixed(1)]), style: text.bodySmall),
        Slider(
          value: m.turnSpeed.clamp(0.5, 2.0).toDouble(),
          min: 0.5,
          max: 2.0,
          divisions: 6,
          onChanged: (double v) => state.updateReaderMotion(m.copyWith(turnSpeed: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('uiInterfaceMotion')),
          subtitle: Text(m.globalMotion ? context.t('uiOn') : context.t('uiOffLocksToNoAnimationAndStopsAutoRead')),
          value: m.globalMotion,
          onChanged: (bool v) => state.updateReaderMotion(m.copyWith(globalMotion: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('uiAutoRead')),
          subtitle: Text(context.tArgs('uiIntervalMsAutoStopsWhenMotionIsOff', <Object?>[m.autoReadIntervalMs])),
          value: m.isAutoReading,
          onChanged: (bool v) => state.updateReaderMotion(m.copyWith(autoRead: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('uiContinuousChapterTransition')),
          value: m.continuousChapter,
          onChanged: (bool v) =>
              state.updateReaderMotion(m.copyWith(continuousChapter: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('uiVolumeKeyPaging')),
          value: m.volumeKeyTurnPage,
          onChanged: (bool v) =>
              state.updateReaderMotion(m.copyWith(volumeKeyTurnPage: v)),
        ),
        const Divider(height: 28),
        _title(text, context.t('uiBilingualReadAloudLanguages')),
        Text(
          context.t('uiReadAloudLanguagesItemsVoice'),
          style: text.bodySmall,
        ),
        const SizedBox(height: LrSpacing.s),
        DropdownButton<ReadingLanguage>(
          isExpanded: true,
          value: b.displayLanguage,
          items: <DropdownMenuItem<ReadingLanguage>>[
            for (final ReadingLanguage l in ReadingLanguage.values)
              DropdownMenuItem<ReadingLanguage>(
                  value: l, child: Text(BilingualPrefs.labels[l]!)),
          ],
          onChanged: (ReadingLanguage? v) =>
              state.updateBilingual(b.copyWith(displayLanguage: v)),
        ),
        const SizedBox(height: LrSpacing.s),
        Text(
          context.tArgs('uiReadAloud', <Object?>[b.speakable().map((ReadingLanguage l) => BilingualPrefs.labels[l]).join("、")]) +
          lrTextArgs('uiPhrase171', <Object?>[b.speakable().isEmpty ? lrText('uiNoVoiceSkipped') : ""]),
          style: text.bodySmall,
        ),
        Text(
          context.t('uiStaticStageKeepsakes'),
          style: text.bodySmall,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- ③ 统计与报告
  Widget _reportPane(BuildContext context, AppState state) {
    final TextTheme text = Theme.of(context).textTheme;
    final ReportPayload payload = state.reportPayload;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _title(text, context.t('uiFiveViews')),
        Wrap(
          spacing: LrSpacing.s,
          children: <Widget>[
            for (final StatsViewKind v in StatsViewKind.values)
              ChoiceChip(
                label: Text(ReportPayload.viewLabels[v]!),
                selected: state.statsView == v,
                onSelected: (_) => state.updateStatsView(v),
              ),
          ],
        ),
        const SizedBox(height: LrSpacing.m),
        _title(text, context.t('uiPeriodPresetsCustomRange')),
        Wrap(
          spacing: LrSpacing.s,
          children: <Widget>[
            for (final StatsPeriodKind k in StatsPeriodKind.values)
              ChoiceChip(
                label: Text(_periodLabel(k)),
                selected: state.statsPeriod.kind == k,
                onSelected: (_) => state.updateStatsPeriod(StatsPeriod(kind: k)),
              ),
          ],
        ),
        const Divider(height: 28),
        _title(text, context.t('uiEightReportLayouts')),
        Wrap(
          spacing: LrSpacing.s,
          children: <Widget>[
            for (final ReportLayout l in ReportLayout.values)
              ChoiceChip(
                label: Text(ReportPayload.layoutLabels[l]!),
                selected: state.reportLayout == l,
                onSelected: (_) => state.updateReportLayout(l),
              ),
          ],
        ),
        const SizedBox(height: LrSpacing.m),
        Text(
          context.tArgs('uiChars', <Object?>[payload.sections.map((ReportSection s) => ReportPayload.sectionLabels[s]).join("、")]) +
          lrTextArgs('uiPhrase177', <Object?>[payload.sections.isEmpty ? lrText('uiNoDataOmitted') : ""]),
          style: text.bodySmall,
        ),
        const SizedBox(height: LrSpacing.s),
        Text(context.t('uiTotalContent'), style: text.bodySmall),
        const SizedBox(height: 4),
        SelectableText(payload.render(), style: text.bodySmall),
        Text(
          context.t('uiStaticStageChars'),
          style: text.bodySmall,
        ),
      ],
    );
  }

  String _periodLabel(StatsPeriodKind k) {
    switch (k) {
      case StatsPeriodKind.today:
        return lrText('uiToday');
      case StatsPeriodKind.week:
        return lrText('uiThisWeek');
      case StatsPeriodKind.month:
        return lrText('uiThisMonth');
      case StatsPeriodKind.year:
        return lrText('uiThisYear');
      case StatsPeriodKind.all:
        return lrText('uiAll2');
      case StatsPeriodKind.custom:
        return lrText('uiCustom');
    }
  }

  // ---------------------------------------------------------------- ④ 书架与导入
  Widget _shelfPane(BuildContext context, AppState state) {
    final TextTheme text = Theme.of(context).textTheme;
    final ShelfPrefs prefs = state.shelfPrefs;
    final BackupSnapshot backup = state.backup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _title(text, context.t('uiShelfViewFilters')),
        Wrap(
          spacing: LrSpacing.s,
          children: <Widget>[
            for (final ShelfViewMode m in ShelfViewMode.values)
              ChoiceChip(
                label: Text(ShelfPrefs.modeLabels[m]!),
                selected: prefs.mode == m,
                onSelected: (_) => state.updateShelfPrefs(prefs.copyWith(mode: m)),
              ),
          ],
        ),
        const SizedBox(height: LrSpacing.s),
        Wrap(
          spacing: LrSpacing.s,
          children: <Widget>[
            DropdownButton<ReadingStatusFilter>(
              value: prefs.status,
              items: <DropdownMenuItem<ReadingStatusFilter>>[
                for (final ReadingStatusFilter s in ReadingStatusFilter.values)
                  DropdownMenuItem<ReadingStatusFilter>(
                      value: s, child: Text(ShelfPrefs.statusLabels[s]!)),
              ],
              onChanged: (ReadingStatusFilter? v) =>
                  state.updateShelfPrefs(prefs.copyWith(status: v)),
            ),
            DropdownButton<BookSourceFilter>(
              value: prefs.source,
              items: <DropdownMenuItem<BookSourceFilter>>[
                for (final BookSourceFilter s in BookSourceFilter.values)
                  DropdownMenuItem<BookSourceFilter>(
                      value: s, child: Text(ShelfPrefs.sourceLabels[s]!)),
              ],
              onChanged: (BookSourceFilter? v) =>
                  state.updateShelfPrefs(prefs.copyWith(source: v)),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('uiMergeLocalLibraryIntoShelf')),
          value: prefs.mergeLocalIntoShelf,
          onChanged: (bool v) =>
              state.updateShelfPrefs(prefs.copyWith(mergeLocalIntoShelf: v)),
        ),
        Text(
          context.tArgs('uiCurrentBooks', <Object?>[prefs.apply(state.allBooks).length, state.allBooks.length]) +
          context.t('uiCarouselParametersLockBackToDefaultInListMode'),
          style: text.bodySmall,
        ),
        const Divider(height: 28),
        _title(text, context.t('uiPreImportReviewSeriesVolumeMerge')),
        Text(
          context.tArgs('uiSource2', <Object?>[ImportReview.sourceLabels.values.join(" / ")]) +
          context.tArgs('uiPolicy', <Object?>[ImportReview.policyLabels.values.join(" / ")]),
          style: text.bodySmall,
        ),
        const SizedBox(height: LrSpacing.s),
        Wrap(
          spacing: LrSpacing.s,
          children: <Widget>[
            for (final ImportSourceKind k in ImportSourceKind.values)
              ChoiceChip(
                label: Text(ImportReview.sourceLabels[k]!),
                selected: _importSource == k,
                onSelected: (_) => setState(() => _importSource = k),
              ),
          ],
        ),
        const SizedBox(height: LrSpacing.s),
        Wrap(
          spacing: LrSpacing.s,
          children: <Widget>[
            for (final VolumeMergePolicy p in VolumeMergePolicy.values)
              ChoiceChip(
                label: Text(ImportReview.policyLabels[p]!),
                selected: _policy == p,
                onSelected: (_) => setState(() => _policy = p),
              ),
          ],
        ),
        const SizedBox(height: LrSpacing.s),
        Text(
          context.tArgs('uiCurrent', <Object?>[ImportReview.sourceLabels[_importSource]]) +
          context.tArgs('uiPhrase194', <Object?>[ImportReview.policyLabels[_policy]]) +
          context.tArgs('uiItems7', <Object?>[const ImportReview().withPolicy(VolumeMergePolicy.mergeBySeries).resolution.name]),
          style: text.bodySmall,
        ),
        const Divider(height: 28),
        _title(text, context.t('uiWebdavBackupOffByDefault')),
        Text(
          context.tArgs('uiContent', <Object?>[BackupSnapshot.payloadLabels.join(" / ")]) +
          context.t('uiWhenOffEvenTestConnectionMakesNoRequest'),
          style: text.bodySmall,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('uiEnableBackup')),
          value: backup.enabled,
          onChanged: (bool v) => state.updateBackup(backup.setEnabled(v)),
        ),
        Wrap(
          spacing: LrSpacing.s,
          children: <Widget>[
            for (final BackupAction a in BackupSnapshot.actions)
              OutlinedButton(
                onPressed: !backup.enabled
                    ? null
                    : () => state.updateBackup(backup
                        .dispatch(a)
                        .finish(ok: true, note: context.t('uiStaticDemoNoNetworkRequestWasMade'))),
                child: Text(BackupSnapshot.actionLabels[a]!),
              ),
          ],
        ),
        Text(
          context.t('uiStaticStageWebdavclient'),
          style: text.bodySmall,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- ⑤ 工程与合规
  Widget _engineeringPane(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    const AndroidPermissionProfile p33 = AndroidPermissionProfile(33);
    const AndroidPermissionProfile p31 = AndroidPermissionProfile(31);
    const CrashGuard guard = CrashGuard();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _title(text, context.t('uiAndroidPermissionTiers')),
        Text('13+：${p33.requiredPermissions().join(", ")}', style: text.bodySmall),
        Text('12-：${p31.requiredPermissions().join(", ")}', style: text.bodySmall),
        Text(context.tArgs('uiRemove', <Object?>[AndroidPermissionProfile.removed.join(", ")]),
            style: text.bodySmall),
        Text(AndroidPermissionProfile.safNote, style: text.bodySmall),
        const Divider(height: 28),
        _title(text, context.t('uiCrashLoopProtection')),
        Text(
          context.tArgs('uiMinutes', <Object?>[guard.policy.threshold, guard.policy.window.inMinutes]) +
          context.tArgs('uiSkipped', <Object?>[guard.policy.safeModeLabel, CrashGuard.skippedInSafeMode.join("、")]),
          style: text.bodySmall,
        ),
        const Divider(height: 28),
        _title(text, context.t('uiStaticDeliveryBoundary')),
        Text(
          context.t('uiAllDartCharsChars') +
          context.t('uiBooksBooksPages'),
          style: text.bodySmall,
        ),
      ],
    );
  }

  Widget _title(TextTheme text, String label) => Padding(
        padding: const EdgeInsets.only(bottom: LrSpacing.xs),
        child: Text(label, style: text.titleMedium),
      );
}
