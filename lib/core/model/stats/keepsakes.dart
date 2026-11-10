import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../common/design_tokens.dart';
import 'keepsake_kind.dart';
import 'reading_stats.dart';
import 'stats_date.dart';

export 'keepsake_kind.dart';

/// 纪念物卡（keepsakes）与阅读日历月度详情的纯 Dart 模型。
///
/// 参考仓库 README：「今日阅读、周热力图、阅读日历、**纪念物**、摘录卡，
/// 五种视觉样式包括季节手账」「点统计卡片打开阅读统计、点最近书续读、直接换到另一条摘录」。
///
/// 前几轮已落今日 / 热力 / 7 天条 / 摘录卡，本轮补上**完整月度日历**与**纪念物卡**。
///
/// **静态边界**：所有数字都从 `StatsSnapshot.days` 与 `AppState.excerpts` 聚合，
/// 不硬编码演示天数、不读数据库、不联网、不落盘；演示数据仍用固定基准日。
/// 日期口径统一走 `stats_date.dart`，五种季节手账由调用方注入 `SeasonStyle`。

// ---------------------------------------------------------------- 纪念物

@immutable
class Keepsake {
  const Keepsake({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.date,
    this.value = 0,
    this.season = SeasonStyle.paper,
    this.bookId,
    this.bookTitle,
    this.fromUserExcerpt = false,
  });

  final String id;
  final KeepsakeKind kind;
  final String title;
  final String detail;
  final DateTime date;
  final int value;
  final SeasonStyle season;
  final String? bookId;
  final String? bookTitle;

  /// 来自阅读器采集的摘录（而非演示种子），卡片上会标「你摘的」。
  final bool fromUserExcerpt;

  String get dateKey => dateKeyOf(date);
  String get monthKey => monthKeyOf(date);
  String get kindLabel => KeepsakeKindLabels.labels[kind]!;

  Map<String, Object> toMap() => <String, Object>{
        'id': id,
        'kind': kind.name,
        'title': title,
        'detail': detail,
        'date': dateKey,
        'value': value,
        'season': season.name,
        'bookId': bookId ?? '',
        'bookTitle': bookTitle ?? '',
        'fromUserExcerpt': fromUserExcerpt,
      };

  static Keepsake fromMap(Map<dynamic, dynamic> m) {
    final String key = m['date'] is String ? m['date'] as String : '1970-01-01';
    final List<int> parts = key.split('-').map(int.tryParse).whereType<int>().toList();
    final DateTime date = parts.length == 3
        ? DateTime.utc(parts[0], parts[1], parts[2])
        : DateTime.utc(1970, 1, 1);
    return Keepsake(
      id: m['id'] is String ? m['id'] as String : 'k',
      kind: _enum<KeepsakeKind>(m['kind'], KeepsakeKind.values, KeepsakeKind.firstRead),
      title: m['title'] is String ? m['title'] as String : '',
      detail: m['detail'] is String ? m['detail'] as String : '',
      date: date,
      value: m['value'] is num ? (m['value'] as num).toInt() : 0,
      season: _enum<SeasonStyle>(m['season'], SeasonStyle.values, SeasonStyle.paper),
      bookId: (m['bookId'] is String && (m['bookId'] as String).isNotEmpty)
          ? m['bookId'] as String
          : null,
      bookTitle: (m['bookTitle'] is String && (m['bookTitle'] as String).isNotEmpty)
          ? m['bookTitle'] as String
          : null,
      fromUserExcerpt: m['fromUserExcerpt'] is bool ? m['fromUserExcerpt'] as bool : false,
    );
  }

