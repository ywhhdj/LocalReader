import 'package:flutter/material.dart';

import '../../core/data/book_repository.dart';
import '../../core/data/demo_document.dart';
import '../../core/router/route_args.dart';
import '../../core/state/app_scope.dart';
import '../../core/stats/excerpt_capture.dart';
import '../../core/stats/keepsakes.dart';
import '../../core/stats/reading_stats.dart';
import '../../core/stats/stats_date.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/theme/season_scheme.dart';
import '../../core/widgets/glass.dart';
import 'keepsake_card.dart';
import '../../core/content/lr_localizations.dart';

/// 阅读统计：今日阅读 / 周热力图 / 阅读日历 / 摘录卡。
///
/// 第八轮起数据全部来自 StatsRepository.snapshot()，页面不再硬编码演示数字；
/// 摘录卡支持环形切换，对应参考仓库「cycle directly to another excerpt」。
/// 小组件配置面板由 app 层注入，feature 之间不互相依赖。
class StatsPage extends StatefulWidget {
  const StatsPage({
    super.key,
    this.onResume,
    this.onOpenWidgetConfig,
    this.onOpenExcerptLibrary,
    this.onOpenCalendarMonth,
    this.onOpenKeepsakeLibrary,
  });

  /// 对应参考仓库「tap a recent book to resume」，由 AppShell 注入。
  final OpenReaderPage? onResume;

  /// 应用内小组件配置入口，由 AppShell 注入。
  final VoidCallback? onOpenWidgetConfig;

  /// 摘录管理页入口，由 AppShell 注入（强类型路由参数）。
  final OpenExcerptLibrary? onOpenExcerptLibrary;

  /// 整月阅读日历入口，由 AppShell 注入（强类型路由参数）。
  final OpenCalendarMonth? onOpenCalendarMonth;

  /// 纪念物册入口，由 AppShell 注入；带上卡片当前的类型 / 月份筛选。
  final OpenKeepsakeLibrary? onOpenKeepsakeLibrary;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  /// 只存索引，不缓存列表：阅读器新增 / 删除摘录后，本页同一次 build 就能看到。
  /// 之前把首次构造的循环器缓存成字段，新摘录要重启页面才出现。
  int _excerptIndex = 0;

  /// 纪念物卡：只存索引 / 月份 / 类型筛选，不缓存列表（第九轮踩过缓存旧列表的坑）。
  /// 类型筛选是页面局部 UI 量，不写回 AppSettings——换 tab 回来保留，重启不持久化，
  /// 与摘录管理页的筛选器同一套纪律。
  int _keepsakeIndex = 0;
  String? _keepsakeMonth;
  KeepsakeKind? _keepsakeKind;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final StatsSnapshot snapshot = state.stats.snapshot();
    final List<Excerpt> excerpts = state.excerpts;
    final List<Keepsake> keepsakes = state.keepsakes;
    final ExcerptCycler cycler = ExcerptCycler(excerpts).select(_excerptIndex);
    final int userExcerptCount = state.userExcerpts.length;

    void cycleNext() => setState(() => _excerptIndex = cycler.next().index);
    void cyclePrevious() =>
        setState(() => _excerptIndex = cycler.previous().index);
    void removeCurrent() {
      final Excerpt? current = cycler.current;
      if (current == null || !current.isUserAdded) return;
      state.removeExcerpt(current.id);
      setState(() => _excerptIndex = 0);
    }

    final BookSummary? recent = state.books.cached.isEmpty
        ? null
        : state.effective(state.books.cached.first);
    final TextTheme text = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final SeasonPalette palette =
        Theme.of(context).extension<LrSeasonTheme>()?.palette ??
            SeasonSchemes.resolve(
              state.season.value,
              isDark ? Brightness.dark : Brightness.light,
            );

