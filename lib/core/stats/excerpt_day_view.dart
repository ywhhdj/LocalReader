import 'package:flutter/foundation.dart';

import 'reading_stats.dart';
import 'stats_date.dart';

/// 「日历某天 → 当天摘录 + 当天阅读记录」联动（第二十四轮候选收口）。
///
/// 第二十一轮做了「日历某天直达当天摘录」的深链，但页面拿到摘录后仍要自己
/// 去 `StatsSnapshot.days` 里找当天分钟数，容易两处口径分裂（一个按 dateKey、
/// 一个按 DateTime 比较）。本层把两个数据源合成一个只读视图。
@immutable
class ExcerptDayView {
  const ExcerptDayView({
    required this.dateKey,
    required this.excerpts,
    required this.minutes,
    required this.pages,
  });

  final String dateKey;
  final List<Excerpt> excerpts;
  final int minutes;
  final int pages;

  factory ExcerptDayView.build({
    required String dateKey,
    required List<Excerpt> allExcerpts,
    required StatsSnapshot snapshot,
  }) {
    final DateTime? day = tryParseDateKey(dateKey);
    if (day == null) {
      return const ExcerptDayView(
        dateKey: '', excerpts: <Excerpt>[], minutes: 0, pages: 0,
      );
    }
    final String key = dateKeyOf(day);
    final List<Excerpt> onDay = List<Excerpt>.unmodifiable(
      allExcerpts.where((Excerpt e) => dateKeyOf(e.capturedAt) == key),
    );
    int minutes = 0;
    int pages = 0;
    for (final ReadingDay d in snapshot.days) {
      if (d.key == key) {
        minutes = d.minutes;
        pages = d.pages;
        break;
      }
    }
    return ExcerptDayView(
      dateKey: key, excerpts: onDay, minutes: minutes, pages: pages,
    );
  }

  bool get isValid => dateKey.isNotEmpty;
  bool get hasRead => minutes > 0 || pages > 0;
  bool get hasExcerpts => excerpts.isNotEmpty;
  bool get isEmpty => !hasRead && !hasExcerpts;

  String get summary => isValid
      ? '${dateLabelOf(tryParseDateKey(dateKey)!)} · '
          '${StatsSnapshot.formatMinutes(minutes)} · $pages 页 · '
          '${excerpts.length} 条摘录'
      : '无效日期';
}
