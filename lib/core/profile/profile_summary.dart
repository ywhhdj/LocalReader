import 'package:flutter/foundation.dart';

import '../stats/reading_stats.dart';

/// 「我的」页阅读摘要（第二十四轮候选收口）。
///
/// 第二十二轮重构个人页时 hero 里的几分钟 / 连续天数仍是页面局部拼装；
/// 统计页第八轮已全部读 `StatsSnapshot`。本层把个人页也接到**同一个聚合源**，
/// 页面不再自己数天数、不缓存旧快照。
@immutable
class ProfileSummary {
  const ProfileSummary({
    required this.todayMinutes,
    required this.weekMinutes,
    required this.streakDays,
    required this.totalBooks,
    required this.goalMinutes,
  });

  factory ProfileSummary.fromSnapshot(StatsSnapshot s) => ProfileSummary(
        todayMinutes: s.today,
        weekMinutes: s.weekMinutes,
        streakDays: s.streakDays,
        totalBooks: s.totalBooks,
        goalMinutes: s.goalMinutes,
      );

  final int todayMinutes;
  final int weekMinutes;
  final int streakDays;
  final int totalBooks;
  final int goalMinutes;

  String get todayLabel => '$todayMinutes';
  String get weekLabel => StatsSnapshot.formatMinutes(weekMinutes);
  String get streakLabel => '$streakDays 天';
  String get booksLabel => '$totalBooks 册';
  double get goalProgress => goalMinutes <= 0
      ? 0
      : (todayMinutes / goalMinutes).clamp(0.0, 1.0).toDouble();

  /// 没有数据的字段由页面省略，不显示「0 分钟 · 连续 0 天」刷屏。
  List<ProfileSummaryField> get visibleFields {
    final List<ProfileSummaryField> out = <ProfileSummaryField>[];
    if (todayMinutes > 0) out.add(ProfileSummaryField.today);
    if (weekMinutes > 0) out.add(ProfileSummaryField.week);
    if (streakDays > 0) out.add(ProfileSummaryField.streak);
    if (totalBooks > 0) out.add(ProfileSummaryField.books);
    return List<ProfileSummaryField>.unmodifiable(out);
  }
}

enum ProfileSummaryField { today, week, streak, books }
