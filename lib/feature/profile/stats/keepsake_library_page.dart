import 'package:flutter/material.dart';

import '../../../assembly/route_args.dart';
import '../../../assembly/app_scope.dart';
import '../../../core/model/stats/keepsake_calendar_link.dart';
import '../../../core/model/stats/keepsake_query.dart';
import '../../../core/model/stats/keepsakes.dart';
import '../../../core/model/stats/stats_date.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/theme/glass_theme.dart';
import '../../../core/ui/theme/season_scheme.dart';
import '../../../core/ui/components/glass.dart';
import '../../../l10n/lr_localizations.dart';

/// 纪念物册：**完整视图**，一次列出全部命中的纪念物，而不是统计页卡片里的一枚。
///
/// 与摘录管理页同一套纪律：列表每次 build 从 `AppState.keepsakes` 重取，
/// 筛选 / 排序 / 分组 / 计数全部交给 `KeepsakeQuery`；页面不缓存、不自己写 `where`。
/// 类型筛选是页面局部 state，不写回 `AppSettings`，重启不持久化。
class KeepsakeLibraryPage extends StatefulWidget {
  const KeepsakeLibraryPage({
    super.key,
    this.initialKind,
    this.initialMonthKey,
    this.initialDateKey,
    this.onOpenCalendarMonth,
  });

  final KeepsakeKind? initialKind;
  final String? initialMonthKey;

  /// 第二十轮 · 双向深链（日历 → 纪念物册）：只按这一天筛选，
  /// 由 `KeepsakeCalendarLink.toLibraryFromDay` 构造，调用点不散写字段。
  final String? initialDateKey;

  /// 第二十轮 · 双向深链（纪念物册 → 日历）：同一回调传不同强类型 Args，
  /// 分别定位「某一枚所在日」与「当前月份整月」。页面不构造路由。
  final OpenCalendarMonthArgs? onOpenCalendarMonth;

  @override
  State<KeepsakeLibraryPage> createState() => _KeepsakeLibraryPageState();
}

class _KeepsakeLibraryPageState extends State<KeepsakeLibraryPage> {
  late final TextEditingController _controller;
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  late KeepsakeFilter _filter;

  /// 第二十一轮：范围输入的格式错误是局部 UI 状态，不写回设置。
  String? _rangeError;

