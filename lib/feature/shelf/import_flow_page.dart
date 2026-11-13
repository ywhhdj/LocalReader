import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/usecases/import_session.dart';
import '../../assembly/app_scope.dart';
import '../../assembly/app_services.dart';
import '../../data/platform/import_service.dart';
import '../../data/platform/real_bridges.dart' show PlatformUnavailable;
import '../../core/common/design_tokens.dart';
import '../../core/ui/theme/glass_theme.dart';
import '../../core/ui/theme/season_scheme.dart';
import '../../core/ui/components/glass/Nav.dart';
import '../../l10n/lr_localizations.dart';

/// 导入向导：格式说明 → 选择授权方式 → 扫描结果 → 冲突处理 → 完成写回。
class ImportFlowPage extends StatefulWidget {
  const ImportFlowPage({super.key, this.initialStep = ImportStep.intro});

  final ImportStep initialStep;

  @override
  State<ImportFlowPage> createState() => _ImportFlowPageState();
}

class _ImportFlowPageState extends State<ImportFlowPage> {
  late ImportSession _session;

  /// 真实扫描得到的路径；为空表示当前处于演示数据回退态。
  List<String> _realPaths = const <String>[];
  bool _busy = false;
  bool _usedDemo = false;

  @override
  void initState() {
    super.initState();
    _session = ImportSession(step: widget.initialStep);
  }

  List<ExistingBook> get _existing => <ExistingBook>[
        for (final book in AppScope.of(context).allBooks)
          ExistingBook(id: book.id, title: book.title),
      ];

  void _update(ImportSession next) {
    if (next == _session) return;
    setState(() => _session = next);
  }

  void _next() {
    if (_busy) return;
    if (_session.step == ImportStep.done) {
      _finish();
      return;
    }
    // 授权 → 扫描这一步改为异步真实扫描，不再读 ImportDemoPaths。
    if (_session.step == ImportStep.permission && _session.canAdvance) {
      unawaited(_scanForReal());
      return;
    }
    _update(_session.advance(existing: _existing));
  }