  static T _enum<T extends Enum>(Object? raw, List<T> values, T fallback) {
    if (raw is! String) return fallback;
    for (final T v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is Keepsake &&
      other.id == id &&
      other.kind == kind &&
      other.title == title &&
      other.detail == detail &&
      other.date == date &&
      other.value == value &&
      other.season == season &&
      other.bookId == bookId &&
      other.bookTitle == bookTitle &&
      other.fromUserExcerpt == fromUserExcerpt;

  @override
  int get hashCode => Object.hash(
        id, kind, title, detail, date, value, season,
        bookId, bookTitle, fromUserExcerpt,
      );
}

/// 从统计快照 + 摘录列表**生成**纪念物，不手写演示纪念物列表。
///
/// 生成规则（全部可单测、无随机数）：
/// 1. 第一次留下阅读记录 → `firstRead`
/// 2. 连续阅读达到 7 / 14 / 21 / 30 天 → `streak`（不达标就不生成）
/// 3. 每月最长的一次阅读 → `monthlyBest`
/// 4. 每月首次达成当日目标 → `goalReached`（goalMinutes <= 0 时不生成）
/// 5. 每条摘录 → `excerpt`（含用户自己采集的）
/// 6. 每个有阅读的月份 → `monthly` 小结
class KeepsakeCatalog {
  const KeepsakeCatalog._();

  static const Set<int> streakMilestones = <int>{7, 14, 21, 30};

  static List<Keepsake> build({
    required StatsSnapshot snapshot,
    required List<Excerpt> excerpts,
    SeasonStyle season = SeasonStyle.paper,
  }) {
    final List<Keepsake> out = <Keepsake>[];
    final List<ReadingDay> days = snapshot.days;

    void add(
      KeepsakeKind kind,
      String id,
      String title,
      String detail,
      DateTime date,
      int value, {
      String? bookId,
      String? bookTitle,
      bool fromUserExcerpt = false,
    }) =>
        out.add(Keepsake(
          id: id,
          kind: kind,
          title: title,
          detail: detail,
          date: utcDateOf(date),
          value: value,
          season: season,
          bookId: bookId,
          bookTitle: bookTitle,
          fromUserExcerpt: fromUserExcerpt,
        ));

    // 1 · 第一次阅读
    for (final ReadingDay d in days) {
      if (d.hasRead) {
        add(
          KeepsakeKind.firstRead,
          'k-firstRead',
          '第一次留下阅读记录',
          '${dateLabelOf(d.date)}，读了 ${StatsSnapshot.formatMinutes(d.minutes)}。',
          d.date,
          d.minutes,
        );
        break;
      }
    }

    // 2 · 连续阅读里程碑（从前往后累计，中断归零）
    int run = 0;
    for (final ReadingDay d in days) {
      if (!d.hasRead) {
        run = 0;
        continue;
      }
      run++;
      if (streakMilestones.contains(run)) {
        add(
          KeepsakeKind.streak,
          'k-streak-$run-${dateKeyOf(d.date)}',
          '连续阅读 $run 天',
          '到 ${dateLabelOf(d.date)} 为止没有中断。',
          d.date,
          run,
        );
      }
    }

    // 按月份分桶：月度类纪念物只基于当月数据，不把补格算进去。
    final Map<String, List<ReadingDay>> byMonth = <String, List<ReadingDay>>{};
    for (final ReadingDay d in days) {
      byMonth.putIfAbsent(monthKeyOf(d.date), () => <ReadingDay>[]).add(d);
    }
    for (final MapEntry<String, List<ReadingDay>> e in byMonth.entries) {
      final List<ReadingDay> monthDays = e.value;
      final List<ReadingDay> readDays = <ReadingDay>[
        for (final ReadingDay d in monthDays) if (d.hasRead) d,
      ];
      if (readDays.isEmpty) continue;

      // 3 · 当月最长一次
      ReadingDay best = readDays.first;
      for (final ReadingDay d in readDays) {
        if (d.minutes > best.minutes) best = d;
      }
      add(
        KeepsakeKind.monthlyBest,
        'k-monthlyBest-${e.key}',
        '${monthLabelOf(best.date.year, best.date.month)}最长的一次',
        '${dateLabelOf(best.date)}，${StatsSnapshot.formatMinutes(best.minutes)}。',
        best.date,
        best.minutes,
      );

      // 4 · 当月首次达标
      if (snapshot.goalMinutes > 0) {
        for (final ReadingDay d in monthDays) {
          if (d.minutes >= snapshot.goalMinutes) {
            add(
              KeepsakeKind.goalReached,
              'k-goalReached-${e.key}',
              '${monthLabelOf(d.date.year, d.date.month)}第一次达标',
              '${dateLabelOf(d.date)} 读了 ${StatsSnapshot.formatMinutes(d.minutes)}，'
                  '目标 ${snapshot.goalMinutes} 分钟。',
              d.date,
              d.minutes,
            );
            break;
          }
        }
      }

      // 6 · 月度小结
      final int total = readDays.fold<int>(0, (int s, ReadingDay d) => s + d.minutes);
      final int pages = readDays.fold<int>(0, (int s, ReadingDay d) => s + d.pages);
      add(
        KeepsakeKind.monthly,
        'k-monthly-${e.key}',
        '${monthLabelOf(readDays.first.date.year, readDays.first.date.month)}小结',
        '阅读 ${readDays.length} 天 · ${StatsSnapshot.formatMinutes(total)} · $pages 页。',
        readDays.last.date,
        total,
      );
    }

    // 5 · 摘录落卡
    for (final Excerpt ex in excerpts) {
      add(
        KeepsakeKind.excerpt,
        'k-excerpt-${ex.id}',
        '摘录《${ex.bookTitle}》',
        ex.text,
        ex.capturedAt,
        0,
        bookId: ex.bookId,
        bookTitle: ex.bookTitle,
        fromUserExcerpt: ex.isUserAdded,
      );
    }

    // 日期降序（最新在前），同日按类型稳定排序。
    out.sort((Keepsake a, Keepsake b) {
      final int byDate = b.dateKey.compareTo(a.dateKey);
      return byDate != 0 ? byDate : a.kind.index.compareTo(b.kind.index);
    });
    return List<Keepsake>.unmodifiable(out);
  }

  static Map<String, List<Keepsake>> byMonth(Iterable<Keepsake> items) {
    final Map<String, List<Keepsake>> out = <String, List<Keepsake>>{};
    for (final Keepsake k in items) {
      out.putIfAbsent(k.monthKey, () => <Keepsake>[]).add(k);
    }
    return Map<String, List<Keepsake>>.unmodifiable(out);
  }

  /// 有纪念物的月份，降序供归档 chip 使用。
  static List<String> monthKeys(Iterable<Keepsake> items) {
    final List<String> keys = byMonth(items).keys.toList()..sort();
    return List<String>.unmodifiable(keys.reversed);
  }

  static List<Keepsake> forMonth(Iterable<Keepsake> items, String monthKey) =>
      List<Keepsake>.unmodifiable(
        items.where((Keepsake k) => k.monthKey == monthKey),
      );

  static Map<KeepsakeKind, int> countByKind(Iterable<Keepsake> items) {
    final Map<KeepsakeKind, int> out = <KeepsakeKind, int>{
      for (final KeepsakeKind k in KeepsakeKind.values) k: 0,
    };
    for (final Keepsake k in items) {
      out[k.kind] = (out[k.kind] ?? 0) + 1;
    }
    return Map<KeepsakeKind, int>.unmodifiable(out);
  }
}

/// 纪念物卡环形切换，与 `ExcerptCycler` 同一套纪律：空列表不崩、越界夹住。
@immutable
class KeepsakeCycler {
  const KeepsakeCycler(this.items, {this.index = 0});

  final List<Keepsake> items;
  final int index;

  bool get isEmpty => items.isEmpty;
  bool get hasMultiple => items.length > 1;

  Keepsake? get current =>
      items.isEmpty ? null : items[index.clamp(0, items.length - 1).toInt()];

  KeepsakeCycler next() => items.isEmpty
      ? this
      : KeepsakeCycler(items, index: (index + 1) % items.length);

  KeepsakeCycler previous() => items.isEmpty
      ? this
      : KeepsakeCycler(items, index: (index - 1 + items.length) % items.length);

  KeepsakeCycler select(int i) => items.isEmpty
      ? this
      : KeepsakeCycler(items, index: i.clamp(0, items.length - 1).toInt());
}

// ---------------------------------------------------------------- 月度日历

@immutable
class CalendarCell {
  const CalendarCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.minutes,
    required this.pages,
    required this.level,
    required this.keepsakes,
    required this.excerpts,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final int minutes;
  final int pages;
  final int level;

  /// 当天生成的纪念物与摘录（可能来自补格日期，但补格不会参与月度合计）。
  final List<Keepsake> keepsakes;
  final List<Excerpt> excerpts;

  String get key => dateKeyOf(date);
  String get monthKey => monthKeyOf(date);
  bool get hasRead => minutes > 0;
  bool get hasKeepsake => keepsakes.isNotEmpty;
  bool get hasExcerpt => excerpts.isNotEmpty;
}

@immutable
class CalendarMonth {
  const CalendarMonth({
    required this.anchor,
    required this.cells,
    required this.totalMinutes,
    required this.readDays,
    required this.keepsakeCount,
    required this.excerptCount,
    required this.todayKey,
    required this.inRange,
    required this.canPrev,
    required this.canNext,
  });

  final MonthAnchor anchor;
  final List<CalendarCell> cells;
  final int totalMinutes;
  final int readDays;
  final int keepsakeCount;
  final int excerptCount;
  final String todayKey;
  final bool inRange;
  final bool canPrev;
  final bool canNext;

  String get label => anchor.label;
  String get monthKey => anchor.key;

  CalendarCell? cellFor(String key) {
    for (final CalendarCell c in cells) {
      if (c.key == key) return c;
    }
    return null;
  }

  static CalendarMonth build({
    required StatsSnapshot snapshot,
    required List<Keepsake> keepsakes,
    required List<Excerpt> excerpts,
    int? year,
    int? month,
  }) {
    // 空快照兜底：用 epoch 作哨兵，不引入「演示日期」。
    final MonthAnchor first = snapshot.days.isEmpty
        ? const MonthAnchor(1970, 1)
        : MonthAnchor.fromDate(snapshot.days.first.date);
    final MonthAnchor last = snapshot.days.isEmpty
        ? const MonthAnchor(1970, 1)
        : MonthAnchor.fromDate(snapshot.days.last.date);
    final MonthAnchor anchor =
        (year != null && month != null) ? MonthAnchor(year, month) : last;

    final Map<String, ReadingDay> dayMap = <String, ReadingDay>{
      for (final ReadingDay d in snapshot.days) dateKeyOf(d.date): d,
    };
    final Map<String, List<Keepsake>> keepsakeMap = KeepsakeCatalog.byMonth(keepsakes);
    // 先按日期分桶，再按 key 取，避免每个格子线性扫全表。
    final Map<String, List<Keepsake>> keepsakeByDay = <String, List<Keepsake>>{};
    for (final List<Keepsake> group in keepsakeMap.values) {
      for (final Keepsake k in group) {
        keepsakeByDay.putIfAbsent(k.dateKey, () => <Keepsake>[]).add(k);
      }
    }
    final Map<String, List<Excerpt>> excerptByDay = <String, List<Excerpt>>{};
    for (final Excerpt e in excerpts) {
      excerptByDay.putIfAbsent(dateKeyOf(e.capturedAt), () => <Excerpt>[]).add(e);
    }

    final String todayKey =
        snapshot.days.isEmpty ? '' : dateKeyOf(snapshot.days.last.date);
    final List<DateTime> grid = monthGridOf(anchor.year, anchor.month);
    final List<CalendarCell> cells = <CalendarCell>[];
    int totalMinutes = 0;
    int readDays = 0;
    int keepsakeCount = 0;
    int excerptCount = 0;

    for (final DateTime d in grid) {
      final String key = dateKeyOf(d);
      final ReadingDay? raw = dayMap[key];
      final bool inMonth = d.year == anchor.year && d.month == anchor.month;
      final List<Keepsake> dayKeepsakes = List<Keepsake>.unmodifiable(
        keepsakeByDay[key] ?? const <Keepsake>[],
      );
      final List<Excerpt> dayExcerpts = List<Excerpt>.unmodifiable(
        excerptByDay[key] ?? const <Excerpt>[],
      );
      final int minutes = raw?.minutes ?? 0;
      final int pages = raw?.pages ?? 0;
      cells.add(CalendarCell(
        date: d,
        inMonth: inMonth,
        isToday: key == todayKey,
        minutes: minutes,
        pages: pages,
        level: StatsSnapshot.heatmapLevel(minutes),
        keepsakes: dayKeepsakes,
        excerpts: dayExcerpts,
      ));
      if (inMonth && raw != null) {
        totalMinutes += minutes;
        if (raw.hasRead) readDays++;
        keepsakeCount += dayKeepsakes.length;
        excerptCount += dayExcerpts.length;
      }
    }

    return CalendarMonth(
      anchor: anchor,
      cells: List<CalendarCell>.unmodifiable(cells),
      totalMinutes: totalMinutes,
      readDays: readDays,
      keepsakeCount: keepsakeCount,
      excerptCount: excerptCount,
      todayKey: todayKey,
      inRange: anchor.index >= first.index && anchor.index <= last.index,
      canPrev: anchor.index > first.index,
      canNext: anchor.index < last.index,
    );
  }
}

/// 月份翻页状态机：夹在演示数据覆盖的月份范围内，不产生「空白月」假装能翻。
@immutable
class CalendarMonthNavigator {
  const CalendarMonthNavigator({
    required this.first,
    required this.last,
    required this.current,
  });

  final MonthAnchor first;
  final MonthAnchor last;
  final MonthAnchor current;

  bool get canPrev => current.index > first.index;
  bool get canNext => current.index < last.index;

  CalendarMonthNavigator shift(int delta) {
    final int target = (current.index + delta).clamp(first.index, last.index).toInt();
    return CalendarMonthNavigator(
      first: first,
      last: last,
      current: MonthAnchor.fromDate(monthStartOf(target)),
    );
  }

  CalendarMonthNavigator prev() => shift(-1);
  CalendarMonthNavigator next() => shift(1);

  CalendarMonthNavigator jumpToThisMonth() => CalendarMonthNavigator(
        first: first,
        last: last,
        current: last,
      );
}

/// 选中日的纯文本摘要，页面与规格单测共用同一口径。
String calendarDaySummary(CalendarCell cell) {
  if (!cell.hasRead && !cell.hasKeepsake && !cell.hasExcerpt) {
    return '${dateLabelOf(cell.date)}：这一天还没有阅读记录';
  }
  final StringBuffer b = StringBuffer()
    ..write('${dateLabelOf(cell.date)}：')
    ..write(cell.hasRead
        ? '${StatsSnapshot.formatMinutes(cell.minutes)} · ${cell.pages} 页 · 热力 ${cell.level} 级'
        : '无阅读记录');
  if (cell.hasKeepsake) b.write(' · 纪念物 ${cell.keepsakes.length} 枚');
  if (cell.hasExcerpt) b.write(' · 摘录 ${cell.excerpts.length} 条');
  return b.toString();
}
