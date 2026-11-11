import 'package:flutter/material.dart';

import '../../../core/model/stats/keepsake_query.dart';
import '../../../core/model/stats/keepsakes.dart';
import '../../../core/model/stats/stats_date.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/components/glass/Nav.dart';
import '../../../l10n/lr_localizations.dart';

/// 纪念物卡：**类型 ∧ 月份**双筛选 + 环形切换 + 五种季节手账配色。
class KeepsakeCard extends StatelessWidget {
  const KeepsakeCard({
    super.key,
    required this.keepsakes,
    required this.palette,
    required this.index,
    required this.monthFilter,
    required this.kindFilter,
    required this.onIndexChanged,
    required this.onMonthChanged,
    required this.onKindChanged,
    this.onOpenCalendarMonth,
    this.onOpenLibrary,
  });

  final List<Keepsake> keepsakes;
  final SeasonPalette palette;
  final int index;
  final String? monthFilter;
  final KeepsakeKind? kindFilter;
  final ValueChanged<int> onIndexChanged;
  final ValueChanged<String?> onMonthChanged;
  final ValueChanged<KeepsakeKind?> onKindChanged;
  final VoidCallback? onOpenCalendarMonth;
  final VoidCallback? onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> months = KeepsakeQuery.monthKeys(keepsakes);
    final String? effectiveMonth =
        (monthFilter != null && months.contains(monthFilter))
            ? monthFilter
            : null;

    // 类型 chip 的计数只受月份影响：切换类型不应让其它类型的数字归零。
    final List<KeepsakeKindOption> kinds = KeepsakeQuery.kindOptions(
      keepsakes,
      filter: KeepsakeFilter(monthKey: effectiveMonth),
    );

    // 唯一查询出口：类型 ∧ 月份，顺序与纪念物册完全一致。
    final KeepsakeFilter filter = KeepsakeFilter(
      kind: kindFilter,
      monthKey: effectiveMonth,
    );
    final List<Keepsake> visible = KeepsakeQuery.apply(
      keepsakes: keepsakes,
      filter: filter,
    );
    final KeepsakeCycler cycler = KeepsakeCycler(visible).select(index);
    final Keepsake? current = cycler.current;

    final String scopeLabel = <String>[
      if (kindFilter != null) KeepsakeKindLabels.labels[kindFilter]!,
      if (effectiveMonth != null) effectiveMonth,
    ].join(' · ');

    return GlassPanel(
      tint: <Color>[
        palette.seed.withValues(alpha: 0.85),
        palette.accent.withValues(alpha: 0.14),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(context.t('keepsakeTitle'), style: text.titleLarge),
              const Spacer(),
              Text(
                context.tArgs('uiKeepsakesN1', <Object?>[
                  visible.length,
                  scopeLabel.isEmpty ? '' : ' · $scopeLabel'
                ]),
                style: text.labelSmall,
              ),
            ],
          ),

