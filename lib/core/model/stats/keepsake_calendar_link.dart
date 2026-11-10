import 'package:flutter/foundation.dart';

import '../../../assembly/route_args.dart';
import 'calendar_day_link.dart';
import 'stats_date.dart';

/// 纪念物册 ↔ 阅读日历的**双向深链**唯一构造口（第二十轮）。
///
/// 之前两页各自只有一条单向入口：统计页卡片 → 纪念物册（第十八轮）、
/// 统计页 → 整月日历（第十三轮）。日历里看到「今天有 2 枚纪念物」却点不进
/// 册子，册子里看到某一枚也回不到日历的那一天。本层把两个方向的
/// **构造、合法性、禁用判据**收口，页面只调静态方法，不自己拼 Args 字段。
///
/// 三条硬口径：
/// 1. **跨月补格不提供深链**：6×7 网格里 `inMonth=false` 的格子只是对齐用，
///    点「查看当天纪念物」却跳到另一个月会让人以为数据错了。
/// 2. **日期与月份必须同月**：`fromDay` 由 dateKey 反解 monthKey，不信任
///    调用方另传的月份；`isConsistent` 在模型层再校验一次。
/// 3. **非法 key 一律回落 null**，不把脏字符串塞进路由参数。`tryParseDateKey`
///    会拦掉 `2026-02-30` 这类会被 `DateTime.utc` 静默进位的日期。
///
/// **静态边界**：纯 Dart 模型，不读时间、不读数据库、不构造路由、不 import
/// 任何 feature 页面；导航由 app 层按强类型 Args 注入。
@immutable
class KeepsakeCalendarLink {
  const KeepsakeCalendarLink._();

  /// 日历选中日 → 纪念物册（只看这一天）。
  /// 返回 null 表示「不给深链」：跨月补格 / 非法 key / 日期月份不一致。
  static KeepsakeLibraryArgs? toLibraryFromDay({
    required String dateKey,
    required bool inMonth,
  }) {
    if (!inMonth) return null;
    // 第二十一轮：禁用判据与「当天摘录」深链共用 CalendarDayLink，
    // 两条按钮不会一个禁用、另一个却把非法日期塞进路由。
    if (!CalendarDayLink.isValidDay(dateKey, inMonth: inMonth)) return null;
    final KeepsakeLibraryArgs args = KeepsakeLibraryArgs.fromDay(dateKey);
    if (!args.isDayScoped || !args.isConsistent) return null;
    return args;
  }

  /// 日历月度汇总 → 纪念物册（只看整月）。
  static KeepsakeLibraryArgs? toLibraryFromMonth(String? monthKey) {
    final KeepsakeLibraryArgs args = KeepsakeLibraryArgs.fromMonth(monthKey);
    return args.initialMonthKey == null ? null : args;
  }

  /// 纪念物册某一枚 → 日历（定位到那天并选中）。
  /// `CalendarMonthArgs.selectedDateKey` 是第十三轮预留的字段，本轮真正用上。
  static CalendarMonthArgs? toCalendarFromDay(String? dateKey) {
    final CalendarMonthArgs args = CalendarMonthArgs.fromDateKey(dateKey);
    return args.isDayScoped ? args : null;
  }

  /// 纪念物册当前月份筛选 → 日历（定位整月，不强制选中日）。
  static CalendarMonthArgs? toCalendarFromMonth(String? monthKey) =>
      tryParseMonthKey(monthKey) == null
          ? null
          : CalendarMonthArgs.fromMonthKey(monthKey);

  /// 日期与月份是否同月，供页面决定要不要显示「清除日期筛选」。
  /// 任一非法都返回 false，不把 null 当通配符。
  static bool sameMonth(String? dateKey, String? monthKey) {
    if (dateKey == null || monthKey == null) return false;
    return monthKeyOfDateKey(dateKey) == monthKey;
  }

  /// 跨月补格 / 非法日期的禁用说明，与「当天摘录」深链共用
  /// `CalendarDayLink`（内部转发 `LegalTexts`），不在这里复制第二份中文句子。
  static String get crossMonthNote => CalendarDayLink.crossMonthNote;
  static String get invalidDateNote => CalendarDayLink.invalidDateNote;
}
