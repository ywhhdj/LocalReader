import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/data/book_repository.dart';
import 'package:local_reader/core/state/app_scope.dart';
import 'package:local_reader/core/state/app_settings.dart';
import 'package:local_reader/core/stats/excerpt_capture.dart';
import 'package:local_reader/core/stats/keepsakes.dart';
import 'package:local_reader/core/stats/reading_stats.dart';
import 'package:local_reader/core/stats/stats_date.dart';
import 'package:local_reader/core/theme/design_tokens.dart';

StatsSnapshot demo() =>
    DemoStatsRepository(today: DateTime.utc(2026, 11, 9)).snapshot();

List<Keepsake> demoKeepsakes() => KeepsakeCatalog.build(
      snapshot: demo(),
      excerpts: demo().excerpts,
    );

void main() {
  group('stats_date 日期口径单一源', () {
    test('dateKeyOf / monthKeyOf 补零且不随时分秒漂移', () {
      final DateTime d = DateTime.utc(2026, 9, 3, 23, 59);
      expect(dateKeyOf(d), '2026-09-03');
      expect(monthKeyOf(d), '2026-09');
      expect(utcDateOf(d), DateTime.utc(2026, 9, 3));
      expect(monthLabelOf(2026, 9), '2026 年 9 月');
      expect(dateLabelOf(d), '9 月 3 日');
    });

    test('ReadingDay.key 与 dateKeyOf 完全一致', () {
      final ReadingDay d = ReadingDay(date: DateTime.utc(2026, 11, 9), minutes: 46);
      expect(d.key, dateKeyOf(d.date));
      expect(d.key, '2026-11-09');
    });

    test('daysInMonthOf 覆盖闰年与各月月末', () {
      expect(daysInMonthOf(2026, 2), 28);
      expect(daysInMonthOf(2024, 2), 29);
      expect(daysInMonthOf(2026, 12), 31);
      expect(daysInMonthOf(2026, 11), 30);
    });

    test('monthGridOf 固定 42 格且周一起始', () {
      final List<DateTime> grid = monthGridOf(2026, 11);
      expect(grid.length, 42);
      expect(grid.first.weekday, DateTime.monday);
      expect(grid.last.weekday, DateTime.sunday);
      expect(grid.where((DateTime d) => d.month == 11 && d.year == 2026).length, 30);
    });

    test('MonthAnchor 跨年平移与月份序号', () {
      expect(MonthAnchor(2026, 12).shift(1), const MonthAnchor(2027, 1));
      expect(MonthAnchor(2026, 1).shift(-1), const MonthAnchor(2025, 12));
      expect(MonthAnchor(2026, 11).label, '2026 年 11 月');
      expect(MonthAnchor(2026, 11).key, '2026-11');
      expect(MonthAnchor.fromDate(DateTime.utc(2026, 10, 6)).index,
          lessThan(MonthAnchor(2026, 11).index));
    });

    test('statsWeekdayLabels 周一起始共 7 项', () {
      expect(statsWeekdayLabels.length, 7);
      expect(statsWeekdayLabels.first, '一');
      expect(statsWeekdayLabels.last, '日');
    });
  });

  group('KeepsakeCatalog 生成规则', () {
    test('演示数据只按规则生成，不手写演示条目', () {
      final List<Keepsake> items = demoKeepsakes();
      final Map<KeepsakeKind, int> counts = KeepsakeCatalog.countByKind(items);
      expect(counts[KeepsakeKind.firstRead], 1);
      expect(counts[KeepsakeKind.streak], 0, reason: '演示最长连续段只有 5 天，不到 7 天里程碑');
      expect(counts[KeepsakeKind.monthlyBest], 2);
      expect(counts[KeepsakeKind.goalReached], 2);
      expect(counts[KeepsakeKind.excerpt], 4);
      expect(counts[KeepsakeKind.monthly], 2);
      expect(items.length, 11);
    });

    test('按日期降序，同日按类型稳定', () {
      final List<Keepsake> items = demoKeepsakes();
      for (int i = 1; i < items.length; i++) {
        expect(
          items[i - 1].dateKey.compareTo(items[i].dateKey),
          greaterThanOrEqualTo(0),
        );
      }
      expect(items.first.dateKey, greaterThanOrEqualTo(items.last.dateKey));
    });

    test('连续 7 天生成 streak，8 天仍只生成 1 枚里程碑', () {
      final StatsSnapshot s = StatsSnapshot(
        today: 10,
        goalMinutes: 60,
        days: <ReadingDay>[
          for (int i = 0; i < 8; i++)
            ReadingDay(date: DateTime.utc(2026, 3, 1 + i), minutes: 10),
        ],
        excerpts: const <Excerpt>[],
        totalBooks: 1,
      );
      final List<Keepsake> items = KeepsakeCatalog.build(
        snapshot: s,
        excerpts: const <Excerpt>[],
      );
      final List<Keepsake> streaks = items
          .where((Keepsake k) => k.kind == KeepsakeKind.streak)
          .toList();
      expect(streaks.length, 1);
      expect(streaks.single.value, 7);
      expect(streaks.single.dateKey, '2026-03-07');
    });

    test('目标为 0 时不生成达标纪念物', () {
      final StatsSnapshot s = StatsSnapshot(
        today: 10,
        goalMinutes: 0,
        days: <ReadingDay>[ReadingDay(date: DateTime.utc(2026, 5, 1), minutes: 90)],
        excerpts: const <Excerpt>[],
        totalBooks: 0,
      );
      final List<Keepsake> items = KeepsakeCatalog.build(
        snapshot: s,
        excerpts: const <Excerpt>[],
      );
      expect(items.where((Keepsake k) => k.kind == KeepsakeKind.goalReached), isEmpty);
      expect(items.where((Keepsake k) => k.kind == KeepsakeKind.monthlyBest).length, 1);
    });

    test('空快照返回空列表，不崩溃', () {
      final StatsSnapshot s = const StatsSnapshot(
        today: 0,
        goalMinutes: 0,
        days: <ReadingDay>[],
        excerpts: <Excerpt>[],
        totalBooks: 0,
      );
      expect(KeepsakeCatalog.build(snapshot: s, excerpts: const <Excerpt>[]), isEmpty);
      expect(KeepsakeCatalog.monthKeys(<Keepsake>[]), isEmpty);
    });

    test('byMonth / monthKeys / forMonth 一致，月份降序', () {
      final List<Keepsake> items = demoKeepsakes();
      final Map<String, List<Keepsake>> grouped = KeepsakeCatalog.byMonth(items);
      expect(grouped.keys.toSet(), <String>{'2026-10', '2026-11'});
      expect(KeepsakeCatalog.monthKeys(items), <String>['2026-11', '2026-10']);
      expect(
        KeepsakeCatalog.forMonth(items, '2026-11').length,
        grouped['2026-11']!.length,
      );
      expect(KeepsakeCatalog.forMonth(items, '1999-01'), isEmpty);
    });

    test('季节样式由调用方注入，五种都可用', () {
      for (final SeasonStyle s in SeasonStyle.values) {
        final List<Keepsake> items = KeepsakeCatalog.build(
          snapshot: demo(),
          excerpts: demo().excerpts,
          season: s,
        );
        expect(items, isNotEmpty);
        expect(items.every((Keepsake k) => k.season == s), isTrue);
      }
    });

    test('摘录纪念物带书名与用户标记', () {
      final StatsSnapshot s = demo();
      final Excerpt e = s.excerpts.first.copyWith(isUserAdded: true);
      final List<Keepsake> items = KeepsakeCatalog.build(
        snapshot: s,
        excerpts: <Excerpt>[e],
      );
      final Keepsake k = items.firstWhere(
        (Keepsake k) => k.kind == KeepsakeKind.excerpt && k.bookId == e.bookId,
      );
      expect(k.id, 'k-excerpt-${e.id}');
      expect(k.bookTitle, e.bookTitle);
      expect(k.fromUserExcerpt, isTrue);
      expect(k.dateKey, dateKeyOf(e.capturedAt));
    });

    test('Keepsake toMap / fromMap 往返，未知枚举回退', () {
      final Keepsake k = demoKeepsakes().first;
      expect(Keepsake.fromMap(k.toMap()), k);
      final Keepsake fallback = Keepsake.fromMap(<dynamic, dynamic>{
        'id': 'x',
        'kind': 'unknown',
        'date': '2026-11-09',
        'season': 'unknown',
      });
      expect(fallback.kind, KeepsakeKind.firstRead);
      expect(fallback.season, SeasonStyle.paper);
      expect(fallback.date, DateTime.utc(2026, 11, 9));
      expect(fallback.bookId, isNull);
    });

    test('六种类型都有标签与图标', () {
      expect(KeepsakeKindLabels.labels.length, KeepsakeKind.values.length);
      expect(KeepsakeKindLabels.icons.length, KeepsakeKind.values.length);
    });
  });

  group('KeepsakeCycler 环形切换', () {
    test('next 到末尾回到第一条', () {
      final List<Keepsake> items = demoKeepsakes();
      KeepsakeCycler c = KeepsakeCycler(items);
      for (int i = 0; i < items.length; i++) {
        c = c.next();
      }
      expect(c.index, 0);
      expect(c.current!.id, items.first.id);
    });

    test('previous 从 0 回到最后，select 越界夹住', () {
      final List<Keepsake> items = demoKeepsakes();
      expect(KeepsakeCycler(items).previous().index, items.length - 1);
      expect(KeepsakeCycler(items).select(99).index, items.length - 1);
      expect(KeepsakeCycler(items).select(-5).index, 0);
    });

    test('空列表不崩溃', () {
      final KeepsakeCycler c = KeepsakeCycler(const <Keepsake>[]);
      expect(c.isEmpty, isTrue);
      expect(c.hasMultiple, isFalse);
      expect(c.current, isNull);
      expect(c.next().index, 0);
    });
  });

  group('CalendarMonth 月度网格', () {
    test('11 月固定 42 格、30 个本月格、周一起始', () {
      final CalendarMonth m = CalendarMonth.build(
        snapshot: demo(),
        keepsakes: demoKeepsakes(),
        excerpts: demo().excerpts,
        year: 2026,
        month: 11,
      );
      expect(m.cells.length, 42);
      expect(m.cells.first.date.weekday, DateTime.monday);
      expect(m.cells.where((CalendarCell c) => c.inMonth).length, 30);
      expect(m.label, '2026 年 11 月');
      expect(m.monthKey, '2026-11');
    });

    test('月度合计只取本月数据，跨月补格不计数', () {
      final StatsSnapshot s = demo();
      final CalendarMonth m = CalendarMonth.build(
        snapshot: s,
        keepsakes: demoKeepsakes(),
        excerpts: s.excerpts,
        year: 2026,
        month: 11,
      );
      final List<ReadingDay> nov = s.days
          .where((ReadingDay d) => d.date.year == 2026 && d.date.month == 11)
          .toList();
      expect(m.totalMinutes, nov.fold<int>(0, (int a, ReadingDay d) => a + d.minutes));
      expect(m.readDays, nov.where((ReadingDay d) => d.hasRead).length);
      expect(m.totalMinutes, greaterThan(0));
      expect(m.cells.where((CalendarCell c) => !c.inMonth), isNotEmpty);
      // 补格即便撞上真实数据也不参与合计：11 月合计不含 10 月的分钟数。
      final int octTotal = s.days
          .where((ReadingDay d) => d.date.month == 10)
          .fold<int>(0, (int a, ReadingDay d) => a + d.minutes);
      expect(m.totalMinutes, isNot(octTotal));
    });

    test('月份边界：10 月可向后、11 月可向前、9 月越界', () {
      CalendarMonth build(int y, int mo) => CalendarMonth.build(
            snapshot: demo(),
            keepsakes: demoKeepsakes(),
            excerpts: demo().excerpts,
            year: y,
            month: mo,
          );
      expect(build(2026, 10).canPrev, isFalse);
      expect(build(2026, 10).canNext, isTrue);
      expect(build(2026, 11).canPrev, isTrue);
      expect(build(2026, 11).canNext, isFalse);
      expect(build(2026, 9).inRange, isFalse);
      expect(build(2026, 10).inRange, isTrue);
    });

    test('今天格标记与 cellFor', () {
      final CalendarMonth m = CalendarMonth.build(
        snapshot: demo(),
        keepsakes: demoKeepsakes(),
        excerpts: demo().excerpts,
        year: 2026,
        month: 11,
      );
      expect(m.todayKey, '2026-11-09');
      final CalendarCell? today = m.cellFor(m.todayKey);
      expect(today, isNotNull);
      expect(today!.isToday, isTrue);
      expect(today.inMonth, isTrue);
      expect(today.minutes, 46);
      expect(today.level, StatsSnapshot.heatmapLevel(46));
      expect(m.cellFor('1900-01-01'), isNull);
    });

    test('当天纪念物与摘录挂到对应格子', () {
      final StatsSnapshot s = demo();
      final CalendarMonth m = CalendarMonth.build(
        snapshot: s,
        keepsakes: demoKeepsakes(),
        excerpts: s.excerpts,
        year: 2026,
        month: 11,
      );
      final CalendarCell e1 = m.cellFor('2026-11-08')!;
      expect(e1.hasKeepsake, isTrue);
      expect(e1.hasExcerpt, isTrue);
      expect(e1.keepsakes.any((Keepsake k) => k.kind == KeepsakeKind.excerpt), isTrue);
      expect(m.keepsakeCount, greaterThan(0));
      expect(m.excerptCount, greaterThan(0));
    });

    test('calendarDaySummary：有阅读 / 只有摘录 / 完全空白三种口径', () {
      final StatsSnapshot s = demo();
      final CalendarMonth m = CalendarMonth.build(
        snapshot: s,
        keepsakes: demoKeepsakes(),
        excerpts: s.excerpts,
        year: 2026,
        month: 11,
      );
      final CalendarCell read = m.cellFor('2026-11-09')!;
      expect(calendarDaySummary(read), contains('46 分钟'));
      expect(calendarDaySummary(read), contains('热力'));

      final CalendarCell blank = m.cells.firstWhere(
        (CalendarCell c) => !c.inMonth && !c.hasRead && !c.hasKeepsake && !c.hasExcerpt,
      );
      expect(calendarDaySummary(blank), contains('这一天还没有阅读记录'));
    });

    test('空快照不崩溃，边界标志均为 false', () {
      const StatsSnapshot s = StatsSnapshot(
        today: 0,
        goalMinutes: 0,
        days: <ReadingDay>[],
        excerpts: <Excerpt>[],
        totalBooks: 0,
      );
      final CalendarMonth m = CalendarMonth.build(
        snapshot: s,
        keepsakes: const <Keepsake>[],
        excerpts: const <Excerpt>[],
      );
      expect(m.cells.length, 42);
      expect(m.totalMinutes, 0);
      expect(m.readDays, 0);
      expect(m.canPrev, isFalse);
      expect(m.canNext, isFalse);
      expect(m.todayKey, isEmpty);
    });
  });

  group('CalendarMonthNavigator 翻页', () {
    CalendarMonthNavigator nav() => CalendarMonthNavigator(
          first: const MonthAnchor(2026, 10),
          last: const MonthAnchor(2026, 11),
          current: const MonthAnchor(2026, 11),
        );

    test('prev / next 夹在演示数据范围内', () {
      final CalendarMonthNavigator n = nav();
      expect(n.canPrev, isTrue);
      expect(n.canNext, isFalse);
      expect(n.prev().current, const MonthAnchor(2026, 10));
      expect(n.prev().prev().current, const MonthAnchor(2026, 10));
      expect(n.next().current, const MonthAnchor(2026, 11));
    });

    test('shift 大幅越界被夹住，jumpToThisMonth 回到最后一个月', () {
      expect(nav().shift(-99).current, const MonthAnchor(2026, 10));
      expect(nav().shift(99).current, const MonthAnchor(2026, 11));
      expect(nav().prev().jumpToThisMonth().current, const MonthAnchor(2026, 11));
    });
  });

  group('小组件内容新增纪念物档', () {
    test('标签与图标覆盖全部枚举，旧断言不失效', () {
      expect(WidgetSpecLabels.content.length, WidgetContent.values.length);
      expect(WidgetSpecLabels.icon.length, WidgetContent.values.length);
      expect(WidgetSpecLabels.content[WidgetContent.keepsake], '纪念物');
      expect(WidgetSpecLabels.icon[WidgetContent.keepsake], isNotNull);
    });

    test('keepsake 档可序列化往返', () {
      const WidgetSpec s = WidgetSpec(id: 'w', content: WidgetContent.keepsake);
      expect(WidgetSpec.fromMap(s.toMap()), s);
    });
  });

  group('AppState 纪念物出口', () {
    AppState make() => AppState(
          settingsStore: InMemorySettingsStore(),
          books: const DemoBookRepository(),
        );

    ExcerptDraft draft() => const ExcerptDraft(
          bookId: 'b01',
          chapterIndex: 0,
          pageIndex: 0,
          text: '这是刚摘下的一句话。',
          signature: '这是刚摘下的一句话',
          highlight: HighlightColor.amber,
        );

    test('初始数量与规则一致，每次读取都重算', () {
      final AppState s = make();
      expect(s.keepsakeCount, 11);
      expect(identical(s.keepsakes, s.keepsakes), isFalse,
          reason: '不得缓存成字段，否则新增摘录不即时出现');
      expect(s.keepsakesByMonth.keys.toSet(), <String>{'2026-10', '2026-11'});
    });

    test('阅读器新增摘录后纪念物即时出现，删除后即时消失', () {
      final AppState s = make();
      final Excerpt? added = s.addExcerpt(
        draft(),
        bookTitle: '雪国的旅行者',
        chapterTitle: '第一章',
        capturedAt: DateTime.utc(2026, 11, 9),
      );
      expect(added, isNotNull);
      expect(s.keepsakeCount, 12);
      final Keepsake k = s.keepsakes.firstWhere(
        (Keepsake k) => k.id == 'k-excerpt-${added!.id}',
      );
      expect(k.fromUserExcerpt, isTrue);
      expect(k.bookTitle, '雪国的旅行者');
      expect(s.removeExcerpt(added!.id), isTrue);
      expect(s.keepsakeCount, 11);
    });

    test('季节换肤即时反映到纪念物配色', () {
      final AppState s = make();
      s.setSeason(SeasonStyle.sakura);
      expect(s.keepsakes.every((Keepsake k) => k.season == SeasonStyle.sakura), isTrue);
      s.setSeason(SeasonStyle.winter);
      expect(s.keepsakes.every((Keepsake k) => k.season == SeasonStyle.winter), isTrue);
    });

    test('纪念物统计不改变纯本地 master switch', () {
      final AppState s = make();
      s.addExcerpt(
        draft(),
        bookTitle: '雪国的旅行者',
        chapterTitle: '第一章',
      );
      expect(s.settings.pureLocal, isTrue);
      expect(s.networkingAllowed, isFalse);
    });
  });
}
