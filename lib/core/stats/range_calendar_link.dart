import 'package:flutter/foundation.dart';

import '../router/route_args.dart';
import 'keepsake_calendar_link.dart';
import 'stats_date.dart';

/// 纪念物册「日期范围筛选 → 日历」的反向深链（第二十四轮候选收口）。
///
/// 第二十轮已有「月份筛选 → 日历」「某一枚 → 当天」，第二十一轮加了起止日期
/// 范围；范围本身一直没有回日历的入口。两条硬口径：
/// 1. **范围跨月时定位到起始月**，不猜「用户想看哪个月」；
/// 2. **范围非法 / 空范围回落 null**，不把脏字符串塞进路由参数。
@immutable
class KeepsakeRangeLink {
  const KeepsakeRangeLink._();

  static CalendarMonthArgs? toCalendar(DateKeyRange? range) {
    if (range == null) return null;
    final String? start = range.from;
    if (start == null || tryParseDateKey(start) == null) return null;
    if (range.to != null && tryParseDateKey(range.to) == null) return null;
    // 起始月由 dateKey 反解，不信任调用方另传月份（与 `fromDay` 同构）。
    final DateTime d = tryParseDateKey(start)!;
    return CalendarMonthArgs.fromMonthKey(monthKeyOf(d));
  }

  /// 范围是否跨月：跨月时页面显示「将定位到起始月」说明，避免以为丢了后半段。
  static bool spansMonths(DateKeyRange? range) {
    if (range?.from == null || range?.to == null) return false;
    final DateTime? a = tryParseDateKey(range!.from);
    final DateTime? b = tryParseDateKey(range.to);
    if (a == null || b == null) return false;
    return monthIndexOf(a.year, a.month) != monthIndexOf(b.year, b.month);
  }

  /// 复用既有双向深链，不另写构造逻辑。
  static CalendarMonthArgs? toCalendarFromDay(String? dateKey) =>
      KeepsakeCalendarLink.toCalendarFromDay(dateKey);
}
