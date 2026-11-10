import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/content/legal_texts.dart';
import 'package:local_reader/core/router/route_args.dart';
import 'package:local_reader/core/stats/calendar_day_link.dart';
import 'package:local_reader/core/stats/keepsake_calendar_link.dart';

void main() {
  group('isValidDay：跨月补格与严格日期，缺一不可', () {
    test('本月合法日期 → true', () {
      expect(
        CalendarDayLink.isValidDay('2026-11-08', inMonth: true),
        isTrue,
      );
    });

    test('跨月补格一律 false，哪怕日期本身合法', () {
      expect(
        CalendarDayLink.isValidDay('2026-10-31', inMonth: false),
        isFalse,
      );
      expect(
        CalendarDayLink.isValidDay('2026-12-01', inMonth: false),
        isFalse,
      );
    });

    test('非法日期一律 false（DateTime.utc 静默进位被拦下）', () {
      for (final String k in <String>['2026-02-30', '2026-13-01', 'bad', '']) {
        expect(CalendarDayLink.isValidDay(k, inMonth: true), isFalse,
            reason: k);
      }
      expect(CalendarDayLink.isValidDay(null, inMonth: true), isFalse);
    });
  });

  group('normalizedDateKey', () {
    test('合法返回原值，非法返回 null', () {
      expect(
        CalendarDayLink.normalizedDateKey('2026-11-08', inMonth: true),
        '2026-11-08',
      );
      expect(
        CalendarDayLink.normalizedDateKey('2026-11-08', inMonth: false),
        isNull,
      );
      expect(
        CalendarDayLink.normalizedDateKey('2026-02-30', inMonth: true),
        isNull,
      );
    });
  });

  group('noteFor：跨月优先于格式错误', () {
    test('跨月补格给跨月说明，不误导成「日期无效」', () {
      expect(
        CalendarDayLink.noteFor(inMonth: false, dateKey: '2026-10-31'),
        LegalTexts.calendarCrossMonthNote,
      );
      expect(
        CalendarDayLink.noteFor(inMonth: false, dateKey: 'bad'),
        LegalTexts.calendarCrossMonthNote,
      );
    });

    test('本月非法日期给格式说明', () {
      expect(
        CalendarDayLink.noteFor(inMonth: true, dateKey: '2026-02-30'),
        LegalTexts.calendarInvalidDateNote,
      );
    });

    test('本月合法日期无说明', () {
      expect(
        CalendarDayLink.noteFor(inMonth: true, dateKey: '2026-11-08'),
        isEmpty,
      );
    });

    test('两条说明转发 LegalTexts 单一源，且互不相同', () {
      expect(CalendarDayLink.crossMonthNote, LegalTexts.calendarCrossMonthNote);
      expect(
          CalendarDayLink.invalidDateNote, LegalTexts.calendarInvalidDateNote);
      expect(CalendarDayLink.crossMonthNote,
          isNot(CalendarDayLink.invalidDateNote));
    });
  });

  group('两条深链共用同一判据（不会一个禁用、另一个放行）', () {
    test('本月合法日：纪念物与摘录都给出带日期的强类型 Args', () {
      final KeepsakeLibraryArgs? k = KeepsakeCalendarLink.toLibraryFromDay(
        dateKey: '2026-11-08',
        inMonth: true,
      );
      final ExcerptLibraryArgs e = ExcerptLibraryArgs.fromDay(
        CalendarDayLink.normalizedDateKey('2026-11-08', inMonth: true),
      );
      expect(k, isNotNull);
      expect(k!.initialDateKey, '2026-11-08');
      expect(e.initialDateKey, '2026-11-08');
      expect(e.isDayScoped, isTrue);
    });

    test('跨月补格：两条都禁用', () {
      expect(
        KeepsakeCalendarLink.toLibraryFromDay(
          dateKey: '2026-10-31',
          inMonth: false,
        ),
        isNull,
      );
      final ExcerptLibraryArgs e = ExcerptLibraryArgs.fromDay(
        CalendarDayLink.normalizedDateKey('2026-10-31', inMonth: false),
      );
      expect(e.isDayScoped, isFalse);
    });

    test('非法日期：两条都不带日期', () {
      expect(
        KeepsakeCalendarLink.toLibraryFromDay(
          dateKey: '2026-02-30',
          inMonth: true,
        ),
        isNull,
      );
      expect(
        ExcerptLibraryArgs.fromDay(
          CalendarDayLink.normalizedDateKey('2026-02-30', inMonth: true),
        ).isDayScoped,
        isFalse,
      );
    });

    test('KeepsakeCalendarLink 的说明也转发到共享模型', () {
      expect(
          KeepsakeCalendarLink.crossMonthNote, CalendarDayLink.crossMonthNote);
      expect(KeepsakeCalendarLink.invalidDateNote,
          CalendarDayLink.invalidDateNote);
    });
  });

  group('CalendarMonthArgs.fromDateKey 与共享判据一致', () {
    test('合法日定位年月并选中当天', () {
      final CalendarMonthArgs a = CalendarMonthArgs.fromDateKey('2026-11-08');
      expect(a.year, 2026);
      expect(a.month, 11);
      expect(a.selectedDateKey, '2026-11-08');
      expect(a.isDayScoped, isTrue);
    });

    test('非法日回落默认参数', () {
      final CalendarMonthArgs a = CalendarMonthArgs.fromDateKey('2026-02-30');
      expect(a.year, isNull);
      expect(a.selectedDateKey, isNull);
      expect(a.isDayScoped, isFalse);
    });
  });
}