  Future<void> _scanForReal() async {
    setState(() => _busy = true);
    try {
      final ImportService service = AppServices.of(context).importer;
      final ImportScanResult result = await service.scan(
        forcePick: _session.mode == ImportPermissionMode.documentPicker,
      );
      final List<String> paths = await service.filterSupported(result.paths);
      _realPaths = paths;
      _usedDemo = false;
      if (!mounted) return;
      final ScanReport report = ImportScanner.scan(paths);
      _update(_session.advance(existing: _existing).copyWith(
        report: report,
        conflicts: ImportScanner.conflicts(report, _existing),
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已扫描 ${paths.length} 个文件 · ${result.root}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } on PlatformUnavailable catch (e) {
      // 平台通道未注册（桌面 / 单测 / 未接原生插件）：明确告知并回退到演示数据，
      // 不让「下一步」变成点了没反应。
      _usedDemo = true;
      _realPaths = const <String>[];
      if (!mounted) return;
      _update(_session.advance(existing: _existing));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e；已使用演示数据，真机接入原生插件后自动改为真实扫描'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      _usedDemo = true;
      if (!mounted) return;
      _update(_session.advance(existing: _existing));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描失败：$e；已使用演示数据')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _finish() {
    final AppState state = AppScope.of(context);
    final Set<String> ids = <String>{
      for (final b in state.allBooks) b.id,
    };
    final ImportCommit commit = _session.commit(existingIds: ids);
    final int added = state.applyImport(commit);
    // 真实落库：写入 books 表，替换「只记在内存里」的静态交付口径。
    if (!_usedDemo) {
      unawaited(AppServices.of(context).importer.persist(commit));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lrTextArgs('uiBooksN1', <Object?>[
            added,
            commit.deferredCount > 0
                ? lrTextArgs('uiDeferredN', <Object?>[commit.deferredCount])
                : ''
          ]),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final SeasonPalette palette =
        Theme.of(context).extension<LrSeasonTheme>()?.palette ??
            SeasonSchemes.resolve(
              AppScope.of(context).season.value,
              isDark ? Brightness.dark : Brightness.light,
            );

    return Scaffold(
      backgroundColor: isDark ? palette.seed : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(context.t('importWizardTitle')),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? <Color>[
                    palette.seed,
                    Color.lerp(palette.seed, Colors.black, 0.35)!
                  ]
                : <Color>[
                    palette.seed,
                    Color.lerp(palette.seed, Colors.white, 0.55)!
                  ],
          ),
        ),
        child: Column(
          children: <Widget>[
            _StepHeader(session: _session, labels: ImportLabels.shortSteps),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  LrSpacing.l,
                  LrSpacing.xs,
                  LrSpacing.l,
                  LrSpacing.l,
                ),
                child: _body(),
              ),
            ),
            _BottomBar(
              session: _session,
              onBack: () => _update(_session.back()),
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_session.step) {
      case ImportStep.intro:
        return _IntroStep();
      case ImportStep.permission:
        return _PermissionStep(
          session: _session,
          onChoose: (ImportPermissionMode m) => _update(_session.chooseMode(m)),
          onGrant: () => _update(_session.grant()),
        );
      case ImportStep.scan:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Text(
                _usedDemo
                    ? '当前为演示数据（原生文件通道未接入）；真机将自动改为真实扫描'
                    : '真实目录扫描：${_realPaths.length} 个文件',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            _ScanStep(session: _session),
          ],
        );
      case ImportStep.conflicts:
        return _ConflictStep(
          session: _session,
          onResolve: (int i, ConflictResolution r) =>
              _update(_session.resolve(i, r)),
          onResolveAll: (ConflictResolution r) =>
              _update(_session.resolveAll(r)),
        );
      case ImportStep.done:
        return _DoneStep(session: _session, existingIds: <String>{
          for (final b in AppScope.of(context).allBooks) b.id,
        });
    }
  }
}

// ---------------------------------------------------------------- 步骤条

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.session, required this.labels});

  final ImportSession session;
  final Map<ImportStep, String> labels;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: LrSpacing.l, vertical: LrSpacing.xs),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < ImportStep.values.length; i++) ...<Widget>[
            if (i > 0)
              Expanded(
                child: Divider(
                  color: i <= session.stepIndex
                      ? accent
                      : Theme.of(context).dividerTheme.color,
                  thickness: 1.5,
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: i <= session.stepIndex
                      ? accent
                      : Theme.of(context).dividerTheme.color,
                  child: Text('${i + 1}',
                      style: text.labelSmall?.copyWith(
                        color: i <= session.stepIndex
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      )),
                ),
                const SizedBox(height: LrSpacing.xs),
                Text(labels[ImportStep.values[i]]!, style: text.labelSmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 1 · 说明

class _IntroStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.t('uiReviewBeforeImporting'), style: text.headlineMedium),
        const SizedBox(height: LrSpacing.m),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Line(
                  text: text,
                  label: context.t('uiSupportedFormats'),
                  value: context.t('importFormats')),
              _Line(
                  text: text,
                  label: context.t('uiArchives'),
                  value: context.t('archiveNotice')),
              _Line(
                  text: text,
                  label: context.t('uiPermissions'),
                  value: context.t('permissionNotice')),
              _Line(
                  text: text,
                  label: context.t('uiImportChannels'),
                  value: context.t('importChannels')),
              _Line(
                  text: text,
                  label: context.t('uiOnline'),
                  value: context.t('localOnlyNote')),
            ],
          ),
        ),
        const SizedBox(height: LrSpacing.m),
        GlassPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.info_outline,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: LrSpacing.xs),
              Expanded(
                  child: Text(context.t('importWizardStaticNote'),
                      style: text.bodySmall)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.label, required this.value});

  final TextTheme text;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: LrSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: text.labelLarge),
            const SizedBox(height: 2),
            Text(value, style: text.bodySmall),
          ],
        ),
      );
}

