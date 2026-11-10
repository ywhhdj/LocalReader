import 'package:Local_reader/core/model/stats/keepsakes.dart';
import 'package:flutter/material.dart';

import '../../../assembly/app_scope.dart';
import '../../../core/model/reader_style.dart';
import '../../../core/model/stats/keepsake_kind.dart';
import '../../../core/model/stats/keepsake_query.dart';
import '../../../core/model/stats/reading_stats.dart';
import '../../../core/model/stats/widget_preview.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/theme/season_scheme.dart';
import '../../../core/ui/components/glass.dart';
import '../../../l10n/lr_localizations.dart';

/// 应用内小组件配置面板。
///
/// 参考仓库：每个小组件的内容与外观可独立配置、可同时放置多个，S/M/L 三档均支持明暗模式。
/// **边界**：这里配置的是「应用内预览 + 交给三端的数据」，不是桌面小组件本体。
/// Android 用应用内配置、iOS 用 WidgetKit 系统编辑控件、HarmonyOS 用卡片配置，
/// 三端本体都需原生实现（❄️ 冻结），Flutter 不冒充桌面 Widget。
class WidgetConfigSheet extends StatefulWidget {
  const WidgetConfigSheet({super.key, this.onOpenKeepsakeMonth});

  /// 「查看本月纪念物」→ 纪念物册，由 app 层注入；带本月 monthKey 深链。
  /// 面板不构造路由，feature 之间不互相依赖。
  final ValueChanged<String>? onOpenKeepsakeMonth;

  static Future<void> open(
    BuildContext context, {
    ValueChanged<String>? onOpenKeepsakeMonth,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext ctx) => WidgetConfigSheet(
          onOpenKeepsakeMonth: onOpenKeepsakeMonth,
        ),
      );

  @override
  State<WidgetConfigSheet> createState() => _WidgetConfigSheetState();
}

class _WidgetConfigSheetState extends State<WidgetConfigSheet> {
  String? _expandedId;
  bool _previewDark = false;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<WidgetSpec> specs = state.widgetSpecs;

    // 「本月」取统计快照的固定基准日，不读 DateTime.now()：热力图、纪念物册、
    // 小组件预览必须落在同一个月，真机时间一变就漂移是第十三轮修掉的老问题。
    final List<ReadingDay> days = state.stats.snapshot().days;
    final DateTime? monthDate = days.isEmpty ? null : days.last.date;
    final List<Keepsake> keepsakes = state.keepsakes;

    return GlassPanel(
      padding: EdgeInsets.fromLTRB(
        LrSpacing.l,
        LrSpacing.l,
        LrSpacing.l,
        LrSpacing.l + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(context.t('uiWidgets2'), style: text.headlineMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: state.resetWidgetSpecs,
                    icon: const Icon(Icons.restart_alt_outlined, size: 17),
                    label: Text(context.t('uiResetToDefault'), style: text.labelLarge),
                  ),
                ],
              ),
              const SizedBox(height: LrSpacing.xs),
              Text(context.tArgs('uiTotalItemsItemsItems', <Object?>[specs.length]), style: text.bodySmall),
              const SizedBox(height: LrSpacing.m),

