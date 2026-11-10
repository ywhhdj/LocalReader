import 'package:flutter/foundation.dart';

/// 统计、热力图、阅读日历、纪念物共用的日期口径**唯一出口**。
///
/// 之前 `ReadingDay.key` 自己拼年月日，`_CalendarStrip` 又自己存一份周标签；
/// 月度日历再加入后会出现三套 key / 三套周起始。这里统一成纯 Dart 顶层函数，
/// 所有日期一律按年月日字段构造 UTC 日期，丢弃时分秒；
/// 演示数据与快照本身都是 UTC，因此不会出现跨时区换算口径。
///
/// 口径：周一起始（原项目 7 天条即如此），固定 6 周 × 7 天 = 42 格网格。

const int statsFirstDayOfWeek = DateTime.monday;

const List<String> statsWeekdayLabels = <String>['一', '二', '三', '四', '五', '六', '日'];

/// 只取年月日，丢弃时分秒与本地时区。
DateTime utcDateOf(DateTime d) => DateTime.utc(d.year, d.month, d.day);

String dateKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String monthKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

String monthLabelOf(int year, int month) => '$year 年 $month 月';

String dateLabelOf(DateTime d) => '${d.month} 月 ${d.day} 日';

/// 第二十轮：双向深链要按 `YYYY-MM-DD` 反解日期，**严格校验**格式与真实日历日。
/// 非法 / 不存在的日期（如 `2026-02-30`）一律返回 null，不靠 `DateTime.parse`
/// 的宽松语义把脏 key 悄悄带进路由参数。
/// 格式固定 10 位、两段连字符、三段纯数字；反解后再回拼一次确认没被进位。
DateTime? tryParseDateKey(String? key) {
  if (key == null || key.length != 10) return null;
  if (key[4] != '-' || key[7] != '-') return null;
  final int? y = int.tryParse(key.substring(0, 4));
  final int? m = int.tryParse(key.substring(5, 7));
  final int? d = int.tryParse(key.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final DateTime date = DateTime.utc(y, m, d);
  // DateTime.utc(2026, 2, 30) 会静默进位到 3 月 2 日，回拼校验把它拦下。
  return dateKeyOf(date) == key ? date : null;
}

/// 从 dateKey 取月份锚点，供「纪念物 → 整月日历」深链；非法 key 返回 null。
MonthAnchor? monthAnchorOfDateKey(String? key) {
  final DateTime? d = tryParseDateKey(key);
  return d == null ? null : MonthAnchor(d.year, d.month);
}

/// dateKey 的月份前缀，不合法时返回 null。用于校验「日期与月份是否同月」。
String? monthKeyOfDateKey(String? key) {
  final DateTime? d = tryParseDateKey(key);
  return d == null ? null : monthKeyOf(d);
}

/// 严格解析 `YYYY-MM`。月份 chip / 月度汇总的深链都走这里，
/// 不在页面里手写 `substring` 或 `int.parse`。
MonthAnchor? tryParseMonthKey(String? key) {
  if (key == null || key.length != 7 || key[4] != '-') return null;
  final int? y = int.tryParse(key.substring(0, 4));
  final int? m = int.tryParse(key.substring(5, 7));
  if (y == null || m == null || m < 1 || m > 12) return null;
  final MonthAnchor anchor = MonthAnchor(y, m);
  return anchor.key == key ? anchor : null;
}

/// 第二十一轮：日期范围筛选要按 UTC 日做加减，不能拿 `DateTime.now()` 当基准。
/// 一律返回 `dateKeyOf()` 格式化后的字符串，保证闭区间两端可直接字典序比较
/// （`YYYY-MM-DD` 字典序 == 时间序），查询层不需要再解析一次。
String? dateKeyAddDays(String dateKey, int days) {
  final DateTime? d = tryParseDateKey(dateKey);
  return d == null ? null : dateKeyOf(d.add(Duration(days: days)));
}

/// 在 `[from, to]` 闭区间内（两端都合法时）；任一端非法返回 false。
bool dateKeyInRange(String dateKey, String? from, String? to) {
  if (from == null && to == null) return true;
  if (tryParseDateKey(dateKey) == null) return false;
  if (from != null && dateKey.compareTo(from) < 0) return false;
  if (to != null && dateKey.compareTo(to) > 0) return false;
  return true;
}

/// 把「起 > 止」的脏范围交换成合法区间；非法端一律置 null。
/// 保留用户意图而不是静默丢弃，和 `normalizeFilter` 的裁决口径一致。
DateKeyRange normalizeDateKeyRange(String? from, String? to) {
  final String? a = tryParseDateKey(from) == null ? null : from;
  final String? b = tryParseDateKey(to) == null ? null : to;
  if (a != null && b != null && a.compareTo(b) > 0) {
    return DateKeyRange(from: b, to: a);
  }
  return DateKeyRange(from: a, to: b);
}

/// 某月的首日 / 末日 dateKey，供「整月」快捷区间与深链使用。
DateKeyRange monthDateKeyRange(int year, int month) => DateKeyRange(
      from: dateKeyOf(DateTime.utc(year, month, 1)),
      to: dateKeyOf(DateTime.utc(year, month, daysInMonthOf(year, month))),
    );

/// 闭区间 `[from, to]`。两端都可为 null 表示不设边界；都 null 时等价于无筛选。
/// 纯 Dart 值对象，参与 `==` / `hashCode`，便于 `KeepsakeFilter` 复用。
@immutable
class DateKeyRange {
  const DateKeyRange({this.from, this.to});

  final String? from;
  final String? to;

  bool get isEmpty => from == null && to == null;
  bool get isScoped => !isEmpty;
  bool get isFull => from != null && to != null;

  /// 两端都合法且顺序正确（或有一端为空）。归一化的目标状态。
  bool get isValid =>
      (from == null || tryParseDateKey(from) != null) &&
      (to == null || tryParseDateKey(to) != null) &&
      (from == null || to == null || from!.compareTo(to!) <= 0);

  @override
  bool operator ==(Object other) =>
      other is DateKeyRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'DateKeyRange($from ~ $to)';
}

/// 月份序号，用于月份加减与边界比较；避免手写 12 月进位逻辑散落各处。
int monthIndexOf(int year, int month) => year * 12 + (month - 1);

/// 由月份序号反解，返回 UTC 月初。
DateTime monthStartOf(int index) =>
    DateTime.utc(index ~/ 12, (index % 12) + 1, 1);

int daysInMonthOf(int year, int month) {
  final int y = month == 12 ? year + 1 : year;
  final int m = month == 12 ? 1 : month + 1;
  return DateTime.utc(y, m, 1).subtract(const Duration(days: 1)).day;
}

/// 固定 42 格：从「本月 1 日所在周的周一」开始连续 42 天。
/// 跨月补格由调用方用 `inMonth` 判断，不参与月度合计。
List<DateTime> monthGridOf(
  int year,
  int month, {
  int firstDayOfWeek = statsFirstDayOfWeek,
}) {
  final DateTime first = DateTime.utc(year, month, 1);
  final int offset = (first.weekday - firstDayOfWeek + 7) % 7;
  final DateTime gridStart = first.subtract(Duration(days: offset));
  return List<DateTime>.unmodifiable(
    List<DateTime>.generate(
      42,
      (int i) => gridStart.add(Duration(days: i)),
    ),
  );
}

@immutable
class MonthAnchor {
  const MonthAnchor(this.year, this.month)
      : assert(month >= 1 && month <= 12, '月份必须在 1..12');

  final int year;
  final int month;

  int get index => monthIndexOf(year, month);
  String get key => monthKeyOf(DateTime.utc(year, month, 1));
  String get label => monthLabelOf(year, month);
  DateTime get start => DateTime.utc(year, month, 1);

  MonthAnchor shift(int delta) {
    final DateTime d = monthStartOf(index + delta);
    return MonthAnchor(d.year, d.month);
  }

  static MonthAnchor fromDate(DateTime d) => MonthAnchor(d.year, d.month);

  @override
  bool operator ==(Object other) =>
      other is MonthAnchor && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => key;
}