          // 类型筛选：六个类型恒可见，0 枚的禁用但仍标出数字，不静默隐藏。
          const SizedBox(height: LrSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                ChoiceChip(
                  label: Text(context.t('keepsakeAllKinds'),
                      style: text.labelLarge),
                  selected: kindFilter == null,
                  onSelected: (bool _) {
                    onKindChanged(null);
                    onIndexChanged(0);
                  },
                ),
                for (final KeepsakeKindOption o in kinds) ...<Widget>[
                  const SizedBox(width: LrSpacing.xs),
                  ChoiceChip(
                    label:
                        Text('${o.label} · ${o.count}', style: text.labelLarge),
                    selected: kindFilter == o.kind,
                    // 0 枚的类型不可点，但已选中的仍显示选中态（用户可能先选类型再切月份）。
                    onSelected: o.count == 0
                        ? null
                        : (bool _) {
                            onKindChanged(o.kind);
                            onIndexChanged(0);
                          },
                  ),
                ],
              ],
            ),
          ),

          if (months.isNotEmpty) ...<Widget>[
            const SizedBox(height: LrSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  ChoiceChip(
                    label: Text(context.t('calendarAllMonths'),
                        style: text.labelLarge),
                    selected: effectiveMonth == null,
                    onSelected: (bool _) {
                      onMonthChanged(null);
                      onIndexChanged(0);
                    },
                  ),
                  for (final String m in months) ...<Widget>[
                    const SizedBox(width: LrSpacing.xs),
                    ChoiceChip(
                      label: Text(m, style: text.labelLarge),
                      selected: effectiveMonth == m,
                      onSelected: (bool _) {
                        onMonthChanged(m);
                        onIndexChanged(0);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: LrSpacing.m),

          if (current == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.t('keepsakeEmptyTitle'), style: text.titleMedium),
                const SizedBox(height: LrSpacing.xs),
                Text(context.t('keepsakeEmptyBody'), style: text.bodySmall),
              ],
            )
          else
            _KeepsakeBody(keepsake: current, palette: palette),

          const SizedBox(height: LrSpacing.m),
          Divider(color: Theme.of(context).dividerTheme.color, height: 1),
          const SizedBox(height: LrSpacing.xs),
          Row(
            children: <Widget>[
              if (cycler.hasMultiple)
                Text('${cycler.index + 1} / ${cycler.items.length}',
                    style: text.labelSmall),
              const Spacer(),
              IconButton(
                tooltip: context.t('uiPreviousKeepsake'),
                onPressed: cycler.hasMultiple
                    ? () => onIndexChanged(cycler.previous().index)
                    : null,
                icon: const Icon(Icons.chevron_left, size: 19),
              ),
              IconButton(
                tooltip: context.t('uiNextKeepsake'),
                onPressed: cycler.hasMultiple
                    ? () => onIndexChanged(cycler.next().index)
                    : null,
                icon: const Icon(Icons.chevron_right, size: 19),
              ),
              if (onOpenCalendarMonth != null)
                TextButton.icon(
                  onPressed: onOpenCalendarMonth,
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(context.t('calendarOpenMonth'),
                      style: text.labelLarge),
                ),
            ],
          ),
          if (onOpenLibrary != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenLibrary,
                icon: const Icon(Icons.auto_awesome_mosaic_outlined, size: 16),
                label: Text(context.t('keepsakeOpenLibrary'),
                    style: text.labelLarge),
              ),
            ),
          const SizedBox(height: LrSpacing.xs),
          Text(context.t('keepsakeStaticNote'), style: text.labelSmall),
        ],
      ),
    );
  }
}

class _KeepsakeBody extends StatelessWidget {
  const _KeepsakeBody({required this.keepsake, required this.palette});

  final Keepsake keepsake;
  final SeasonPalette palette;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(LrRadius.card),
          ),
          child: Icon(
            KeepsakeKindLabels.icons[keepsake.kind],
            size: 20,
            color: palette.accent,
          ),
        ),
        const SizedBox(width: LrSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(keepsake.kindLabel, style: text.labelLarge),
                  const SizedBox(width: LrSpacing.xs),
                  Text(
                    '${dateLabelOf(keepsake.date)} · ${keepsake.monthKey}',
                    style: text.labelSmall,
                  ),
                  if (keepsake.fromUserExcerpt) ...<Widget>[
                    const SizedBox(width: LrSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: LrSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(LrRadius.pill),
                      ),
                      child:
                          Text(context.t('uiYours2'), style: text.labelSmall),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: LrSpacing.xs),
              Text(keepsake.title, style: text.titleMedium),
              const SizedBox(height: LrSpacing.xs),
              Text(
                keepsake.detail,
                style: text.bodyMedium?.copyWith(height: 1.55),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (keepsake.bookTitle != null) ...<Widget>[
                const SizedBox(height: LrSpacing.xs),
                Text('《${keepsake.bookTitle}》', style: text.labelSmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