  /// 本轮 build 归一化后的筛选（失效月份已被清掉）。所有 setter 基于它，
  /// 否则「带进来的月份已不在数据里」时，点一次类型 chip 又会把脏月份带回来。
  /// 在 build 里直接赋值、不触发 setState，只是给回调一个干净的起点。
  KeepsakeFilter _activeFilter = const KeepsakeFilter();
  KeepsakeSort _sort = KeepsakeSort.newest;
  KeepsakeGroup _group = KeepsakeGroup.none;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _fromController = TextEditingController();
    _toController = TextEditingController();
    _filter = KeepsakeFilter(
      kind: widget.initialKind,
      monthKey: widget.initialMonthKey,
      dateKey: widget.initialDateKey,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final SeasonPalette palette = Theme.of(context).extension<LrSeasonTheme>()?.palette ??
        SeasonSchemes.resolve(state.season.value, isDark ? Brightness.dark : Brightness.light);

    // 唯一数据源：不缓存，阅读器新增摘录后本页同一次 build 即可见。
    final List<Keepsake> all = state.keepsakes;
    final List<String> months = KeepsakeQuery.monthKeys(all);

    // 第二十轮：归一化收口到 KeepsakeQuery.normalizeFilter——失效月份清掉、
    // 非法日期清掉、日期与月份不同月时以日期为准修正月份，不静默丢深链。
    final KeepsakeFilter filter = KeepsakeQuery.normalizeFilter(
      _filter,
      availableMonths: months,
    );
    _activeFilter = filter;
    final String? effectiveMonth = filter.monthKey;

    // 分面计数：只去掉类型条件，月份与关键词仍生效。
    final List<KeepsakeKindOption> kinds = KeepsakeQuery.kindOptions(all, filter: filter);
    final KeepsakeSummary summary = KeepsakeQuery.summarize(all);
    final List<Keepsake> results = KeepsakeQuery.apply(
      keepsakes: all,
      filter: filter,
      sort: _sort,
    );
    final Map<String, List<Keepsake>> groups =
        KeepsakeQuery.group(results, by: _group);

    final int kindTotalCount = filter.kind == null
        ? 0
        : KeepsakeQuery.countForKind(all, filter.kind!);
    final int dayTotalCount = filter.dateKey == null
        ? 0
        : KeepsakeQuery.countForDay(all, filter.dateKey!);
    final int rangeTotalCount = KeepsakeQuery.countForRange(
      all,
      from: filter.fromDateKey,
      to: filter.toDateKey,
    );
    final KeepsakeEmptyKind empty = KeepsakeQuery.emptyKind(
      total: all.length,
      matched: results.length,
      filter: filter,
      kindTotalCount: kindTotalCount,
      dayTotalCount: dayTotalCount,
      rangeTotalCount: rangeTotalCount,
    );

    // 第二十一轮：「本月 / 最近 7 天」的基准日只认统计快照的最后一个日期，
    // 不读 DateTime.now()——否则真机时间一变，快捷区间会和热力图 / 日历错月。
    final DateTime baseDay = state.stats.snapshot().days.isEmpty
        ? DateTime.utc(1970, 1, 1)
        : state.stats.snapshot().days.last.date;
    final String baseKey = dateKeyOf(baseDay);
    final DateKeyRange thisMonth =
        monthDateKeyRange(baseDay.year, baseDay.month);
    final String? last7From = dateKeyAddDays(baseKey, -6);

    return Scaffold(
      backgroundColor: isDark ? palette.seed : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(context.t('keepsakeLibraryTitle')),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? <Color>[palette.seed, Color.lerp(palette.seed, Colors.black, 0.35)!]
                : <Color>[palette.seed, Color.lerp(palette.seed, Colors.white, 0.5)!],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(LrSpacing.l, LrSpacing.s, LrSpacing.l, LrSpacing.xxl),
          children: <Widget>[
            GlassPanel(
              borderRadius: LrRadius.pill,
              padding: const EdgeInsets.symmetric(horizontal: LrSpacing.m, vertical: LrSpacing.xs),
              child: Row(
                children: <Widget>[
                  Icon(Icons.search, size: 19, color: text.bodySmall?.color),
                  const SizedBox(width: LrSpacing.s),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: (String v) => setState(
                        () => _filter = _filter.copyWith(query: v.trim()),
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: context.t('uiTitleNoteTypeBook'),
                        hintStyle: text.bodyMedium,
                      ),
                      style: text.bodyMedium,
                    ),
                  ),
                  if (_filter.query.isNotEmpty)
                    GestureDetector(
                      onTap: _clearQuery,
                      child: const Icon(Icons.close, size: 17),
                    ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.s),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LrSpacing.s),
              child: Text(context.t('keepsakeFilterHint'), style: text.labelSmall),
            ),
            const SizedBox(height: LrSpacing.m),

            Text(context.t('uiType'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Wrap(
              spacing: LrSpacing.s,
              runSpacing: LrSpacing.xs,
              children: <Widget>[
                ChoiceChip(
                  label: Text(context.t('keepsakeAllKinds'), style: text.labelLarge),
                  selected: filter.kind == null,
                  onSelected: (bool _) => _setKind(null),
                ),
                for (final KeepsakeKindOption o in kinds)
                  ChoiceChip(
                    label: Text('${o.label} · ${o.count}', style: text.labelLarge),
                    selected: filter.kind == o.kind,
                    onSelected: o.count == 0 ? null : (bool _) => _setKind(o.kind),
                  ),
              ],
            ),
            const SizedBox(height: LrSpacing.m),

            Text(context.t('uiMonth'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Wrap(
              spacing: LrSpacing.s,
              runSpacing: LrSpacing.xs,
              children: <Widget>[
                ChoiceChip(
                  label: Text(context.t('calendarAllMonths'), style: text.labelLarge),
                  selected: effectiveMonth == null,
                  onSelected: (bool _) => _setMonth(null),
                ),
                for (final String m in months)
                  ChoiceChip(
                    label: Text(m, style: text.labelLarge),
                    selected: effectiveMonth == m,
                    onSelected: (bool _) => _setMonth(m),
                  ),
              ],
            ),
            // 第二十一轮：日期范围筛选。两个输入框都走严格 YYYY-MM-DD 校验，
            // 快捷区间只认统计快照的固定基准日；范围与单日 / 整月互斥由
            // KeepsakeQuery.normalizeFilter 统一裁决，页面不自己解释。
            const SizedBox(height: LrSpacing.m),
            Text(context.t('keepsakeDateRangeTitle'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Wrap(
              spacing: LrSpacing.s,
              runSpacing: LrSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ActionChip(
                  label: Text(context.t('keepsakeDateRangeAll'),
                      style: text.labelLarge),
                  onPressed: () => _setRange(null, null),
                ),
                ActionChip(
                  label: Text(context.t('keepsakeDateRangeThisMonth'),
                      style: text.labelLarge),
                  onPressed: () =>
                      _setRange(thisMonth.from, thisMonth.to),
                ),
                if (last7From != null)
                  ActionChip(
                    label: Text(context.t('keepsakeDateRangeLast7'),
                        style: text.labelLarge),
                    onPressed: () => _setRange(last7From, baseKey),
                  ),
              ],
            ),
            const SizedBox(height: LrSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _fromController,
                    keyboardType: TextInputType.datetime,
                    onSubmitted: (String _) => _submitRange(),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: context.t('keepsakeDateRangeHint'),
                      hintStyle: text.bodySmall,
                    ),
                    style: text.bodySmall,
                  ),
                ),
                Text(' ~ ', style: text.labelSmall),
                Expanded(
                  child: TextField(
                    controller: _toController,
                    keyboardType: TextInputType.datetime,
                    onSubmitted: (String _) => _submitRange(),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: context.t('keepsakeDateRangeHint'),
                      hintStyle: text.bodySmall,
                    ),
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
            if (_rangeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_rangeError!, style: text.labelSmall),
              ),
            if (filter.isRangeScoped) ...<Widget>[
              const SizedBox(height: LrSpacing.s),
              Wrap(
                spacing: LrSpacing.s,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  InputChip(
                    label: Text(
                      '${filter.fromDateKey ?? '…'} ~ ${filter.toDateKey ?? '…'}',
                      style: text.labelLarge,
                    ),
                    onDeleted: () => _setRange(null, null),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                  Text(context.t('keepsakeDateRangeFilterNote'),
                      style: text.labelSmall),
                ],
              ),
            ],
            const SizedBox(height: LrSpacing.xs),
            Text(context.t('keepsakeDateRangeNote'), style: text.labelSmall),
            // 第二十轮：按天深链的可见 chip。清除后回到整月，
            // 不把 dateKey 变成看不见的「幽灵筛选条件」。
            if (filter.dateKey != null) ...<Widget>[
              const SizedBox(height: LrSpacing.s),
              Wrap(
                spacing: LrSpacing.s,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  InputChip(
                    label: Text(filter.dateKey!, style: text.labelLarge),
                    onDeleted: () => _setDate(null),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                  Text(context.t('keepsakeDayFilterNote'), style: text.labelSmall),
                ],
              ),
            ],
            // 纪念物册 → 日历：当前月份若合法，可一键回到整月日历。
            if (widget.onOpenCalendarMonth != null) ...<Widget>[
              const SizedBox(height: LrSpacing.s),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final String? month = filter.monthKey ??
                        (filter.dateKey == null
                            ? null
                            : monthKeyOfDateKey(filter.dateKey));
                    final CalendarMonthArgs? args =
                        KeepsakeCalendarLink.toCalendarFromMonth(month);
                    if (args != null) widget.onOpenCalendarMonth!(args);
                  },
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(context.t('keepsakeOpenCalendarMonth'),
                      style: text.labelLarge),
                ),
              ),
            ],
            const SizedBox(height: LrSpacing.m),

            Text(context.t('uiSort'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Wrap(
              spacing: LrSpacing.s,
              children: <Widget>[
                for (final KeepsakeSort s in KeepsakeSort.values)
                  ChoiceChip(
                    label: Text(KeepsakeQuery.sortLabels[s]!, style: text.labelLarge),
                    selected: _sort == s,
                    onSelected: (bool _) => setState(() => _sort = s),
                  ),
              ],
            ),
            const SizedBox(height: LrSpacing.s),
            Text(context.t('uiGroup'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Wrap(
              spacing: LrSpacing.s,
              children: <Widget>[
                for (final KeepsakeGroup g in KeepsakeGroup.values)
                  ChoiceChip(
                    label: Text(KeepsakeQuery.groupLabels[g]!, style: text.labelLarge),
                    selected: _group == g,
                    onSelected: (bool _) => setState(() => _group = g),
                  ),
              ],
            ),
            const SizedBox(height: LrSpacing.m),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LrSpacing.s),
              child: Text(
                context.tArgs('uiTotalKeepsakesItems', <Object?>[summary.total, summary.monthCount]) +
                context.tArgs('uiKeepsakesKeepsakes', <Object?>[summary.userExcerptCount, results.length]),
                style: text.labelSmall,
              ),
            ),
            const SizedBox(height: LrSpacing.s),

            if (empty != KeepsakeEmptyKind.none)
              _EmptyState(kind: empty, filter: filter, onReset: _resetFilter)
            else
              ...groups.entries.map<Widget>(
                (MapEntry<String, List<Keepsake>> e) => _Section(
                      title: e.key,
                      items: e.value,
                      palette: palette,
                      onOpenCalendarDay: widget.onOpenCalendarMonth,
                    ),
              ),

            const SizedBox(height: LrSpacing.l),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(context.t('keepsakeFilterStaticNote'), style: text.bodySmall),
                  const SizedBox(height: LrSpacing.s),
                  Text(context.t('keepsakeWidgetKindNote'), style: text.bodySmall),
                  const SizedBox(height: LrSpacing.s),
                  Text(context.t('demoDataNote'), style: text.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setKind(KeepsakeKind? kind) => setState(
        () => _filter = kind == null
            ? _activeFilter.copyWith(clearKind: true)
            : _activeFilter.copyWith(kind: kind),
      );

  /// 换月份必须同时退出「只看某天」，否则归一化会按日期把月份改回去，
  /// 表现为「点了 10 月没反应」——和前几轮反复修的状态分裂是同一类问题。
  void _setMonth(String? month) => setState(
        () => _filter = month == null
            ? _activeFilter.copyWith(
                clearMonth: true, clearDate: true, clearRange: true)
            : _activeFilter.copyWith(
                monthKey: month, clearDate: true, clearRange: true),
      );

  void _setDate(String? dateKey) => setState(
        () => _filter = dateKey == null
            ? _activeFilter.copyWith(clearDate: true, clearRange: true)
            : _activeFilter.copyWith(
                dateKey: dateKey, clearRange: true),
      );

  /// 第二十一轮：设置范围时清掉单日 / 月份，避免归一化把它们悄悄改回去，
  /// 表现为「范围设了没反应」。clearRange 先清两端，再赋新值——
  /// `copyWith(fromDateKey: null)` 不能表示清空，沿用第十轮显式开关纪律。
  void _setRange(String? from, String? to) {
    _fromController.text = from ?? '';
    _toController.text = to ?? '';
    setState(() {
      _rangeError = null;
      final KeepsakeFilter clean = _activeFilter.copyWith(
        clearRange: true,
        clearDate: true,
        clearMonth: true,
      );
      _filter = (from == null && to == null)
          ? clean
          : clean.copyWith(fromDateKey: from, toDateKey: to);
    });
  }

  /// 手动输入提交：非法端直接拒绝并提示，不把脏 key 塞进筛选。
  /// 两端合法但起 > 止时交给 normalizeDateKeyRange 交换，保留用户意图。
  void _submitRange() {
    final String a = _fromController.text.trim();
    final String b = _toController.text.trim();
    final bool aBad = a.isNotEmpty && tryParseDateKey(a) == null;
    final bool bBad = b.isNotEmpty && tryParseDateKey(b) == null;
    if (aBad || bBad) {
      setState(() => _rangeError = lrText('keepsakeDateRangeInvalid'));
      return;
    }
    _setRange(a.isEmpty ? null : a, b.isEmpty ? null : b);
  }

  void _clearQuery() {
    _controller.clear();
    setState(() => _filter = _activeFilter.copyWith(query: ''));
  }

  void _resetFilter() {
    _controller.clear();
    _fromController.clear();
    _toController.clear();
    setState(() {
      _rangeError = null;
      _filter = const KeepsakeFilter();
    });
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.palette,
    this.onOpenCalendarDay,
  });

  final String title;
  final List<Keepsake> items;
  final SeasonPalette palette;
  final OpenCalendarMonthArgs? onOpenCalendarDay;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LrSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LrSpacing.s),
            child: Text(context.tArgs('uiKeepsakes3', <Object?>[title, items.length]), style: text.titleSmall),
          ),
          const SizedBox(height: LrSpacing.xs),
          for (final Keepsake k in items)
            Padding(
              padding: const EdgeInsets.only(bottom: LrSpacing.s),
              child: _KeepsakeTile(
                keepsake: k,
                palette: palette,
                onOpenCalendarDay: onOpenCalendarDay,
              ),
            ),
        ],
      ),
    );
  }
}

