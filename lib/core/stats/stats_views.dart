import 'package:flutter/foundation.dart';

import 'reading_stats.dart';
import 'stats_date.dart';

/// 统计多视图与报告布局（第二十四轮）。
///
/// 参考仓库 README 两句：「Distinct views for different records: overview,
/// reading rhythm, books, marks, and touch activity. Choose a preset period or
/// custom date range; fields and charts without data are omitted.」「Eight
/// distinct report layouts, with optional reading calendars, rhythms,
/// companion book lists, progress, and excerpts. Previews and exports use
/// the same content.」
///
/// 关键口径：**预览与导出同内容**——两者都从同一个 `ReportPayload` 取，
/// 不各拼一份字符串（第十轮导出落地时踩过「页面显示新名、导出旧名」的坑）。
enum StatsViewKind { overview, rhythm, books, marks, touchActivity }

enum StatsPeriodKind { today, week, month, year, all, custom }

enum ReportLayout {
  classic, compact, journal, calendarFocus, rhythmFocus,
  companion, progressFocus, excerptFocus,
}

@immutable
class StatsPeriod {
  const StatsPeriod({this.kind = StatsPeriodKind.month, this.from, this.to});

  final StatsPeriodKind kind;
  final String? from;
  final String? to;

  /// 归一化：非自定义周期不保留残留的自定义范围；自定义范围非法则退回整月。
  StatsPeriod normalized() {
    if (kind != StatsPeriodKind.custom) {
      return StatsPeriod(kind: kind);
    }
    final String? a = from == null ? null : (tryParseDateKey(from) == null ? null : from);
    final String? b = to == null ? null : (tryParseDateKey(to) == null ? null : to);
    if (a == null || b == null) {
      return const StatsPeriod(kind: StatsPeriodKind.month);
    }
    // 起止倒置时交换，不让筛选变成永远空结果。
    return a.compareTo(b) <= 0
        ? StatsPeriod(kind: kind, from: a, to: b)
        : StatsPeriod(kind: kind, from: b, to: a);
  }

  bool contains(String dateKey) {
    final StatsPeriod n = normalized();
    if (n.kind == StatsPeriodKind.custom) {
      return dateKeyInRange(dateKey, n.from, n.to);
    }
    return true; // 预设周期由 StatsSnapshot 的数据窗口决定，静态阶段只提供判据。
  }

  @override
  bool operator ==(Object other) =>
      other is StatsPeriod &&
      other.kind == kind &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(kind, from, to);
}

/// 「无数据则省略」不是页面里写 if，而是模型产出**实际有内容的字段集合**。
/// 页面与导出都读这个集合，所以两者不会出现「预览有卡片、导出没有」。
@immutable
class ReportPayload {
  const ReportPayload({
    required this.layout,
    required this.period,
    required this.snapshot,
    required this.sections,
  });

  final ReportLayout layout;
  final StatsPeriod period;
  final StatsSnapshot snapshot;
  final List<ReportSection> sections;

  static const Map<ReportLayout, List<ReportSection>> layoutSections =
      <ReportLayout, List<ReportSection>>{
    ReportLayout.classic: <ReportSection>[
      ReportSection.calendar, ReportSection.progress, ReportSection.excerpts,
    ],
    ReportLayout.compact: <ReportSection>[ReportSection.progress],
    ReportLayout.journal: <ReportSection>[
      ReportSection.calendar, ReportSection.excerpts, ReportSection.companion,
    ],
    ReportLayout.calendarFocus: <ReportSection>[ReportSection.calendar],
    ReportLayout.rhythmFocus: <ReportSection>[ReportSection.rhythm, ReportSection.touch],
    ReportLayout.companion: <ReportSection>[ReportSection.companion, ReportSection.progress],
    ReportLayout.progressFocus: <ReportSection>[ReportSection.progress, ReportSection.rhythm],
    ReportLayout.excerptFocus: <ReportSection>[ReportSection.excerpts, ReportSection.calendar],
  };

  /// 单一构造口：按布局挑字段，再把「真的没数据」的字段剔除。
  factory ReportPayload.build({
    required ReportLayout layout,
    required StatsPeriod period,
    required StatsSnapshot snapshot,
  }) {
    final List<ReportSection> requested = layoutSections[layout]!;
    final List<ReportSection> available = <ReportSection>[];
    for (final ReportSection s in requested) {
      if (_hasData(s, snapshot)) available.add(s);
    }
    return ReportPayload(
      layout: layout,
      period: period.normalized(),
      snapshot: snapshot,
      sections: List<ReportSection>.unmodifiable(available),
    );
  }