    return Container(
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
                  Color.lerp(palette.seed, Colors.white, 0.5)!
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              LrSpacing.l, LrSpacing.xl, LrSpacing.l, 120),
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                    child: Text(context.t('uiReadingStats'),
                        style: text.displayMedium)),
                TextButton.icon(
                  onPressed: () => widget.onOpenExcerptLibrary?.call('', null),
                  icon: const Icon(Icons.format_quote_outlined, size: 17),
                  label: Text(context.t('uiExcerpts'), style: text.labelLarge),
                ),
                const SizedBox(width: LrSpacing.xs),
                TextButton.icon(
                  onPressed: widget.onOpenWidgetConfig,
                  icon:
                      const Icon(Icons.dashboard_customize_outlined, size: 17),
                  label: Text(context.t('uiWidgets'), style: text.labelLarge),
                ),
              ],
            ),
            const SizedBox(height: LrSpacing.xs),
            Text(context.t('uiTurnReadingTimeIntoPagesYouCanFlipBackThrough'),
                style: text.bodyMedium),
            const SizedBox(height: LrSpacing.l),

            // 今日阅读：点最近一本书直接续读（由 AppShell 注入导航）
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                                context.tArgs('uiGoalminutesMinutes',
                                    <Object?>[snapshot]),
                                style: text.labelSmall),
                            const SizedBox(height: LrSpacing.s),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: <Widget>[
                                Text(snapshot.todayLabel,
                                    style: text.displayLarge),
                                const SizedBox(width: LrSpacing.s),
                                Text(context.t('uiMinutes2'),
                                    style: text.titleMedium),
                              ],
                            ),
                            const SizedBox(height: LrSpacing.s),
                            Text(
                              context.tArgs('uiDaysThisWeek', <Object?>[
                                    snapshot.streakDays,
                                    snapshot.weekLabel
                                  ]) +
                                  context.tArgs(
                                      'uiBooksExcerptsItems', <Object?>[
                                    snapshot.totalBooks,
                                    userExcerptCount
                                  ]),
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      _RingProgress(
                          value: snapshot.progress, color: palette.accent),
                    ],
                  ),
                  if (recent != null) ...<Widget>[
                    const SizedBox(height: LrSpacing.s),
                    Divider(
                        color: Theme.of(context).dividerTheme.color, height: 1),
                    const SizedBox(height: LrSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => widget.onResume?.call(
                            recent, DemoDocumentFactory.resumeChapter(recent)),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(
                            context.tArgs(
                                'uiContinueReading2', <Object?>[recent.title]),
                            style: text.labelLarge),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.l),

            // 周热力图：分级口径来自 StatsSnapshot.heatmapLevel
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(context.t('uiReadingHeatmap'),
                          style: text.titleLarge),
                      const Spacer(),
                      Text(
                          context.tArgs(
                              'uiDays3', <Object?>[snapshot.days.length]),
                          style: text.labelSmall),
                    ],
                  ),
                  const SizedBox(height: LrSpacing.m),
                  _Heatmap(days: snapshot.days, accent: palette.accent),
                  const SizedBox(height: LrSpacing.s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(context.t('uiLow'), style: text.labelSmall),
                      ...List<Widget>.generate(
                          5,
                          (int i) => Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  color: i == 0
                                      ? palette.accent.withValues(alpha: 0.06)
                                      : palette.accent.withValues(
                                          alpha: 0.16 + (i - 1) * 0.22),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              )),
                      const SizedBox(width: 4),
                      Text(context.t('uiHigh'), style: text.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.l),

            // 阅读日历：最近 7 天
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(context.t('uiReadingCalendar'),
                          style: text.titleLarge),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: widget.onOpenCalendarMonth == null ||
                                snapshot.days.isEmpty
                            ? null
                            : () => widget.onOpenCalendarMonth!(
                                  snapshot.days.last.date.year,
                                  snapshot.days.last.date.month,
                                ),
                        icon:
                            const Icon(Icons.calendar_month_outlined, size: 16),
                        label: Text(context.t('calendarOpenMonth'),
                            style: text.labelLarge),
                      ),
                    ],
                  ),
                  const SizedBox(height: LrSpacing.m),
                  _CalendarStrip(days: snapshot.calendarWeek),
                  const SizedBox(height: LrSpacing.s),
                  Text(
                    context.tArgs('uiDaysTotalPages', <Object?>[
                      snapshot.totalPages,
                      context.t('demoDataNote')
                    ]),
                    style: text.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.l),

            // 摘录卡：点击卡片或箭头环形切换（cycle to another excerpt）
            GlassPanel(
              tint: <Color>[
                palette.seed.withValues(alpha: 0.85),
                palette.accent.withValues(alpha: 0.12),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(context.t('uiExcerpts2'), style: text.labelSmall),
                      const SizedBox(width: LrSpacing.s),
                      Text(
                          context.tArgs('uiTotalItemsItems',
                              <Object?>[excerpts.length, userExcerptCount]),
                          style: text.labelSmall),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            widget.onOpenExcerptLibrary?.call('', null),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                              horizontal: LrSpacing.s),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child:
                            Text(context.t('uiManage'), style: text.labelLarge),
                      ),
                      if (cycler.hasMultiple)
                        Padding(
                          padding: const EdgeInsets.only(left: LrSpacing.s),
                          child: Text(
                              '${cycler.index + 1} / ${cycler.excerpts.length}',
                              style: text.labelSmall),
                        ),
                    ],
                  ),
                  const SizedBox(height: LrSpacing.m),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: cycler.hasMultiple ? cycleNext : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (cycler.current?.isUserAdded ?? false)
                          Container(
                            width: 3,
                            height: 46,
                            margin: const EdgeInsets.only(right: LrSpacing.m),
                            decoration: BoxDecoration(
                              color: HighlightPalette.spine(
                                  cycler.current!.highlight),
                              borderRadius:
                                  BorderRadius.circular(LrRadius.pill),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            cycler.current?.text ??
                                context.t(
                                    'uiNoExcerptsYetSelectAFewLinesInTheReaderToStart'),
                            style: text.headlineMedium?.copyWith(height: 1.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 批注独立成行，不与原文混排成一个大字号
                  if (cycler.current?.note.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(
                          top: LrSpacing.s, left: LrSpacing.m),
                      child: Text('—— ${cycler.current!.note}',
                          style: text.bodySmall),
                    ),
                  const SizedBox(height: LrSpacing.m),
                  Divider(color: Theme.of(context).dividerTheme.color),
                  const SizedBox(height: LrSpacing.s),
                  Row(
                    children: <Widget>[
                      if (cycler.current?.isUserAdded ?? false)
                        Container(
                          margin: const EdgeInsets.only(right: LrSpacing.s),
                          padding: const EdgeInsets.symmetric(
                              horizontal: LrSpacing.s, vertical: 2),
                          decoration: BoxDecoration(
                            color: HighlightPalette.lineTint(
                                cycler.current!.highlight),
                            borderRadius: BorderRadius.circular(LrRadius.pill),
                          ),
                          child: Text(context.t('uiYours2'),
                              style: text.labelSmall),
                        ),
                      Expanded(
                        child: Text(
                          cycler.current == null
                              ? context.t('uiSampleData')
                              : '《${cycler.current!.bookTitle}》· ${cycler.current!.chapterTitle}',
                          style: text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: context.t('uiPrevious'),
                        onPressed: cycler.hasMultiple ? cyclePrevious : null,
                        icon: const Icon(Icons.chevron_left, size: 19),
                      ),
                      IconButton(
                        tooltip: context.t('uiNextExcerpt'),
                        onPressed: cycler.hasMultiple ? cycleNext : null,
                        icon: const Icon(Icons.chevron_right, size: 19),
                      ),
                      if (cycler.current?.isUserAdded ?? false)
                        IconButton(
                          tooltip: context.t('uiDeleteThisExcerpt'),
                          onPressed: removeCurrent,
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.l),

            // 纪念物卡：数据来自 AppState.keepsakes，按月份归档 + 环形切换
            KeepsakeCard(
              keepsakes: keepsakes,
              palette: palette,
              index: _keepsakeIndex,
              monthFilter: _keepsakeMonth,
              kindFilter: _keepsakeKind,
              onIndexChanged: (int i) => setState(() => _keepsakeIndex = i),
              onMonthChanged: (String? m) => setState(() => _keepsakeMonth = m),
              onKindChanged: (KeepsakeKind? k) =>
                  setState(() => _keepsakeKind = k),
              onOpenLibrary: widget.onOpenKeepsakeLibrary == null
                  ? null
                  : () => widget.onOpenKeepsakeLibrary!(
                        _keepsakeKind,
                        _keepsakeMonth,
                      ),
              onOpenCalendarMonth:
                  widget.onOpenCalendarMonth == null || snapshot.days.isEmpty
                      ? null
                      : () => widget.onOpenCalendarMonth!(
                            snapshot.days.last.date.year,
                            snapshot.days.last.date.month,
                          ),
            ),
            const SizedBox(height: LrSpacing.l),

            // 已配置的小组件摘要：入口由 app 层注入，页面不 import 配置面板
            GestureDetector(
              onTap: widget.onOpenWidgetConfig,
              child: GlassPanel(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.dashboard_customize_outlined,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: LrSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                              context.tArgs('uiItemswidgets',
                                  <Object?>[state.widgetSpecs.length]),
                              style: text.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            state.widgetSpecs
                                .map<String>((WidgetSpec s) =>
                                    WidgetSpecLabels.content[s.content]!)
                                .join(' · '),
                            style: text.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingProgress extends StatelessWidget {
  const _RingProgress({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CircularProgressIndicator(
              value: value,
              strokeWidth: 6,
              backgroundColor: color.withValues(alpha: 0.14),
              color: color),
          Text('${(value * 100).round()}%',
              style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.days, required this.accent});
  final List<ReadingDay> days;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: days.length,
      itemBuilder: (BuildContext context, int i) {
        final int level = StatsSnapshot.heatmapLevel(days[i].minutes);
        return Tooltip(
          message: context
              .tArgs('uiMinutes3', <Object?>[days[i].key, days[i].minutes]),
          child: Container(
            decoration: BoxDecoration(
              color: level == 0
                  ? accent.withValues(alpha: 0.06)
                  : accent.withValues(alpha: 0.16 + (level - 1) * 0.22),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  const _CalendarStrip({required this.days});
  final List<ReadingDay> days;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (int i = 0; i < days.length; i++)
          Column(
            children: <Widget>[
              Text(
                statsWeekdayLabels[
                    (days[i].date.weekday - 1).clamp(0, 6).toInt()],
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: LrSpacing.s),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: days[i].hasRead
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('${days[i].date.day}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
      ],
    );
  }
}