class _KeepsakeTile extends StatelessWidget {
  const _KeepsakeTile({
    required this.keepsake,
    required this.palette,
    this.onOpenCalendarDay,
  });

  final Keepsake keepsake;
  final SeasonPalette palette;
  final OpenCalendarMonthArgs? onOpenCalendarDay;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(LrRadius.card),
            ),
            child: Icon(KeepsakeKindLabels.icons[keepsake.kind],
                size: 19, color: palette.accent),
          ),
          const SizedBox(width: LrSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(keepsake.kindLabel, style: text.labelLarge),
                    const SizedBox(width: LrSpacing.s),
                    Text(dateLabelOf(keepsake.date), style: text.labelSmall),
                    if (keepsake.fromUserExcerpt) ...<Widget>[
                      const SizedBox(width: LrSpacing.s),
                      Text(context.t('uiYours2'), style: text.labelSmall),
                    ],
                  ],
                ),
                const SizedBox(height: LrSpacing.xs),
                Text(keepsake.title, style: text.titleMedium),
                const SizedBox(height: LrSpacing.xs),
                Text(keepsake.detail, style: text.bodySmall),
                if (keepsake.bookTitle != null) ...<Widget>[
                  const SizedBox(height: LrSpacing.xs),
                  Text('《${keepsake.bookTitle}》', style: text.labelSmall),
                ],
                // 纪念物册 → 日历（某一枚所在日）。非法 dateKey 由深链模型
                // 返回 null，按钮直接不渲染，不产生「点了没反应」的入口。
                if (onOpenCalendarDay != null &&
                    KeepsakeCalendarLink.toCalendarFromDay(keepsake.dateKey) !=
                        null) ...<Widget>[
                  const SizedBox(height: LrSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        final CalendarMonthArgs? args =
                            KeepsakeCalendarLink.toCalendarFromDay(
                                keepsake.dateKey);
                        if (args != null) onOpenCalendarDay!(args);
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 15),
                      label: Text(context.t('keepsakeOpenCalendarDay'),
                          style: text.labelLarge),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.kind,
    required this.filter,
    required this.onReset,
  });

  final KeepsakeEmptyKind kind;
  final KeepsakeFilter filter;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool noKeepsakes = kind == KeepsakeEmptyKind.noKeepsakes;
    final bool kindHasNone = kind == KeepsakeEmptyKind.kindHasNone;
    final bool dayHasNone = kind == KeepsakeEmptyKind.dayHasNone;
    final bool rangeHasNone = kind == KeepsakeEmptyKind.rangeHasNone;
    final String title = noKeepsakes
        ? context.t('keepsakeEmptyTitle')
        : (kindHasNone
            ? context.t('keepsakeKindEmptyTitle')
            : (dayHasNone
                ? context.t('keepsakeDayEmptyTitle')
                : (rangeHasNone
                    ? context.t('keepsakeRangeEmptyTitle')
                    : context.t('keepsakeNoResultTitle'))));
    final String body = noKeepsakes
        ? context.t('keepsakeEmptyBody')
        : (kindHasNone
            ? context.t('keepsakeKindEmptyBody')
            : (dayHasNone
                ? context.t('keepsakeDayEmptyBody')
                : (rangeHasNone
                    ? context.t('keepsakeRangeEmptyBody')
                    : context.t('keepsakeNoResultBody'))));
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(LrSpacing.l, LrSpacing.xl, LrSpacing.l, LrSpacing.xl),
      child: Column(
        children: <Widget>[
          Icon(
            (noKeepsakes || kindHasNone || dayHasNone || rangeHasNone)
                ? Icons.auto_awesome_outlined
                : Icons.filter_alt_off_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: LrSpacing.m),
          Text(title, style: text.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: LrSpacing.s),
          Text(body, style: text.bodySmall, textAlign: TextAlign.center),
          if (!noKeepsakes && !filter.isEmpty) ...<Widget>[
            const SizedBox(height: LrSpacing.l),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_outlined, size: 17),
              label: Text(context.t('uiClearFilters')),
            ),
          ],
        ],
      ),
    );
  }
}