// ---------------------------------------------------------------- 2 · 授权

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({
    required this.session,
    required this.onChoose,
    required this.onGrant,
  });

  final ImportSession session;
  final ValueChanged<ImportPermissionMode> onChoose;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.t('uiChooseAnAuthorizationMethod'),
            style: text.headlineMedium),
        const SizedBox(height: LrSpacing.xs),
        Text(context.t('permissionNotice'), style: text.bodySmall),
        const SizedBox(height: LrSpacing.m),
        ...ImportPermissionMode.values.map<Widget>((ImportPermissionMode m) {
          final bool selected = session.mode == m;
          return Padding(
            padding: const EdgeInsets.only(bottom: LrSpacing.xs),
            child: GestureDetector(
              onTap: () => onChoose(m),
              child: GlassPanel(
                child: Row(
                  children: <Widget>[
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 19,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: LrSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(ImportLabels.modes[m]!, style: text.titleMedium),
                          const SizedBox(height: 2),
                          Text(ImportLabels.modeHints[m]!,
                              style: text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: LrSpacing.xs),
        Row(
          children: <Widget>[
            FilledButton.icon(
              onPressed:
                  session.mode == null || session.granted ? null : onGrant,
              icon: const Icon(Icons.folder_open_outlined, size: 17),
              label: Text(session.granted
                  ? context.t('uiAuthorizationConfirmed')
                  : '确认授权方式'),
            ),
            const SizedBox(width: LrSpacing.m),
            Expanded(
              child: Text(
                session.granted
                    ? '下一步将拉起系统目录选择器并递归扫描书籍文件'
                    : context.t('importNoGrantHint'),
                style: text.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: LrSpacing.m),
        Text(
          '授权由系统文件选择器完成并持久化；扫描结果来自真实目录，仅在本机处理。',
          style: text.labelSmall,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 3 · 扫描

class _ScanStep extends StatelessWidget {
  const _ScanStep({required this.session});

  final ImportSession session;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ScanReport? report = session.report;
    if (report == null) {
      return GlassPanel(
          child: Text(context.t('importScanEmpty'), style: text.bodyMedium));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.t('uiScanResults'), style: text.headlineMedium),
        const SizedBox(height: LrSpacing.xs),
        Wrap(
          spacing: LrSpacing.xs,
          runSpacing: LrSpacing.xs,
          children: <Widget>[
            _CountChip(label: context.t('uiScanned'), value: report.total),
            _CountChip(
                label: context.t('uiImportable'), value: report.acceptedCount),
            _CountChip(
                label: context.t('uiUnsupported'), value: report.rejectedCount),
            _CountChip(
                label: context.t('uiUnregistered'),
                value: report.unsupportedCount),
            _CountChip(
                label: context.t('uiNameConflict'),
                value: session.conflicts.length),
          ],
        ),
        const SizedBox(height: LrSpacing.m),
        ...report.candidates.map<Widget>(
          (ImportCandidate c) => Padding(
            padding: const EdgeInsets.only(bottom: LrSpacing.xs),
            child: _CandidateCard(candidate: c),
          ),
        ),
        const SizedBox(height: LrSpacing.xs),
        Text(context.t('archiveNotice'), style: text.labelSmall),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => GlassPanel(
        borderRadius: LrRadius.pill,
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.m, vertical: LrSpacing.xs),
        child: Text('$label $value',
            style: Theme.of(context).textTheme.labelLarge),
      );
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final ImportCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color statusColor = switchColor(context, candidate.status);
    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(LrRadius.pill),
            ),
          ),
          const SizedBox(width: LrSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(candidate.title,
                          style: text.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(candidate.format, style: text.labelSmall),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  candidate.path,
                  style: text.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: LrSpacing.xs),
                Text(
                  '${ImportLabels.statuses[candidate.status]} · '
                  '${ImportLabels.renderRoutes[candidate.route] ?? ''}'
                  '${candidate.reason.isEmpty ? '' : ' · ${candidate.reason}'}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color switchColor(BuildContext context, CandidateStatus s) {
    switch (s) {
      case CandidateStatus.accepted:
        return Colors.green.shade400;
      case CandidateStatus.rejected:
        return Colors.orange.shade400;
      case CandidateStatus.unsupported:
        return Theme.of(context).colorScheme.error;
    }
  }
}

// ---------------------------------------------------------------- 4 · 冲突

class _ConflictStep extends StatelessWidget {
  const _ConflictStep({
    required this.session,
    required this.onResolve,
    required this.onResolveAll,
  });

  final ImportSession session;
  final void Function(int, ConflictResolution) onResolve;
  final ValueChanged<ConflictResolution> onResolveAll;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    if (session.conflicts.isEmpty) {
      return GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(context.t('uiNoNameConflicts'), style: text.titleMedium),
            const SizedBox(height: LrSpacing.xs),
            Text(context.t('importConflictNote'), style: text.bodySmall),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.t('uiResolveDuplicateNames'), style: text.headlineMedium),
        const SizedBox(height: LrSpacing.xs),
        Text(context.t('importConflictNote'), style: text.bodySmall),
        const SizedBox(height: LrSpacing.m),
        Wrap(
          spacing: LrSpacing.xs,
          children: <Widget>[
            for (final ConflictResolution r in ConflictResolution.values)
              ActionChip(
                label: Text(
                    context
                        .tArgs('uiAll', <Object?>[ImportLabels.resolutions[r]]),
                    style: text.labelLarge),
                onPressed: () => onResolveAll(r),
              ),
          ],
        ),
        const SizedBox(height: LrSpacing.m),
        ...session.conflicts.asMap().entries.map<Widget>(
              (MapEntry<int, ImportConflict> e) => Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.xs),
                child: _ConflictCard(
                  conflict: e.value,
                  onPick: (ConflictResolution r) => onResolve(e.key, r),
                ),
              ),
            ),
      ],
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.conflict, required this.onPick});

  final ImportConflict conflict;
  final ValueChanged<ConflictResolution> onPick;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(conflict.candidate.title, style: text.titleMedium),
          const SizedBox(height: 2),
          Text(
            context.tArgs('uiDuplicateOf',
                <Object?>[conflict.existing.title, conflict.candidate.format]),
            style: text.labelSmall,
          ),
          const SizedBox(height: LrSpacing.xs),
          Wrap(
            spacing: LrSpacing.xs,
            runSpacing: LrSpacing.xs,
            children: <Widget>[
              for (final ConflictResolution r in ConflictResolution.values)
                ChoiceChip(
                  label: Text(ImportLabels.resolutions[r]!),
                  selected: conflict.resolution == r,
                  onSelected: (bool _) => onPick(r),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 5 · 完成

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.session, required this.existingIds});

  final ImportSession session;
  final Set<String> existingIds;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ImportCommit commit = session.commit(existingIds: existingIds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.t('uiImportSummary'), style: text.headlineMedium),
        const SizedBox(height: LrSpacing.m),
        GlassPanel(
          child: Column(
            children: <Widget>[
              _SummaryRow(
                  text: text,
                  label: context.t('uiScannedFiles'),
                  value: context
                      .tArgs('uiItems3', <Object?>[commit.totalCandidates])),
              _SummaryRow(
                  text: text,
                  label: context.t('uiToBeAdded'),
                  value:
                      context.tArgs('uiBooks', <Object?>[commit.addedCount])),
              _SummaryRow(
                  text: text,
                  label: context.t('uiSkippedUnsupported'),
                  value: context.tArgs('uiItems4',
                      <Object?>[commit.skipped + commit.unsupported])),
              _SummaryRow(
                  text: text,
                  label: context.t('uiNameConflict'),
                  value: context
                      .tArgs('uiItems5', <Object?>[commit.conflictCount])),
              _SummaryRow(
                  text: text,
                  label: context.t('uiDeferred'),
                  value: context
                      .tArgs('uiItems6', <Object?>[commit.deferredCount])),
            ],
          ),
        ),
        const SizedBox(height: LrSpacing.m),
        if (commit.added.isNotEmpty) ...<Widget>[
          Text(context.t('uiToBeAdded2'), style: text.labelLarge),
          const SizedBox(height: LrSpacing.xs),
          ...commit.added.map<Widget>(
            (ImportBookDraft d) => Padding(
              padding: const EdgeInsets.only(bottom: LrSpacing.xs),
              child: GlassPanel(
                padding: const EdgeInsets.all(LrSpacing.m),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(d.title, style: text.titleMedium)),
                    Text(d.format, style: text.labelSmall),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: LrSpacing.m),
        Text(context.t('importDoneNote'), style: text.bodySmall),
        const SizedBox(height: LrSpacing.xs),
        Text(context.t('demoDataNote'), style: text.labelSmall),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.text, required this.label, required this.value});

  final TextTheme text;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: LrSpacing.xs),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: text.bodyMedium)),
            Text(value, style: text.titleMedium),
          ],
        ),
      );
}

// ---------------------------------------------------------------- 底栏

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.session,
    required this.onBack,
    required this.onNext,
  });

  final ImportSession session;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool done = session.step == ImportStep.done;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            LrSpacing.l, LrSpacing.xs, LrSpacing.l, LrSpacing.m),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!session.canAdvance && !done)
                Padding(
                  padding: const EdgeInsets.only(bottom: LrSpacing.xs),
                  child: Text(session.blockingHint, style: text.labelSmall),
                ),
              Row(
                children: <Widget>[
                  if (!session.isFirst)
                    OutlinedButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back, size: 17),
                      label: Text(context.t('uiBack')),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed:
                        done ? onNext : (session.canAdvance ? onNext : null),
                    icon: Icon(done ? Icons.check : Icons.arrow_forward,
                        size: 17),
                    label: Text(done
                        ? context.t('uiWriteToShelfAndClose')
                        : context.t('uiNext')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