              // 明暗预览开关：同一套配置在浅/深色下都要可读
              GlassPanel(
                borderRadius: LrRadius.pill,
                padding: const EdgeInsets.symmetric(horizontal: LrSpacing.m),
                child: Row(
                  children: <Widget>[
                    Icon(
                      _previewDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: LrSpacing.s),
                    Expanded(
                      child: Text(
                        _previewDark ? context.t('uiDarkPreview') : context.t('uiLightPreview'),
                        style: text.labelLarge,
                      ),
                    ),
                    Switch.adaptive(
                      value: _previewDark,
                      onChanged: (bool v) => setState(() => _previewDark = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LrSpacing.s),

              ...specs.map<Widget>((WidgetSpec spec) => Padding(
                    padding: const EdgeInsets.only(bottom: LrSpacing.s),
                    child: _SpecCard(
                      spec: spec,
                      expanded: _expandedId == spec.id,
                      previewBrightness: _previewDark ? Brightness.dark : Brightness.light,
                      onToggle: () => setState(
                        () => _expandedId = _expandedId == spec.id ? null : spec.id,
                      ),
                      onChange: (WidgetSpec next) => state.updateWidgetSpec(next),
                      onRemove: () => state.removeWidgetSpec(spec.id),
                      keepsakePreview: (spec.content == WidgetContent.keepsake &&
                              monthDate != null)
                          ? KeepsakeMonthPreview.build(
                              keepsakes: keepsakes,
                              monthDate: monthDate,
                              kind: spec.keepsakeKind,
                            )
                          : null,
                      onOpenKeepsakeMonth: widget.onOpenKeepsakeMonth,
                    ),
                  )),

              const SizedBox(height: LrSpacing.s),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  final WidgetSpec added = state.addWidgetSpec();
                  _expandedId = added.id;
                }),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.t('uiAddAWidget')),
              ),
              const SizedBox(height: LrSpacing.m),

              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: LrSpacing.s),
                        Text(context.t('uiAboutDesktopWidgets'), style: text.titleMedium),
                      ],
                    ),
                    const SizedBox(height: LrSpacing.s),
                    Text(
                      context.t('uiSaveWidgetsFlutter') +
                      context.t('uiAndroidUsesInAppConfigIosUsesWidgetkitEditCont') +
                      context.t('uiAllThreePlatformsNeedNativeImplementationsRead'),
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: LrSpacing.s),
                    Text(context.t('demoDataNote'), style: text.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({
    required this.spec,
    required this.expanded,
    required this.previewBrightness,
    required this.onToggle,
    required this.onChange,
    required this.onRemove,
    this.keepsakePreview,
    this.onOpenKeepsakeMonth,
  });

  final WidgetSpec spec;
  final bool expanded;
  final Brightness previewBrightness;
  final VoidCallback onToggle;
  final ValueChanged<WidgetSpec> onChange;
  final VoidCallback onRemove;
  final KeepsakeMonthPreview? keepsakePreview;
  final ValueChanged<String>? onOpenKeepsakeMonth;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final SeasonPalette palette = SeasonSchemes.preview(spec.season, brightness: previewBrightness);
    final Color on = ReaderStyle.onColor(palette.seed);
    final bool isDark = previewBrightness == Brightness.dark;
    // 提到局部变量，避免在字符串插值里再嵌一层插值（静态阶段无 SDK 验证，宁可直白）。
    final String kindSuffix = (spec.content == WidgetContent.keepsake &&
            spec.keepsakeKind != null)
        ? ' · ${KeepsakeKindLabels.labels[spec.keepsakeKind]!}'
        : '';

    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 预览块：内容 + 尺寸 + 季节 + 明暗四项都能一眼看到
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(LrSpacing.m),
              decoration: BoxDecoration(
                color: palette.seed,
                borderRadius: BorderRadius.circular(LrRadius.card),
                border: Border.all(color: palette.accent.withOpacity(0.4)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(WidgetSpecLabels.icon[spec.content], size: 22, color: palette.accent),
                  const SizedBox(width: LrSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          WidgetSpecLabels.content[spec.content]!,
                          style: text.titleMedium?.copyWith(color: on),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tArgs('uiWidgetSpecLine', <Object?>[
                            WidgetSpecLabels.size[spec.size],
                            palette.label,
                            spec.showProgress ? lrText('uiShowProgress') : '',
                            kindSuffix,
                          ]),
                          style: text.labelSmall?.copyWith(color: on.withOpacity(0.62)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: on.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
          // 第十九轮：内容 = 纪念物时，预览块下方直接给出「本月」真实聚合结果，
          // 而不只是四个配置项。桌面小组件本体仍 ❄️ 冻结，这里只是应用内预览。
          if (keepsakePreview != null) ...<Widget>[
            const SizedBox(height: LrSpacing.s),
            _MonthKeepsakePreview(
              preview: keepsakePreview!,
              palette: palette,
              on: on,
              onOpenMonth: onOpenKeepsakeMonth == null
                  ? null
                  : () => onOpenKeepsakeMonth!(keepsakePreview!.monthKey),
            ),
          ],
          if (expanded) ...<Widget>[
            const SizedBox(height: LrSpacing.m),
            Text(context.t('uiContent2'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Wrap(
              spacing: LrSpacing.s,
              runSpacing: LrSpacing.xs,
              children: <Widget>[
                for (final WidgetContent c in WidgetContent.values)
                  ChoiceChip(
                    label: Text(WidgetSpecLabels.content[c]!),
                    selected: spec.content == c,
                    onSelected: (bool _) => onChange(spec.copyWith(content: c)),
                  ),
              ],
            ),
            // 内容 = 纪念物时，每个小组件可独立指定一种类型；null = 显示全部。
            // 面板只在展开且内容匹配时渲染，其它内容档不会多出一排无关 chip。
            if (spec.content == WidgetContent.keepsake) ...<Widget>[
              const SizedBox(height: LrSpacing.s),
              Text(context.t('uiKeepsakeTypePerWidget'), style: text.labelSmall),
              const SizedBox(height: LrSpacing.xs),
              Wrap(
                spacing: LrSpacing.s,
                runSpacing: LrSpacing.xs,
                children: <Widget>[
                  ChoiceChip(
                    label: Text(context.t('keepsakeAllKinds')),
                    selected: spec.keepsakeKind == null,
                    onSelected: (bool _) =>
                        onChange(spec.copyWith(clearKeepsakeKind: true)),
                  ),
                  for (final KeepsakeKind k in KeepsakeKind.values)
                    ChoiceChip(
                      label: Text(KeepsakeKindLabels.labels[k]!),
                      selected: spec.keepsakeKind == k,
                      onSelected: (bool _) =>
                          onChange(spec.copyWith(keepsakeKind: k)),
                    ),
                ],
              ),
              const SizedBox(height: LrSpacing.xs),
              Text(context.t('keepsakeWidgetKindNote'), style: text.labelSmall),
            ],
            const SizedBox(height: LrSpacing.s),
            Text(context.t('uiSize2'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Wrap(
              spacing: LrSpacing.s,
              children: <Widget>[
                for (final WidgetSize s in WidgetSize.values)
                  ChoiceChip(
                    label: Text(WidgetSpecLabels.size[s]!),
                    selected: spec.size == s,
                    onSelected: (bool _) => onChange(spec.copyWith(size: s)),
                  ),
              ],
            ),
            const SizedBox(height: LrSpacing.s),
            Text(context.t('uiSeasonStyleIndependentOfAppTheme'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Wrap(
              spacing: LrSpacing.s,
              runSpacing: LrSpacing.xs,
              children: <Widget>[
                for (final SeasonStyle s in SeasonSchemes.styles)
                  GestureDetector(
                    onTap: () => onChange(spec.copyWith(season: s)),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: SeasonSchemes.preview(s, brightness: previewBrightness).accent,
                      child: spec.season == s
                          ? Icon(Icons.check, size: 15, color: isDark ? Colors.black : Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: LrSpacing.s),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(context.t('uiShowProgress2'), style: text.bodyMedium),
              value: spec.showProgress,
              onChanged: (bool v) => onChange(spec.copyWith(showProgress: v)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(context.t('uiRemove2'), style: text.labelLarge),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 「本月纪念物」小组件预览：显示真实聚合结果，不是静态示意图。
/// 数据全部来自 `KeepsakeMonthPreview`，本组件不自己算条数、不读时间。
class _MonthKeepsakePreview extends StatelessWidget {
  const _MonthKeepsakePreview({
    required this.preview,
    required this.palette,
    required this.on,
    this.onOpenMonth,
  });

  final KeepsakeMonthPreview preview;
  final SeasonPalette palette;
  final Color on;
  final VoidCallback? onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color sub = on.withOpacity(0.72);
    final KeepsakeMonthEmptyKind empty = preview.emptyKind;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LrSpacing.m),
      decoration: BoxDecoration(
        color: palette.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(LrRadius.card),
        border: Border.all(color: palette.accent.withOpacity(0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_outlined, size: 16, color: palette.accent),
              const SizedBox(width: LrSpacing.s),
              Text(context.t('uiThisMonthKeepsakePreview'), style: text.labelLarge?.copyWith(color: on)),
              const Spacer(),
              Text(preview.monthKey, style: text.labelSmall?.copyWith(color: sub)),
            ],
          ),
          const SizedBox(height: LrSpacing.s),
          Text(preview.headline,
              style: text.titleMedium?.copyWith(color: on)),
          if (preview.subline.isNotEmpty) ...<Widget>[
            const SizedBox(height: LrSpacing.xs),
            Text(preview.subline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: sub)),
          ],
          if (preview.kindOptions.isNotEmpty) ...<Widget>[
            const SizedBox(height: LrSpacing.s),
            Wrap(
              spacing: LrSpacing.xs,
              runSpacing: LrSpacing.xs,
              children: <Widget>[
                for (final KeepsakeKindOption o in preview.kindOptions)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LrSpacing.s,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.seed.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(LrRadius.pill),
                    ),
                    child: Text('${o.label} ${o.count}',
                        style: text.labelSmall?.copyWith(color: on)),
                  ),
              ],
            ),
          ],
          if (empty != KeepsakeMonthEmptyKind.none) ...<Widget>[
            const SizedBox(height: LrSpacing.s),
            Text(_emptyBody(empty), style: text.bodySmall?.copyWith(color: sub)),
          ],
          const SizedBox(height: LrSpacing.xs),
          Text(context.t('keepsakeMonthPreviewNote'),
              style: text.labelSmall?.copyWith(color: sub)),
          if (onOpenMonth != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenMonth,
                icon: const Icon(Icons.open_in_new, size: 15),
                label: Text(context.t('keepsakeMonthPreviewOpen'),
                    style: text.labelLarge),
              ),
            ),
        ],
      ),
    );
  }

  String _emptyBody(KeepsakeMonthEmptyKind kind) {
    switch (kind) {
      case KeepsakeMonthEmptyKind.noMonth:
        return lrText('keepsakeMonthEmptyBody');
      case KeepsakeMonthEmptyKind.kindHasNone:
        return lrText('keepsakeMonthKindEmptyBody');
      case KeepsakeMonthEmptyKind.noResult:
        return lrText('keepsakeMonthNoResultBody');
      case KeepsakeMonthEmptyKind.none:
        return '';
    }
  }
}
