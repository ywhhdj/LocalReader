import 'package:flutter/material.dart';

/// 纪念物类型词表（第十八轮从 `keepsakes.dart` 抽出）。
///
/// 抽出的原因不是好看：`reading_stats.dart` 的 `WidgetSpec` 需要引用
/// `KeepsakeKind`，而 `keepsakes.dart` 又 import `reading_stats.dart`——
/// 两边直接互引会形成 library 循环。把纯词表放到独立文件，
/// `keepsakes.dart` 继续 `export` 它，所有既有调用点的 import 路径不用改。
enum KeepsakeKind { firstRead, streak, monthlyBest, goalReached, excerpt, monthly }

class KeepsakeKindLabels {
  const KeepsakeKindLabels._();

  static const Map<KeepsakeKind, String> labels = <KeepsakeKind, String>{
    KeepsakeKind.firstRead: '起读',
    KeepsakeKind.streak: '连续',
    KeepsakeKind.monthlyBest: '最长一次',
    KeepsakeKind.goalReached: '达标',
    KeepsakeKind.excerpt: '摘录',
    KeepsakeKind.monthly: '月度小结',
  };

  static const Map<KeepsakeKind, IconData> icons = <KeepsakeKind, IconData>{
    KeepsakeKind.firstRead: Icons.auto_stories_outlined,
    KeepsakeKind.streak: Icons.local_fire_department_outlined,
    KeepsakeKind.monthlyBest: Icons.schedule_outlined,
    KeepsakeKind.goalReached: Icons.emoji_events_outlined,
    KeepsakeKind.excerpt: Icons.format_quote_outlined,
    KeepsakeKind.monthly: Icons.calendar_month_outlined,
  };
}
