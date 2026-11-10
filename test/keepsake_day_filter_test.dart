import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/stats/keepsake_kind.dart';
import 'package:local_reader/core/stats/keepsake_query.dart';
import 'package:local_reader/core/stats/keepsakes.dart';
import 'package:local_reader/core/stats/stats_date.dart';

Keepsake k(String id, KeepsakeKind kind, DateTime date,
        {String title = '一枚纪念物'}) =>
    Keepsake(
      id: id,
      kind: kind,
      title: title,
      detail: '由阅读记录生成',
      date: date,
    );

final DateTime oct7 = DateTime.utc(2026, 10, 7);
final DateTime nov2 = DateTime.utc(2026, 11, 2);
final DateTime nov8 = DateTime.utc(2026, 11, 8);
final DateTime nov9 = DateTime.utc(2026, 11, 9);

/// 11 月 4 枚（其中 11-08 两枚）、10 月 1 枚。
final List<Keepsake> data = <Keepsake>[
  k('k1', KeepsakeKind.monthly, nov2, title: '十月小结'),
  k('k2', KeepsakeKind.firstRead, nov2, title: '第一次翻开书'),
  k('k3', KeepsakeKind.excerpt, nov8, title: '摘下一句'),
  k('k4', KeepsakeKind.excerpt, nov8, title: '又摘一句'),
  k('k5', KeepsakeKind.streak, oct7, title: '连续七天'),
];

List<String> ids(List<Keepsake> items) =>
    items.map((Keepsake e) => e.id).toList();

