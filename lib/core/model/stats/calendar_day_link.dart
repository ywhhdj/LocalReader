import 'package:flutter/foundation.dart';

import '../../../l10n/legal_texts.dart';
import 'stats_date.dart';

/// 阅读日历「选中某一天 → 别的页面」的**共享判据**（第二十一轮）。
///
/// 第二十轮已有「纪念物册当天深链」，本轮再加「当天摘录深链」。两条按钮若
/// 各写一份「跨月补格能不能点、非法日期怎么提示」，迟早会变成
/// 「纪念物按钮禁用了、摘录按钮却能跳到另一个月」。这里把判据与两条说明
/// 收口成唯一出口，两个页面 / 两个 Args 工厂都委托它。
///
/// **静态边界**：纯 Dart，不读时间、不构造路由、不 import 任何 feature 页面。
@immutable
class CalendarDayLink {
  const CalendarDayLink._();

  /// 两个条件缺一不可：
  /// 1. `inMonth` —— 6×7 网格里 `inMonth=false` 的格子只用于对齐周起始，
  ///    点「查看当天」却跳到另一个月会让人以为数据错了；
  /// 2. dateKey 必须能被 `tryParseDateKey` 严格解析（`DateTime.utc` 对
  ///    `2026-02-30` 会静默进位，回拼校验把它拦下）。
  static bool isValidDay(String? dateKey, {required bool inMonth}) =>
      inMonth && tryParseDateKey(dateKey) != null;

  /// 归一化后的 dateKey：合法返回原值，否则 null。调用方拿到 null 就不给深链。
  static String? normalizedDateKey(String? dateKey, {required bool inMonth}) =>
      isValidDay(dateKey, inMonth: inMonth) ? dateKey : null;

  /// 禁用原因，页面直接引用，不各写一份中文句子。
  /// 跨月优先于格式错误：对跨月补格说「日期格式无效」是误导。
  static String noteFor({required bool inMonth, required String? dateKey}) {
    if (!inMonth) return LegalTexts.calendarCrossMonthNote;
    if (tryParseDateKey(dateKey) == null) {
      return LegalTexts.calendarInvalidDateNote;
    }
    return '';
  }

  static String get crossMonthNote => LegalTexts.calendarCrossMonthNote;
  static String get invalidDateNote => LegalTexts.calendarInvalidDateNote;
}
