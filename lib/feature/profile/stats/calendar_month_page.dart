import 'package:flutter/material.dart';

import '../../../assembly/route_args.dart';
import '../../../assembly/app_scope.dart';
import '../../../core/model/stats/calendar_day_link.dart';
import '../../../core/model/stats/keepsake_calendar_link.dart';
import '../../../core/model/stats/keepsakes.dart';
import '../../../core/model/stats/reading_stats.dart';
import '../../../core/model/stats/stats_date.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/theme/glass_theme.dart';
import '../../../core/ui/theme/season_scheme.dart';
import '../../../core/ui/components/glass.dart';
import '../../../l10n/lr_localizations.dart';

/// 阅读日历 · 整月：月份翻页、6 周热力网格、点某天看当日详情。
///
/// 数据全部由 `CalendarMonth.build()` 从 `StatsSnapshot` / `AppState.keepsakes`
/// / `AppState.excerpts` 聚合，页面不缓存、不硬编码演示数字。
/// 跨月补格只用于对齐周起始，不计入月度合计（见 LegalTexts.calendarStaticNote）。
class CalendarMonthPage extends StatefulWidget {
  const CalendarMonthPage({
    super.key,
    required this.args,
    this.onOpenKeepsakeLibrary,
    this.onOpenDayExcerpts,
  });

  final CalendarMonthArgs args;

  /// 第二十轮 · 双向深链（日历 → 纪念物册）：只把强类型 Args 交给 app 层，
  /// 页面不构造路由、不 import 另一个 feature。
  final OpenKeepsakeLibraryArgs? onOpenKeepsakeLibrary;

  /// 第二十一轮 · 日历选中日 → 摘录管理页「只看这一天摘下的话」。
  /// 与上一条共用 `CalendarDayLink` 的跨月补格 / 非法日期禁用判据。
  final OpenExcerptLibraryArgs? onOpenDayExcerpts;

  @override
  State<CalendarMonthPage> createState() => _CalendarMonthPageState();
}

class _CalendarMonthPageState extends State<CalendarMonthPage> {
  int? _year;
  int? _month;
  String? _selectedKey;
  bool _ignoreArgsSelection = false;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final StatsSnapshot snapshot = state.stats.snapshot();
    final List<Keepsake> keepsakes = state.keepsakes;
    final List<Excerpt> excerpts = state.excerpts;
    final TextTheme text = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final SeasonPalette palette = Theme.of(context).extension<LrSeasonTheme>()?.palette ??
        SeasonSchemes.resolve(
          state.season.value,
          isDark ? Brightness.dark : Brightness.light,
        );

    final MonthAnchor first = snapshot.days.isEmpty
        ? const MonthAnchor(1970, 1)
        : MonthAnchor.fromDate(snapshot.days.first.date);
    final MonthAnchor last = snapshot.days.isEmpty
        ? const MonthAnchor(1970, 1)
        : MonthAnchor.fromDate(snapshot.days.last.date);
    final MonthAnchor current = (_year != null && _month != null)
        ? MonthAnchor(_year!, _month!)
        : MonthAnchor(
            widget.args.year ?? last.year,
            widget.args.month ?? last.month,
          );
    final CalendarMonthNavigator nav = CalendarMonthNavigator(
      first: first,
      last: last,
      current: current,
    );
    final CalendarMonth month = CalendarMonth.build(
      snapshot: snapshot,
      keepsakes: keepsakes,
      excerpts: excerpts,
      year: current.year,
      month: current.month,
    );

    // 默认选中今天（若今天不在本月则回退到本月第一个有记录的格子）。
    // 手写查找，避免引入任何集合扩展依赖。
    final CalendarCell? todayCell = month.cellFor(month.todayKey);
    String? fallbackKey;
    if (todayCell == null || !todayCell.inMonth) {
      for (final CalendarCell c in month.cells) {
        if (c.inMonth && c.hasRead) {
          fallbackKey = c.key;
          break;
        }
      }
    }
    final String? defaultKey =
        (todayCell != null && todayCell.inMonth) ? month.todayKey : fallbackKey;
    final String? argKey = _ignoreArgsSelection ? null : widget.args.selectedDateKey;
    // 第二十轮：两个方向的深链都由 KeepsakeCalendarLink 构造并校验。
    final OpenKeepsakeLibraryArgs? openLibrary = widget.onOpenKeepsakeLibrary;
    final KeepsakeLibraryArgs? monthArgs =
        KeepsakeCalendarLink.toLibraryFromMonth(month.monthKey);
    final OpenExcerptLibraryArgs? openDayExcerpts = widget.onOpenDayExcerpts;
    final String? selectedKey = _selectedKey ?? argKey ?? defaultKey;
    final CalendarCell? selected =
        selectedKey == null ? null : month.cellFor(selectedKey);