void main() {
  group('按日筛选 matches / apply', () {
    test('dateKey 只命中那一天', () {
      final List<Keepsake> out = KeepsakeQuery.apply(
        keepsakes: data,
        filter: const KeepsakeFilter(dateKey: '2026-11-08'),
      );
      expect(ids(out), <String>['k3', 'k4']);
    });

    test('日期 ∧ 月份同时给定时取交集', () {
      final List<Keepsake> out = KeepsakeQuery.apply(
        keepsakes: data,
        filter: const KeepsakeFilter(
          dateKey: '2026-11-08',
          monthKey: '2026-11',
        ),
      );
      expect(out.length, 2);
    });

    test('日期 ∧ 类型 ∧ 关键词', () {
      final List<Keepsake> out = KeepsakeQuery.apply(
        keepsakes: data,
        filter: const KeepsakeFilter(
          dateKey: '2026-11-08',
          kind: KeepsakeKind.excerpt,
          query: '又摘',
        ),
      );
      expect(ids(out), <String>['k4']);
    });

    test('不存在的日期返回空列表，不回落整月', () {
      final List<Keepsake> out = KeepsakeQuery.apply(
        keepsakes: data,
        filter: const KeepsakeFilter(dateKey: '2026-11-03'),
      );
      expect(out, isEmpty);
    });

    test('分面计数带日期条件：类型 chip 的数字只统计这一天', () {
      final List<KeepsakeKindOption> opts = KeepsakeQuery.kindOptions(
        data,
        filter: const KeepsakeFilter(dateKey: '2026-11-08'),
      );
      expect(
          opts
              .firstWhere(
                  (KeepsakeKindOption o) => o.kind == KeepsakeKind.excerpt)
              .count,
          2);
      expect(
          opts
              .firstWhere(
                  (KeepsakeKindOption o) => o.kind == KeepsakeKind.firstRead)
              .count,
          0);
    });
  });

  group('normalizeFilter：深链进来后的统一归一化', () {
    test('月份仍在数据里、日期合法且同月 → 原样保留', () {
      const KeepsakeFilter f = KeepsakeFilter(
        dateKey: '2026-11-08',
        monthKey: '2026-11',
      );
      expect(
        KeepsakeQuery.normalizeFilter(f, availableMonths: <String>['2026-11']),
        f,
      );
    });

    test('失效月份清掉（第十八轮既有行为）', () {
      const KeepsakeFilter f = KeepsakeFilter(monthKey: '2026-08');
      expect(
        KeepsakeQuery.normalizeFilter(f, availableMonths: <String>['2026-11'])
            .monthKey,
        isNull,
      );
    });

    test('非法日期清掉，但保留月份，不把整月视图一起丢掉', () {
      const KeepsakeFilter f = KeepsakeFilter(
        dateKey: '2026-02-30',
        monthKey: '2026-11',
      );
      final KeepsakeFilter out = KeepsakeQuery.normalizeFilter(
        f,
        availableMonths: <String>['2026-11'],
      );
      expect(out.dateKey, isNull);
      expect(out.monthKey, '2026-11');
    });

    test('日期与月份不同月 → 以日期为准修正月份，不静默丢深链', () {
      const KeepsakeFilter f = KeepsakeFilter(
        dateKey: '2026-11-08',
        monthKey: '2026-10',
      );
      final KeepsakeFilter out = KeepsakeQuery.normalizeFilter(
        f,
        availableMonths: <String>['2026-10', '2026-11'],
      );
      expect(out.dateKey, '2026-11-08');
      expect(out.monthKey, '2026-11');
    });

    test('带日期但月份为空 → 补齐同月月份', () {
      const KeepsakeFilter f = KeepsakeFilter(dateKey: '2026-11-08');
      final KeepsakeFilter out = KeepsakeQuery.normalizeFilter(
        f,
        availableMonths: <String>['2026-11'],
      );
      expect(out.monthKey, '2026-11');
      expect(monthKeyOfDateKey(out.dateKey), out.monthKey);
    });
  });

  group('countForDay 与空状态分支', () {
    test('countForDay 算全量，不受当前筛选影响', () {
      expect(KeepsakeQuery.countForDay(data, '2026-11-08'), 2);
      expect(KeepsakeQuery.countForDay(data, '2026-11-03'), 0);
      expect(KeepsakeQuery.countForDay(const <Keepsake>[], '2026-11-08'), 0);
    });

    test('该日全量 0 枚 → dayHasNone（引导回日历换一天）', () {
      const KeepsakeFilter f = KeepsakeFilter(
        dateKey: '2026-11-03',
        monthKey: '2026-11',
      );
      expect(
        KeepsakeQuery.emptyKind(
          total: data.length,
          matched: 0,
          filter: f,
          dayTotalCount: KeepsakeQuery.countForDay(data, '2026-11-03'),
        ),
        KeepsakeEmptyKind.dayHasNone,
      );
    });

    test('该日有 2 枚但被类型筛掉 → noResult，不误报 dayHasNone', () {
      const KeepsakeFilter f = KeepsakeFilter(
        dateKey: '2026-11-08',
        monthKey: '2026-11',
        kind: KeepsakeKind.streak,
      );
      expect(
        KeepsakeQuery.emptyKind(
          total: data.length,
          matched: 0,
          filter: f,
          kindTotalCount: KeepsakeQuery.countForKind(data, KeepsakeKind.streak),
          dayTotalCount: KeepsakeQuery.countForDay(data, '2026-11-08'),
        ),
        KeepsakeEmptyKind.noResult,
      );
    });

    test('类型从未产生优先于日期从未产生', () {
      // goalReached 在演示数据里全量 0 枚，而 11-03 也没有任何纪念物。
      const KeepsakeFilter g = KeepsakeFilter(
        dateKey: '2026-11-03',
        kind: KeepsakeKind.goalReached,
      );
      expect(
        KeepsakeQuery.emptyKind(
          total: data.length,
          matched: 0,
          filter: g,
          kindTotalCount: 0,
          dayTotalCount: 0,
        ),
        KeepsakeEmptyKind.kindHasNone,
      );
    });

    test('有命中 → none；全书库空 → noKeepsakes', () {
      expect(
        KeepsakeQuery.emptyKind(
          total: 5,
          matched: 2,
          filter: const KeepsakeFilter(dateKey: '2026-11-08'),
          dayTotalCount: 2,
        ),
        KeepsakeEmptyKind.none,
      );
      expect(
        KeepsakeQuery.emptyKind(
          total: 0,
          matched: 0,
          filter: const KeepsakeFilter(dateKey: '2026-11-08'),
          dayTotalCount: 0,
        ),
        KeepsakeEmptyKind.noKeepsakes,
      );
    });
  });

  group('KeepsakeFilter 值语义与清空语义', () {
    test('dateKey 参与 == / hashCode', () {
      const KeepsakeFilter a = KeepsakeFilter(dateKey: '2026-11-08');
      const KeepsakeFilter b = KeepsakeFilter(dateKey: '2026-11-09');
      expect(a, isNot(b));
      expect(a, const KeepsakeFilter(dateKey: '2026-11-08'));
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('isEmpty 包含 dateKey；isDayScoped', () {
      expect(const KeepsakeFilter().isEmpty, isTrue);
      expect(const KeepsakeFilter(dateKey: '2026-11-08').isEmpty, isFalse);
      expect(const KeepsakeFilter(dateKey: '2026-11-08').isDayScoped, isTrue);
    });

    test('clearDate 只清日期、不动月份（清除后回到整月）', () {
      const KeepsakeFilter f = KeepsakeFilter(
        dateKey: '2026-11-08',
        monthKey: '2026-11',
        query: '雪',
      );
      final KeepsakeFilter out = f.copyWith(clearDate: true);
      expect(out.dateKey, isNull);
      expect(out.monthKey, '2026-11');
      expect(out.query, '雪');
    });

    test('copyWith(dateKey: null) 不能表示清空（沿用显式开关纪律）', () {
      const KeepsakeFilter f = KeepsakeFilter(dateKey: '2026-11-08');
      expect(f.copyWith(dateKey: null).dateKey, '2026-11-08');
      expect(f.copyWith(clearDate: true).dateKey, isNull);
    });
  });
}
