import 'package:flutter/material.dart';

import '../../../core/model/comic/comic_spread.dart';
import '../../../core/model/comic/comic_toc.dart';
import '../../../assembly/app_scope.dart';
import '../../../core/model/reader_style.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/components/glass/Nav.dart';
import '../../../l10n/lr_localizations.dart';

/// 阅读排版面板：阅读器顶栏与「我的」页共用同一张面板，写回同一个 AppState。
class ReaderStyleSheet extends StatelessWidget {
  const ReaderStyleSheet({super.key});

  /// 返回 Future，便于调用方在面板关闭后做一次性收尾（如让新语速生效）。
  static Future<void> open(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => const ReaderStyleSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ReaderStyle s = state.settings.reader;
    final bool motion = state.settings.motion;
    final TextTheme text = Theme.of(context).textTheme;

    void update(ReaderStyle next) => state.updateReader(next);

    return GlassPanel(
      padding: EdgeInsets.fromLTRB(
        LrSpacing.l,
        LrSpacing.l,
        LrSpacing.l,
        LrSpacing.l + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(context.t('uiReadingLayout'),
                      style: text.headlineMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: state.resetReader,
                    icon: const Icon(Icons.restart_alt_outlined, size: 17),
                    label: Text(context.t('uiResetToDefault'),
                        style: text.labelLarge),
                  ),
                ],
              ),
              const SizedBox(height: LrSpacing.xs),
              _SectionTitle(context.t('uiBodyText')),
              _SliderRow(
                label: context.t('uiFontSize'),
                value: s.fontSize,
                min: 14,
                max: 28,
                divisions: 14,
                display: '${s.fontSize.round()} pt',
                onChanged: (double v) => update(s.copyWith(fontSize: v)),
              ),
              _SliderRow(
                label: context.t('uiLineHeight2'),
                value: s.lineHeight,
                min: 1.3,
                max: 2.4,
                divisions: 11,
                display: s.lineHeight.toStringAsFixed(2),
                onChanged: (double v) => update(s.copyWith(lineHeight: v)),
              ),
              _SliderRow(
                label: context.t('uiFirstLineIndent'),
                value: s.firstLineIndentEm,
                min: 0,
                max: 4,
                divisions: 8,
                display: '${s.firstLineIndentEm.toStringAsFixed(1)} em',
                onChanged: (double v) =>
                    update(s.copyWith(firstLineIndentEm: v)),
              ),
              _SliderRow(
                label: context.t('uiParagraphSpacing'),
                value: s.paragraphSpacing,
                min: 0,
                max: 1.2,
                divisions: 12,
                display: s.paragraphSpacing.toStringAsFixed(2),
                onChanged: (double v) =>
                    update(s.copyWith(paragraphSpacing: v)),
              ),
              _SectionTitle(context.t('uiReadingBackground')),
              Wrap(
                spacing: LrSpacing.xs,
                runSpacing: LrSpacing.xs,
                children: <Widget>[
                  for (final ReaderBackground bg in ReaderBackground.values)
                    _BackgroundChip(
                      background: bg,
                      selected: s.background == bg,
                      onTap: () => update(s.copyWith(background: bg)),
                    ),
                ],
              ),
              const SizedBox(height: LrSpacing.xs),
              Text(
                context.t('uiBodyTextCharsCurrentcontrast') +
                    context.tArgs('uiWcagAaBodyText452',
                        <Object?>[s.bodyContrast.toStringAsFixed(2)]),
                style: text.bodySmall,
              ),
              _SectionTitle(context.t('uiPageTurnMotion')),
              Wrap(
                spacing: LrSpacing.xs,
                children: <Widget>[
                  for (final ReaderPageTurn t in ReaderPageTurn.values)
                    ChoiceChip(
                      label: Text(ReaderStyle.pageTurnLabels[t]!),
                      selected: s.pageTurn == t,
                      onSelected: motion
                          ? (bool _) => update(s.copyWith(pageTurn: t))
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: LrSpacing.xs),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(context.t('uiInterfaceMotion2'),
                    style: text.titleMedium),
                subtitle: Text(
                  state.settings.motion
                      ? context.t('uiChooseSlideSimulatedPageTurnWhenEnabled')
                      : context.t('uiMotionIsOffSoPageTurnIsLockedToNone'),
                  style: text.bodySmall,
                ),
                value: state.settings.motion,
                onChanged: state.setMotion,
              ),
              if (!motion)
                Padding(
                  padding: const EdgeInsets.only(bottom: LrSpacing.xs),
                  child: Text(
                    context.t(
                            'uiNormalizationIsCentralizedInAppsettingsNormali') +
                        context.t(
                            'uiTurningMotionOffLocksPageTurnToNonePagesNeverR'),
                    style: text.bodySmall,
                  ),
                ),
              _SectionTitle(context.t('uiComicReading')),
              Wrap(
                spacing: LrSpacing.xs,
                children: <Widget>[
                  for (final ComicReadMode m in ComicReadMode.values)
                    ChoiceChip(
                      label: Text(ComicModeLabels.labels[m]!),
                      selected: s.comicReadMode == m,
                      onSelected: (bool _) =>
                          update(s.copyWith(comicReadMode: m)),
                    ),
                ],
              ),
              const SizedBox(height: LrSpacing.xs),
              Text(ComicModeLabels.hints[s.comicReadMode]!,
                  style: text.bodySmall),
              const SizedBox(height: LrSpacing.xs),
              Text(context.t('comicLocalNote'), style: text.labelSmall),
              _SectionTitle(context.t('comicSpreadTitle')),
              if (s.comicReadMode == ComicReadMode.vertical)
                GlassPanel(
                  padding: const EdgeInsets.all(LrSpacing.m),
                  child: Text(context.t('comicVerticalLockNote'),
                      style: text.bodySmall),
                )
              else ...<Widget>[
                Wrap(
                  spacing: LrSpacing.xs,
                  children: <Widget>[
                    for (final ComicSpreadMode m in ComicSpreadMode.values)
                      ChoiceChip(
                        label: Text(ComicSpreadLabels.mode[m]!),
                        selected: s.comicSpreadMode == m,
                        onSelected: (bool _) =>
                            update(s.copyWith(comicSpreadMode: m)),
                      ),
                  ],
                ),
                const SizedBox(height: LrSpacing.xs),
                Text(ComicSpreadLabels.modeHint[s.comicSpreadMode]!,
                    style: text.bodySmall),
                const SizedBox(height: LrSpacing.m),
                Wrap(
                  spacing: LrSpacing.xs,
                  children: <Widget>[
                    for (final ComicReadingDirection d
                        in ComicReadingDirection.values)
                      ChoiceChip(
                        label: Text(ComicSpreadLabels.direction[d]!),
                        selected: s.comicDirection == d,
                        onSelected: (bool _) =>
                            update(s.copyWith(comicDirection: d)),
                      ),
                  ],
                ),
                const SizedBox(height: LrSpacing.xs),
                Text(ComicSpreadLabels.directionHint[s.comicDirection]!,
                    style: text.bodySmall),
                const SizedBox(height: LrSpacing.xs),
                // 第十九轮：宽幅页（横幅 / 跨页彩图）独占一跨。只在双页模式生效，
                // 单页模式每页本来就独占，开关仍保留偏好但不产生视觉差异。
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(context.t('comicWideSoloTitle'),
                      style: text.bodyMedium),
                  subtitle: Text(
                    s.comicSpreadMode == ComicSpreadMode.single
                        ? context.t('comicWideSoloSingleNote')
                        : context.t('comicWideSoloNote'),
                    style: text.bodySmall,
                  ),
                  value: s.widePageSolo,
                  onChanged: (bool v) => update(s.copyWith(widePageSolo: v)),
                ),
                const SizedBox(height: LrSpacing.xs),
                // 第二十轮：书脊留白是固定视觉规则（不是可写偏好），
                // 只在两页真实页并排时生效；数值全部由 ComicSpreadGutter 裁决。
                GlassPanel(
                  padding: const EdgeInsets.all(LrSpacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(context.t('comicSpineGutterTitle'),
                          style: text.labelLarge),
                      const SizedBox(height: 4),
                      Text(context.t('comicSpineGutterNote'),
                          style: text.bodySmall),
                      // 第二十一轮：渐暗强度模型化说明。档位按槽宽自动选、
                      // 目标色按背景亮度反推，仍然是固定规则不是用户设置。
                      const SizedBox(height: LrSpacing.xs),
                      Text(context.t('comicSpineShadeTitle'),
                          style: text.labelLarge),
                      const SizedBox(height: 4),
                      Text(context.t('comicSpineShadeNote'),
                          style: text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: LrSpacing.xs),
                Text(context.t('comicSpreadStaticNote'),
                    style: text.labelSmall),
              ],
              _SectionTitle(context.t('uiReadAloud2')),
              _SliderRow(
                label: context.t('uiRate'),
                value: s.ttsRate,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                display: '${s.ttsRate.toStringAsFixed(2)} ×',
                onChanged: (double v) => update(s.copyWith(ttsRate: v)),
              ),
              _SliderRow(
                label: context.t('uiPitch'),
                value: s.ttsPitch,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                display: '${s.ttsPitch.toStringAsFixed(2)} ×',
                onChanged: (double v) => update(s.copyWith(ttsPitch: v)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title:
                    Text(context.t('uiTtsReadAloud'), style: text.titleMedium),
                subtitle: Text(context.t('uiSentenceQueueAutoNextChapter'),
                    style: text.bodySmall),
                value: state.settings.tts,
                onChanged: state.setTts,
              ),
              _SectionTitle(context.t('uiReadingAidsPlatformCapability')),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title:
                    Text(context.t('uiKeepScreenOn'), style: text.titleMedium),
                value: s.keepScreenOn,
                onChanged: (bool v) => update(s.copyWith(keepScreenOn: v)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(context.t('uiVolumeKeyPaging'),
                    style: text.titleMedium),
                value: s.volumeKeyTurnPage,
                onChanged: (bool v) => update(s.copyWith(volumeKeyTurnPage: v)),
              ),
              Text(
                context.t('uiItems9'),
                style: text.bodySmall,
              ),
              const SizedBox(height: LrSpacing.m),
              Text(
                context.t('uiSaveSettingsstore'),
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: LrSpacing.m, bottom: LrSpacing.xs),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        SizedBox(width: 66, child: Text(label, style: text.bodyMedium)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
            width: 56,
            child: Text(display,
                textAlign: TextAlign.right, style: text.labelSmall)),
      ],
    );
  }
}

class _BackgroundChip extends StatelessWidget {
  const _BackgroundChip({
    required this.background,
    required this.selected,
    required this.onTap,
  });

  final ReaderBackground background;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = ReaderStyle.backgroundColors[background]!;
    final Color on = ReaderStyle.onColor(bg);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: LrSpacing.xs),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(LrRadius.card),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                size: 16, color: on),
            const SizedBox(height: 3),
            Text(
              ReaderStyle.backgroundLabels[background]!,
              style: TextStyle(fontSize: 11, color: on),
            ),
          ],
        ),
      ),
    );
  }
}