    void goTo(CalendarMonthNavigator next) {
      setState(() {
        _year = next.current.year;
        _month = next.current.month;
        _selectedKey = null;
        _ignoreArgsSelection = true; // 翻月后不再沿用深链传来的选中日
      });
    }

    return Scaffold(
      backgroundColor: isDark ? palette.seed : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(context.t('calendarMonthTitle')),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? <Color>[palette.seed, Color.lerp(palette.seed, Colors.black, 0.35)!]
                : <Color>[palette.seed, Color.lerp(palette.seed, Colors.white, 0.55)!],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(LrSpacing.l, LrSpacing.s, LrSpacing.l, 120),
          children: <Widget>[
            // 月份切换
            GlassPanel(
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: context.t('uiPreviousMonth'),
                    onPressed: nav.canPrev ? () => goTo(nav.prev()) : null,
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      month.label,
                      textAlign: TextAlign.center,
                      style: text.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('uiNextMonth'),
                    onPressed: nav.canNext ? () => goTo(nav.next()) : null,
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                  const SizedBox(width: LrSpacing.s),
                  TextButton(
                    onPressed: () => goTo(nav.jumpToThisMonth()),
                    child: Text(context.t('calendarBackToThisMonth'), style: text.labelLarge),
                  ),
                ],
              ),
            ),
            if (!nav.canPrev && !nav.canNext)
              Padding(
                padding: const EdgeInsets.only(top: LrSpacing.s),
                child:
                    Text(context.t('calendarOutOfRangeNote'), style: text.labelSmall),
              ),
            const SizedBox(height: LrSpacing.m),

