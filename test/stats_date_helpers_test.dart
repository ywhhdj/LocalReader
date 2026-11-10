import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/stats/keepsakes.dart';
import 'package:local_reader/core/stats/stats_date.dart';

/// 第二十一轮「规格单测扩充」之一：`stats_date.dart` 自第十三轮起是
/// 热力图 / 阅读日历 / 纪念物 / 摘录共用的唯一日期出口，但此前只有间接覆盖。
/// 本文件把它的每个顶层函数与边界补成可执行规格。
void main() {
  group('dateKey / monthKey 格式化', () {
    test('年月日补零，且丢弃时分秒', () {
      final DateTime d = DateTime.utc(2026, 1, 8, 23, 59, 59);
      expect(dateKeyOf(d), '2026-01-08');
      expect(monthKeyOf(d), '2026-01');
      expect(dateLabelOf(d), '1 月 8 日');
      expect(monthLabelOf(2026, 1), '2026 年 1 月');
    });

    test('utcDateOf 丢弃时分秒', () {
      final DateTime d = utcDateOf(DateTime.utc(2026, 11, 8, 15, 30));
      expect(d, DateTime.utc(2026, 11, 8));
    });

    test('周一起始标签固定 7 个', () {
      expect(statsFirstDayOfWeek, DateTime.monday);
      expect(statsWeekdayLabels.length, 7);
      expect(statsWeekdayLabels.first, '一');
      expect(statsWeekdayLabels.last, '日');
    });

    test('monthIndexOf / monthStartOf 互为逆运算', () {
      for (final (int y, int m) in <(int, int)>[
        (2026, 1),
        (2026, 11),
        (2026, 12),
        (2027, 1),
      ]) {
        final DateTime back = monthStartOf(monthIndexOf(y, m));
        expect(back.year, y);
        expect(back.month, m);
        expect(back.day, 1);
      }
      expect(monthIndexOf(2026, 12) + 1, monthIndexOf(2027, 1));
    });

    test('daysInMonthOf 含闰年 2 月', () {
      expect(daysInMonthOf(2026, 2), 28);
      expect(daysInMonthOf(2024, 2), 29);
      expect(daysInMonthOf(2026, 12), 31);
      expect(daysInMonthOf(2026, 11), 30);
    });
  });

  group('monthGridOf：固定 42 格、周一起始', () {
    test('长度恒为 42', () {
      for (int m = 1; m <= 12; m++) {
        expect(monthGridOf(2026, m).length, 42, reason: '2026-$m');
      }
    });

    test('第一格必是周一，且包含本月 1 日', () {
      final List<DateTime> grid = monthGridOf(2026, 11);
      expect(grid.first.weekday, DateTime.monday);
      expect(grid.where((DateTime d) => d.month == 11 && d.day == 1).length, 1);
    });

    test('连续 42 天，无重复无跳日', () {
      final List<DateTime> grid = monthGridOf(2026, 11);
      for (int i = 1; i < grid.length; i++) {
        expect(grid[i].difference(grid[i - 1]).inDays, 1);
      }
    });

    test('跨月补格存在但不参与本月计数（由调用方按 inMonth 判）', () {
      final List<DateTime> grid = monthGridOf(2026, 11);
      final int inMonth = grid
          .where((DateTime d) => d.year == 2026 && d.month == 11)
          .length;
      expect(inMonth, 30);
      expect(grid.length - inMonth, greaterThan(0));
    });
  });

  group('MonthAnchor 与 CalendarMonthNavigator 边界', () {
    test('MonthAnchor.fromDate 只取年月', () {
      final MonthAnchor a =
          MonthAnchor.fromDate(DateTime.utc(2026, 11, 8, 22, 10));
      expect(a.year, 2026);
      expect(a.month, 11);
      expect(a.key, '2026-11');
      expect(a.label, '2026 年 11 月');
    });

    test('翻月夹在首末月之间，不翻出空白月', () {
      final CalendarMonthNavigator nav = CalendarMonthNavigator(
        first: const MonthAnchor(2026, 9),
        last: const MonthAnchor(2026, 11),
        current: const MonthAnchor(2026, 11),
      );
      expect(nav.canPrev, isTrue);
      expect(nav.canNext, isFalse);
      expect(nav.next().current.month, 11);
      expect(nav.prev().current.month, 10);
      expect(nav.shift(-99).current.month, 9);
      expect(nav.shift(99).current.month, 11);
    });

    test('jumpToThisMonth 也受边界约束', () {
      final CalendarMonthNavigator nav = CalendarMonthNavigator(
        first: const MonthAnchor(2026, 9),
        last: const MonthAnchor(2026, 10),
        current: const MonthAnchor(2026, 9),
      );
      expect(nav.jumpToThisMonth().current, isA<MonthAnchor>());
      expect(nav.jumpToThisMonth().current.month, 10);
    });
  });

  group('第二十一轮新增：日期范围辅助', () {
    test('dateKeyAddDays 支持跨月 / 跨年，UTC 不涉时区', () {
      expect(dateKeyAddDays('2026-11-08', -6), '2026-11-02');
      expect(dateKeyAddDays('2026-11-01', -1), '2026-10-31');
      expect(dateKeyAddDays('2026-12-31', 1), '2027-01-01');
      expect(dateKeyAddDays('2026-01-01', -1), '2025-12-31');
    });

    test('dateKeyAddDays 非法 key 返回 null，不抛异常', () {
      expect(dateKeyAddDays('2026-02-30', 1), isNull);
      expect(dateKeyAddDays('bad', 1), isNull);
      expect(dateKeyAddDays('', 0), isNull);
    });

    test('dateKeyInRange：闭区间、两端包含、可只设一端', () {
      expect(dateKeyInRange('2026-11-08', '2026-11-01', '2026-11-30'), isTrue);
      expect(dateKeyInRange('2026-11-01', '2026-11-01', '2026-11-30'), isTrue);
      expect(dateKeyInRange('2026-11-30', '2026-11-01', '2026-11-30'), isTrue);
      expect(dateKeyInRange('2026-10-31', '2026-11-01', '2026-11-30'), isFalse);
      expect(dateKeyInRange('2026-12-01', '2026-11-01', '2026-11-30'), isFalse);
      expect(dateKeyInRange('2026-11-08', null, '2026-11-30'), isTrue);
      expect(dateKeyInRange('2026-12-01', null, '2026-11-30'), isFalse);
      expect(dateKeyInRange('2026-11-08', '2026-11-01', null), isTrue);
      expect(dateKeyInRange('2026-10-31', '2026-11-01', null), isFalse);
      expect(dateKeyInRange('2026-11-08', null, null), isTrue);
    });

    test('dateKeyInRange 非法 dateKey 一律 false', () {
      expect(dateKeyInRange('2026-02-30', null, null), isFalse);
      expect(dateKeyInRange('bad', null, null), isFalse);
    });

    test('normalizeDateKeyRange：交换逆序、清非法端、保留单边', () {
      expect(normalizeDateKeyRange('2026-11-08', '2026-11-02'),
          const DateKeyRange(from: '2026-11-02', to: '2026-11-08'));
      expect(normalizeDateKeyRange('2026-02-30', '2026-11-08'),
          const DateKeyRange(from: null, to: '2026-11-08'));
      expect(normalizeDateKeyRange('2026-11-02', null),
          const DateKeyRange(from: '2026-11-02', to: null));
      expect(normalizeDateKeyRange(null, null), const DateKeyRange());
    });

    test('monthDateKeyRange：首末日含闰年', () {
      expect(monthDateKeyRange(2026, 11),
          const DateKeyRange(from: '2026-11-01', to: '2026-11-30'));
      expect(monthDateKeyRange(2024, 2),
          const DateKeyRange(from: '2024-02-01', to: '2024-02-29'));
      expect(monthDateKeyRange(2026, 12),
          const DateKeyRange(from: '2026-12-01', to: '2026-12-31'));
    });
  });

  group('DateKeyRange 值语义', () {
    test('isEmpty / isScoped / isFull', () {
      expect(const DateKeyRange().isEmpty, isTrue);
      expect(const DateKeyRange().isScoped, isFalse);
      expect(const DateKeyRange(from: '2026-11-01').isScoped, isTrue);
      expect(const DateKeyRange(from: '2026-11-01').isFull, isFalse);
      expect(
        const DateKeyRange(from: '2026-11-01', to: '2026-11-30').isFull,
        isTrue,
      );
    });

    test('isValid 拦住逆序与非法端', () {
      expect(const DateKeyRange().isValid, isTrue);
      expect(
        const DateKeyRange(from: '2026-11-01', to: '2026-11-30').isValid,
        isTrue,
      );
      expect(
        const DateKeyRange(from: '2026-11-30', to: '2026-11-01').isValid,
        isFalse,
      );
      expect(const DateKeyRange(from: '2026-02-30').isValid, isFalse);
    });

    test('== / hashCode / toString', () {
      const DateKeyRange a = DateKeyRange(from: '2026-11-01', to: '2026-11-30');
      const DateKeyRange b = DateKeyRange(from: '2026-11-01', to: '2026-11-30');
      const DateKeyRange c = DateKeyRange(from: '2026-11-02', to: '2026-11-30');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('2026-11-01'));
    });
  });
}