  static bool _hasData(ReportSection s, StatsSnapshot snap) {
    switch (s) {
      case ReportSection.calendar:
      case ReportSection.rhythm:
      case ReportSection.touch:
        return snap.days.any((ReadingDay d) => d.hasRead);
      case ReportSection.progress:
        return snap.today > 0 || snap.weekMinutes > 0;
      case ReportSection.excerpts:
        return snap.excerpts.isNotEmpty;
      case ReportSection.companion:
        return snap.totalBooks > 0;
    }
  }

  /// **预览与导出共用**：同一个 payload → 同一份文本，不做第二次拼装。
  String render() {
    final StringBuffer buf = StringBuffer();
    buf.writeln('阅读报告 · ${_layoutLabel(layout)}');
    buf.writeln('周期：${_periodLabel(period)}');
    for (final ReportSection s in sections) {
      buf.writeln('');
      buf.writeln('【${sectionLabels[s]!}】');
      buf.writeln(_sectionText(s, snapshot));
    }
    return buf.toString();
  }

  static String _layoutLabel(ReportLayout l) => layoutLabels[l]!;

  static String _periodLabel(StatsPeriod p) {
    final StatsPeriod n = p.normalized();
    switch (n.kind) {
      case StatsPeriodKind.today:
        return '今天';
      case StatsPeriodKind.week:
        return '本周';
      case StatsPeriodKind.month:
        return '本月';
      case StatsPeriodKind.year:
        return '今年';
      case StatsPeriodKind.all:
        return '全部';
      case StatsPeriodKind.custom:
        return '${n.from} ~ ${n.to}';
    }
  }

  static String _sectionText(ReportSection s, StatsSnapshot snap) {
    switch (s) {
      case ReportSection.calendar:
        return '${snap.days.where((ReadingDay d) => d.hasRead).length} 个阅读日，'
            '连续 ${snap.streakDays} 天';
      case ReportSection.rhythm:
        return '本周 ${snap.weekLabel}，累计 ${snap.totalPages} 页';
      case ReportSection.touch:
        return '翻页活动已记录（静态演示口径）';
      case ReportSection.progress:
        return '今日 ${snap.today} 分钟 / 目标 ${snap.goalMinutes} 分钟';
      case ReportSection.excerpts:
        return '${snap.excerpts.length} 条摘录';
      case ReportSection.companion:
        return '书库 ${snap.totalBooks} 册';
    }
  }

  static const Map<ReportLayout, String> layoutLabels = <ReportLayout, String>{
    ReportLayout.classic: '经典',
    ReportLayout.compact: '精简',
    ReportLayout.journal: '手账',
    ReportLayout.calendarFocus: '日历为主',
    ReportLayout.rhythmFocus: '节奏为主',
    ReportLayout.companion: '伴随书单',
    ReportLayout.progressFocus: '进度为主',
    ReportLayout.excerptFocus: '摘录为主',
  };

  static const Map<StatsViewKind, String> viewLabels = <StatsViewKind, String>{
    StatsViewKind.overview: '概览',
    StatsViewKind.rhythm: '阅读节奏',
    StatsViewKind.books: '书籍',
    StatsViewKind.marks: '标记',
    StatsViewKind.touchActivity: '触摸活动',
  };

  static const Map<ReportSection, String> sectionLabels = <ReportSection, String>{
    ReportSection.calendar: '阅读日历',
    ReportSection.rhythm: '阅读节奏',
    ReportSection.progress: '阅读进度',
    ReportSection.excerpts: '摘录',
    ReportSection.companion: '伴随书单',
    ReportSection.touch: '触摸活动',
  };
}

enum ReportSection { calendar, rhythm, progress, excerpts, companion, touch }

/// 按书聚合（「书籍」视图）。复用 `StatsSnapshot.days` 与书库数量，
/// 不新造一份演示数据。
@immutable
class BookStatsSummary {
  const BookStatsSummary({required this.totalBooks, required this.lastReadTitle});

  final int totalBooks;
  final String lastReadTitle;

  factory BookStatsSummary.fromSnapshot(StatsSnapshot s) => BookStatsSummary(
        totalBooks: s.totalBooks,
        lastReadTitle: s.lastReadBookTitle ?? '暂无最近阅读',
      );

  bool get hasData => totalBooks > 0 || lastReadTitle != '暂无最近阅读';
}