            // 月度汇总：全部来自 CalendarMonth 聚合
            GlassPanel(
              child: Row(
                children: <Widget>[
                  _StatTile(
                    text: text,
                    label: context.t('uiThisMonth2'),
                    value: StatsSnapshot.formatMinutes(month.totalMinutes),
                  ),
                  _StatTile(text: text, label: context.t('uiReadingDays'), value: context.tArgs('uiDays2', <Object?>[month.readDays])),
                  _StatTile(text: text, label: context.t('uiKeepsakes'), value: context.tArgs('uiKeepsakes2', <Object?>[month.keepsakeCount])),
                  _StatTile(text: text, label: context.t('uiExcerpts'), value: context.tArgs('uiItems10', <Object?>[month.excerptCount])),
                ],
              ),
            ),
            if (openLibrary != null && monthArgs != null) ...<Widget>[
              const SizedBox(height: LrSpacing.s),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openLibrary(monthArgs),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                  label: Text(context.t('calendarOpenMonthKeepsakes'),
                      style: text.labelLarge),
                ),
              ),
            ],
            const SizedBox(height: LrSpacing.m),

            // 周一起始标签 + 6×7 网格
            GlassPanel(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      for (final String w in statsWeekdayLabels)
                        Expanded(
                          child: Text(w, textAlign: TextAlign.center, style: text.labelSmall),
                        ),
                    ],
                  ),
                  const SizedBox(height: LrSpacing.s),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: month.cells.length,
                    itemBuilder: (BuildContext context, int i) {
                      final CalendarCell cell = month.cells[i];
                      final bool isSelected = cell.key == selectedKey;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedKey = cell.key),
                        child: Tooltip(
                          message: calendarDaySummary(cell),
                          child: _DayCell(
                            cell: cell,
                            accent: palette.accent,
                            selected: isSelected,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: LrSpacing.s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(context.t('uiLow'), style: text.labelSmall),
                      ...List<Widget>.generate(5, (int i) => Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: i == 0
                                  ? palette.accent.withOpacity(0.06)
                                  : palette.accent.withOpacity(0.16 + (i - 1) * 0.22),
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
            const SizedBox(height: LrSpacing.m),

            // 选中日详情
            if (selected != null) ...<Widget>[
              _DayDetail(
                cell: selected,
                palette: palette,
                onOpenKeepsakes: openLibrary == null
                    ? null
                    : () {
                        final KeepsakeLibraryArgs? args =
                            KeepsakeCalendarLink.toLibraryFromDay(
                          dateKey: selected.key,
                          inMonth: selected.inMonth,
                        );
                        if (args != null) openLibrary(args);
                      },
                dayLinkEnabled: CalendarDayLink.isValidDay(
                  selected.key,
                  inMonth: selected.inMonth,
                ),
                onOpenDayExcerpts: openDayExcerpts == null
                    ? null
                    : () {
                        final String? key = CalendarDayLink.normalizedDateKey(
                          selected.key,
                          inMonth: selected.inMonth,
                        );
                        final ExcerptLibraryArgs args =
                            ExcerptLibraryArgs.fromDay(key);
                        if (args.isDayScoped) openDayExcerpts(args);
                      },
              ),
              const SizedBox(height: LrSpacing.m),
            ],

            Text(context.t('calendarStaticNote'), style: text.bodySmall),
            const SizedBox(height: LrSpacing.s),
            Text(context.t('demoDataNote'), style: text.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.text, required this.label, required this.value});

  final TextTheme text;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: <Widget>[
            Text(label, style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Text(
              value,
              style: text.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.cell,
    required this.accent,
    required this.selected,
  });

  final CalendarCell cell;
  final Color accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color base = cell.level == 0
        ? accent.withOpacity(0.06)
        : accent.withOpacity(0.16 + (cell.level - 1) * 0.22);
    return Container(
      decoration: BoxDecoration(
        color: cell.inMonth ? base : base.withOpacity(0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? accent
              : (cell.isToday ? accent.withOpacity(0.55) : Colors.transparent),
          width: selected ? 2 : 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Text(
            '${cell.date.day}',
            style: text.bodySmall?.copyWith(
              color: cell.inMonth ? null : text.bodySmall?.color?.withOpacity(0.45),
              fontWeight: cell.isToday ? FontWeight.bold : null,
            ),
          ),
          if (cell.hasKeepsake || cell.hasExcerpt)
            Positioned(
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (cell.hasKeepsake)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (cell.hasExcerpt)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.cell,
    required this.palette,
    this.onOpenKeepsakes,
    this.dayLinkEnabled = false,
    this.onOpenDayExcerpts,
  });

  final CalendarCell cell;
  final SeasonPalette palette;
  final VoidCallback? onOpenKeepsakes;
  final bool dayLinkEnabled;
  final VoidCallback? onOpenDayExcerpts;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool empty = !cell.hasRead && !cell.hasKeepsake && !cell.hasExcerpt;
    return GlassPanel(
      tint: <Color>[
        palette.seed.withOpacity(0.85),
        palette.accent.withOpacity(0.12),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('${dateLabelOf(cell.date)} · ${cell.key}', style: text.titleMedium),
              const Spacer(),
              if (!cell.inMonth) Text(context.t('uiAdjacentMonthCells'), style: text.labelSmall),
            ],
          ),
          const SizedBox(height: LrSpacing.s),
          Text(calendarDaySummary(cell), style: text.bodySmall),
          if (empty) ...<Widget>[
            const SizedBox(height: LrSpacing.s),
            Text(context.t('calendarNoRecordNote'), style: text.labelSmall),
          ],
          if (cell.keepsakes.isNotEmpty) ...<Widget>[
            const SizedBox(height: LrSpacing.m),
            Text(context.t('uiKeepsakesThatDay'), style: text.labelLarge),
            const SizedBox(height: LrSpacing.s),
            ...cell.keepsakes.map<Widget>(
              (Keepsake k) => Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Icon(
                      KeepsakeKindLabels.icons[k.kind],
                      size: 16,
                      color: palette.accent,
                    ),
                    const SizedBox(width: LrSpacing.s),
                    Expanded(
                      child: Text(
                        '${k.kindLabel} · ${k.title}',
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // 第二十轮：日历 → 纪念物册（当天）；第二十一轮：日历 → 摘录（当天）。
          // 两条按钮共用 CalendarDayLink 的禁用判据与说明，不会一个禁用、
          // 另一个却把非法日期塞进路由。跨月补格只用于对齐周起始。
          if (onOpenKeepsakes != null || onOpenDayExcerpts != null) ...<Widget>[
            const SizedBox(height: LrSpacing.m),
            Wrap(
              spacing: LrSpacing.s,
              children: <Widget>[
                if (onOpenKeepsakes != null)
                  TextButton.icon(
                    onPressed: dayLinkEnabled ? onOpenKeepsakes : null,
                    icon: const Icon(Icons.open_in_new, size: 15),
                    label: Text(context.t('calendarOpenDayKeepsakes'),
                        style: text.labelLarge),
                  ),
                if (onOpenDayExcerpts != null)
                  TextButton.icon(
                    onPressed: dayLinkEnabled ? onOpenDayExcerpts : null,
                    icon: const Icon(Icons.format_quote_outlined, size: 15),
                    label: Text(context.t('calendarOpenDayExcerpts'),
                        style: text.labelLarge),
                  ),
              ],
            ),
            if (!dayLinkEnabled)
              Text(
                CalendarDayLink.noteFor(
                  inMonth: cell.inMonth,
                  dateKey: cell.key,
                ),
                style: text.labelSmall,
              ),
          ],
          if (cell.excerpts.isNotEmpty) ...<Widget>[
            const SizedBox(height: LrSpacing.m),
            Text(context.t('uiExcerptsThatDay'), style: text.labelLarge),
            const SizedBox(height: LrSpacing.s),
            ...cell.excerpts.map<Widget>(
              (Excerpt e) => Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.xs),
                child: Text(
                  '《${e.bookTitle}》 ${e.text}',
                  style: text.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
