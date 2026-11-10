import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/content/legal_texts.dart';
import 'package:local_reader/core/router/route_args.dart';
import 'package:local_reader/core/stats/keepsake_calendar_link.dart';
import 'package:local_reader/core/stats/stats_date.dart';

void main() {
  group('dateKey / monthKey 严格解析', () {
    test('合法 dateKey 反解为 UTC 年月日', () {
      final DateTime? d = tryParseDateKey('2026-11-08');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 11);
      expect(d.day, 8);
      expect(dateKeyOf(d), '2026-11-08');
    });

    test('DateTime.utc 会静默进位的非法日期一律拦下', () {
      expect(tryParseDateKey('2026-02-30'), isNull);
      expect(tryParseDateKey('2026-13-01'), isNull);
      expect(tryParseDateKey('2026-00-10'), isNull);
    });

    test('格式不对 / 长度不对 / null 一律 null', () {
      expect(tryParseDateKey(null), isNull);
      expect(tryParseDateKey(''), isNull);
      expect(tryParseDateKey('2026-1-8'), isNull);
      expect(tryParseDateKey('2026/11/08'), isNull);
      expect(tryParseDateKey('2026-1x-08'), isNull);
      expect(tryParseDateKey('2026-11-08-extra'), isNull);
    });

    test('monthKey 解析与回拼校验', () {
      expect(tryParseMonthKey('2026-11')?.key, '2026-11');
      expect(tryParseMonthKey('2026-13'), isNull);
      expect(tryParseMonthKey('2026-1'), isNull);
      expect(tryParseMonthKey(null), isNull);
    });

    test('monthKeyOfDateKey 取月份前缀', () {
      expect(monthKeyOfDateKey('2026-11-08'), '2026-11');
      expect(monthKeyOfDateKey('2026-02-30'), isNull);
    });
  });

  group('CalendarMonthArgs 工厂', () {
    test('fromDateKey 定位年月并选中当天', () {
      final CalendarMonthArgs a = CalendarMonthArgs.fromDateKey('2026-11-08');
      expect(a.year, 2026);
      expect(a.month, 11);
      expect(a.selectedDateKey, '2026-11-08');
      expect(a.isDayScoped, isTrue);
    });

    test('非法 dateKey 回落默认参数，不把脏字符串塞进路由', () {
      final CalendarMonthArgs a = CalendarMonthArgs.fromDateKey('2026-02-30');
      expect(a.year, isNull);
      expect(a.month, isNull);
      expect(a.selectedDateKey, isNull);
      expect(a.isDayScoped, isFalse);
    });

    test('fromMonthKey 只定位整月，不强制选中日', () {
      final CalendarMonthArgs a = CalendarMonthArgs.fromMonthKey('2026-10');
      expect(a.year, 2026);
      expect(a.month, 10);
      expect(a.selectedDateKey, isNull);
    });
  });

  group('KeepsakeLibraryArgs 工厂', () {
    test('fromDay 由日期反解月份，不信任另传的月份', () {
      final KeepsakeLibraryArgs a = KeepsakeLibraryArgs.fromDay('2026-11-08');
      expect(a.initialDateKey, '2026-11-08');
      expect(a.initialMonthKey, '2026-11');
      expect(a.isDayScoped, isTrue);
      expect(a.isScoped, isTrue);
      expect(a.isConsistent, isTrue);
    });

    test('fromMonth 只按整月', () {
      final KeepsakeLibraryArgs a = KeepsakeLibraryArgs.fromMonth('2026-10');
      expect(a.initialMonthKey, '2026-10');
      expect(a.initialDateKey, isNull);
      expect(a.isDayScoped, isFalse);
    });

    test('fromCard 保留第十八轮行为（类型 + 月份，不带日期）', () {
      final KeepsakeLibraryArgs a =
          KeepsakeLibraryArgs.fromCard(null, '2026-09');
      expect(a.initialMonthKey, '2026-09');
      expect(a.initialDateKey, isNull);
      expect(KeepsakeLibraryArgs.fromCard(null, '').initialMonthKey, isNull);
    });

    test('isConsistent 拦住「日期 11 月、月份却是 10 月」的脏组合', () {
      const KeepsakeLibraryArgs bad = KeepsakeLibraryArgs(
        initialDateKey: '2026-11-08',
        initialMonthKey: '2026-10',
      );
      expect(bad.isConsistent, isFalse);
      expect(
        const KeepsakeLibraryArgs(initialDateKey: '2026-11-08').isConsistent,
        isFalse,
        reason: '带日期时月份不能为空',
      );
      expect(const KeepsakeLibraryArgs().isConsistent, isTrue);
    });

    test('非法日期 / 非法月份回落空参数', () {
      expect(KeepsakeLibraryArgs.fromDay('2026-02-30').isScoped, isFalse);
      expect(KeepsakeLibraryArgs.fromMonth('bad').initialMonthKey, isNull);
    });
  });

  group('日历 → 纪念物册', () {
    test('本月合法日期给出「只看这天」的强类型 Args', () {
      final KeepsakeLibraryArgs? a = KeepsakeCalendarLink.toLibraryFromDay(
        dateKey: '2026-11-08',
        inMonth: true,
      );
      expect(a, isNotNull);
      expect(a!.initialDateKey, '2026-11-08');
      expect(a.initialMonthKey, '2026-11');
      expect(a.isConsistent, isTrue);
    });

    test('跨月补格不提供深链（对齐格不该跳到另一个月）', () {
      expect(
        KeepsakeCalendarLink.toLibraryFromDay(
          dateKey: '2026-10-31',
          inMonth: false,
        ),
        isNull,
      );
    });

    test('非法 dateKey 不提供深链', () {
      expect(
        KeepsakeCalendarLink.toLibraryFromDay(
          dateKey: '2026-02-30',
          inMonth: true,
        ),
        isNull,
      );
    });

    test('整月深链只带月份，不带日期', () {
      final KeepsakeLibraryArgs? a =
          KeepsakeCalendarLink.toLibraryFromMonth('2026-11');
      expect(a, isNotNull);
      expect(a!.initialMonthKey, '2026-11');
      expect(a.initialDateKey, isNull);
      expect(KeepsakeCalendarLink.toLibraryFromMonth('bad'), isNull);
    });
  });

  group('纪念物册 → 日历', () {
    test('某一枚所在日：定位年月并选中当天', () {
      final CalendarMonthArgs? a =
          KeepsakeCalendarLink.toCalendarFromDay('2026-11-08');
      expect(a, isNotNull);
      expect(a!.year, 2026);
      expect(a.month, 11);
      expect(a.selectedDateKey, '2026-11-08');
    });

    test('非法日期返回 null，页面按钮直接不渲染', () {
      expect(KeepsakeCalendarLink.toCalendarFromDay('nope'), isNull);
      expect(KeepsakeCalendarLink.toCalendarFromDay(null), isNull);
    });

    test('当前月份 → 整月日历，不强制选中日', () {
      final CalendarMonthArgs? a =
          KeepsakeCalendarLink.toCalendarFromMonth('2026-11');
      expect(a, isNotNull);
      expect(a!.year, 2026);
      expect(a.month, 11);
      expect(a.selectedDateKey, isNull);
      expect(KeepsakeCalendarLink.toCalendarFromMonth('2026-13'), isNull);
    });
  });

  group('同月校验与说明文案', () {
    test('sameMonth：两边都合法且同月才为 true', () {
      expect(KeepsakeCalendarLink.sameMonth('2026-11-08', '2026-11'), isTrue);
      expect(KeepsakeCalendarLink.sameMonth('2026-11-08', '2026-10'), isFalse);
      expect(KeepsakeCalendarLink.sameMonth(null, '2026-11'), isFalse);
      expect(KeepsakeCalendarLink.sameMonth('2026-11-08', null), isFalse);
      expect(KeepsakeCalendarLink.sameMonth('bad', '2026-11'), isFalse);
    });

    test('禁用说明转发 LegalTexts 单一源，不复制中文句子', () {
      expect(KeepsakeCalendarLink.crossMonthNote,
          LegalTexts.calendarCrossMonthNote);
      expect(KeepsakeCalendarLink.invalidDateNote,
          LegalTexts.calendarInvalidDateNote);
      expect(KeepsakeCalendarLink.crossMonthNote,
          isNot(KeepsakeCalendarLink.invalidDateNote));
    });
  });
}
