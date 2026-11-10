import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/stats/keepsake_kind.dart';
import 'package:local_reader/core/stats/keepsake_query.dart';
import 'package:local_reader/core/stats/keepsakes.dart';
import 'package:local_reader/core/stats/stats_date.dart';

Keepsake k(String id, KeepsakeKind kind, String dateKey) {
  final DateTime d = tryParseDateKey(dateKey)!;
  return Keepsake(
    id: id,
    kind: kind,
    title: '纪念物 $id',
    detail: '由阅读记录生成',
    date: d,
  );
}

/// 10 月 2 枚、11 月 3 枚、12 月 1 枚，跨三个月。
final List<Keepsake> data = <Keepsake>[
  k('k1', KeepsakeKind.firstRead, '2026-10-07'),
  k('k2', KeepsakeKind.streak, '2026-10-31'),
  k('k3', KeepsakeKind.excerpt, '2026-11-02'),
  k('k4', KeepsakeKind.excerpt, '2026-11-08'),
  k('k5', KeepsakeKind.monthlyBest, '2026-11-20'),
  k('k6', KeepsakeKind.monthly, '2026-12-01'),
];

List<String> ids(List<Keepsake> items) => items.map((Keepsake e) => e.id).toList();

/// 本文件所有命中断言统一按时间升序，避免默认 newest 让期望值难读。
/// 排序行为本身由 `keepsake_filter_test.dart` 覆盖。
List<String> idsOf(KeepsakeFilter f) => ids(KeepsakeQuery.apply(
      keepsakes: data,
      filter: f,
      sort: KeepsakeSort.oldest,
    ));

void main() {
  group('matches / apply：闭区间筛选', () {
    test('完整闭区间两端包含', () {
      expect(
        idsOf(const KeepsakeFilter(
          fromDateKey: '2026-11-02',
          toDateKey: '2026-11-20',
        )),
        <String>['k3', 'k4', 'k5'],
      );
    });

    test('只设起点 / 只设终点', () {
      expect(idsOf(const KeepsakeFilter(fromDateKey: '2026-11-20')),
          <String>['k5', 'k6']);
      expect(idsOf(const KeepsakeFilter(toDateKey: '2026-10-31')),
          <String>['k1', 'k2']);
    });

    test('范围跨月，不与 monthKey 冲突（归一化会清掉月份）', () {
      const KeepsakeFilter raw = KeepsakeFilter(
        fromDateKey: '2026-10-31',
        toDateKey: '2026-11-08',
        monthKey: '2026-10',
      );
      final KeepsakeFilter f = KeepsakeQuery.normalizeFilter(
        raw,
        availableMonths: KeepsakeQuery.monthKeys(data),
      );
      expect(f.monthKey, isNull);
      expect(idsOf(f), <String>['k2', 'k3', 'k4']);
    });

    test('范围可叠加类型与关键词', () {
      expect(
        idsOf(const KeepsakeFilter(
          fromDateKey: '2026-11-01',
          toDateKey: '2026-11-30',
          kind: KeepsakeKind.excerpt,
        )),
        <String>['k3', 'k4'],
      );
    });

    test('区间外返回空，不回落全量', () {
      expect(
        KeepsakeQuery.apply(
          keepsakes: data,
          filter: const KeepsakeFilter(
            fromDateKey: '2027-01-01',
            toDateKey: '2027-01-31',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('normalizeFilter：范围归一化（五条口径）', () {
    test('起 > 止自动交换，保留用户意图', () {
      final KeepsakeFilter f = KeepsakeQuery.normalizeFilter(
        const KeepsakeFilter(
          fromDateKey: '2026-11-20',
          toDateKey: '2026-11-02',
        ),
        availableMonths: KeepsakeQuery.monthKeys(data),
      );
      expect(f.fromDateKey, '2026-11-02');
      expect(f.toDateKey, '2026-11-20');
      expect(f.isRangeScoped, isTrue);
      expect(f.dateKey, isNull);
      expect(f.monthKey, isNull);
    });

    test('非法端清掉，另一端保留', () {
      final KeepsakeFilter f = KeepsakeQuery.normalizeFilter(
        const KeepsakeFilter(
          fromDateKey: '2026-02-30',
          toDateKey: '2026-11-20',
        ),
        availableMonths: KeepsakeQuery.monthKeys(data),
      );
      expect(f.fromDateKey, isNull);
      expect(f.toDateKey, '2026-11-20');
      expect(f.isRangeScoped, isTrue);
    });

    test('两端都非法 → 完全不带范围', () {
      final KeepsakeFilter f = KeepsakeQuery.normalizeFilter(
        const KeepsakeFilter(
          fromDateKey: 'bad',
          toDateKey: 'worse',
        ),
        availableMonths: KeepsakeQuery.monthKeys(data),
      );
      expect(f.isRangeScoped, isFalse);
      expect(f.isEmpty, isTrue);
    });

    test('有范围时清掉单日深链，避免两个条件打架', () {
      final KeepsakeFilter f = KeepsakeQuery.normalizeFilter(
        const KeepsakeFilter(
          dateKey: '2026-11-08',
          monthKey: '2026-11',
          fromDateKey: '2026-11-01',
          toDateKey: '2026-11-30',
        ),
        availableMonths: KeepsakeQuery.monthKeys(data),
      );
      expect(f.dateKey, isNull);
      expect(f.monthKey, isNull);
      expect(f.isRangeScoped, isTrue);
      expect(idsOf(f), <String>['k3', 'k4', 'k5']);
    });

    test('第二十轮既有行为不被回归：失效月份清掉', () {
      final KeepsakeFilter f = KeepsakeQuery.normalizeFilter(
        const KeepsakeFilter(monthKey: '2026-08'),
        availableMonths: KeepsakeQuery.monthKeys(data),
      );
      expect(f.monthKey, isNull);
      expect(f.isRangeScoped, isFalse);
    });

    test('第二十轮既有行为不被回归：非法单日清掉但保留月份', () {
      final KeepsakeFilter f = KeepsakeQuery.normalizeFilter(
        const KeepsakeFilter(dateKey: '2026-02-30', monthKey: '2026-11'),
        availableMonths: KeepsakeQuery.monthKeys(data),
      );
      expect(f.dateKey, isNull);
      expect(f.monthKey, '2026-11');
    });

    test('第二十轮既有行为不被回归：日期与月份不同月以日期为准', () {
      final KeepsakeFilter f = KeepsakeQuery.normalizeFilter(
        const KeepsakeFilter(dateKey: '2026-11-08', monthKey: '2026-10'),
        availableMonths: KeepsakeQuery.monthKeys(data),
      );
      expect(f.dateKey, '2026-11-08');
      expect(f.monthKey, '2026-11');
    });
  });

  group('分面计数带范围条件', () {
    test('类型 chip 只统计这段区间，不显示全量数字', () {
      final List<KeepsakeKindOption> opts = KeepsakeQuery.kindOptions(
        data,
        filter: const KeepsakeFilter(
          fromDateKey: '2026-11-01',
          toDateKey: '2026-11-30',
        ),
      );
      expect(
        opts
            .firstWhere((KeepsakeKindOption o) =>
                o.kind == KeepsakeKind.excerpt)
            .count,
        2,
      );
      expect(
        opts
            .firstWhere((KeepsakeKindOption o) =>
                o.kind == KeepsakeKind.streak)
            .count,
        0,
      );
    });
  });

  group('countForRange 与空状态', () {
    test('countForRange 算全量、闭区间、可单端', () {
      expect(
        KeepsakeQuery.countForRange(data,
            from: '2026-11-02', to: '2026-11-20'),
        3,
      );
      expect(KeepsakeQuery.countForRange(data, from: '2026-11-20'), 2);
      expect(KeepsakeQuery.countForRange(data, to: '2026-10-31'), 2);
      expect(KeepsakeQuery.countForRange(data,
          from: '2027-01-01', to: '2027-01-31'), 0);
      expect(
          KeepsakeQuery.countForRange(const <Keepsake>[], from: '2026-01-01'),
          0);
    });

    test('该区间全量 0 枚 → rangeHasNone', () {
      expect(
        KeepsakeQuery.emptyKind(
          total: data.length,
          matched: 0,
          filter: const KeepsakeFilter(
            fromDateKey: '2027-01-01',
            toDateKey: '2027-01-31',
          ),
          rangeTotalCount: 0,
        ),
        KeepsakeEmptyKind.rangeHasNone,
      );
    });

    test('该区间有 3 枚但被类型筛掉 → noResult，不误报 rangeHasNone', () {
      const KeepsakeFilter f = KeepsakeFilter(
        fromDateKey: '2026-11-01',
        toDateKey: '2026-11-30',
        kind: KeepsakeKind.streak,
      );
      expect(
        KeepsakeQuery.emptyKind(
          total: data.length,
          matched: 0,
          filter: f,
          kindTotalCount:
              KeepsakeQuery.countForKind(data, KeepsakeKind.streak),
          rangeTotalCount: KeepsakeQuery.countForRange(data,
              from: f.fromDateKey, to: f.toDateKey),
        ),
        KeepsakeEmptyKind.noResult,
      );
    });

    test('优先级：有命中 > 全库空 > 类型无 > 单日无 > 区间无 > noResult', () {
      expect(
        KeepsakeQuery.emptyKind(
            total: 6,
            matched: 1,
            filter: const KeepsakeFilter(fromDateKey: '2027-01-01'),
            rangeTotalCount: 0),
        KeepsakeEmptyKind.none,
      );
      expect(
        KeepsakeQuery.emptyKind(
            total: 0,
            matched: 0,
            filter: const KeepsakeFilter(fromDateKey: '2027-01-01'),
            rangeTotalCount: 0),
        KeepsakeEmptyKind.noKeepsakes,
      );
      expect(
        KeepsakeQuery.emptyKind(
          total: 6,
          matched: 0,
          filter: const KeepsakeFilter(
            fromDateKey: '2027-01-01',
            kind: KeepsakeKind.goalReached,
          ),
          kindTotalCount: 0,
          rangeTotalCount: 0,
        ),
        KeepsakeEmptyKind.kindHasNone,
      );
    });
  });

  group('KeepsakeFilter 值语义与清空语义', () {
    test('范围字段参与 == / hashCode', () {
      const KeepsakeFilter a =
          KeepsakeFilter(fromDateKey: '2026-11-01', toDateKey: '2026-11-30');
      const KeepsakeFilter b =
          KeepsakeFilter(fromDateKey: '2026-11-01', toDateKey: '2026-11-20');
      expect(a, isNot(b));
      expect(a, const KeepsakeFilter(
          fromDateKey: '2026-11-01', toDateKey: '2026-11-30'));
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('isEmpty 含范围；isRangeScoped', () {
      expect(const KeepsakeFilter().isEmpty, isTrue);
      expect(const KeepsakeFilter(fromDateKey: '2026-11-01').isEmpty, isFalse);
      expect(
          const KeepsakeFilter(toDateKey: '2026-11-30').isRangeScoped, isTrue);
    });

    test('clearRange 一次清两端；clearFromDate / clearToDate 各清一端', () {
      const KeepsakeFilter f = KeepsakeFilter(
        fromDateKey: '2026-11-01',
        toDateKey: '2026-11-30',
        query: '雪',
      );
      final KeepsakeFilter cleared = f.copyWith(clearRange: true);
      expect(cleared.isRangeScoped, isFalse);
      expect(cleared.query, '雪');
      expect(f.copyWith(clearFromDate: true).fromDateKey, isNull);
      expect(f.copyWith(clearFromDate: true).toDateKey, '2026-11-30');
      expect(f.copyWith(clearToDate: true).fromDateKey, '2026-11-01');
      expect(f.copyWith(clearToDate: true).toDateKey, isNull);
    });

    test('copyWith(fromDateKey: null) 不能表示清空（显式开关纪律）', () {
      const KeepsakeFilter f =
          KeepsakeFilter(fromDateKey: '2026-11-01', toDateKey: '2026-11-30');
      expect(f.copyWith(fromDateKey: null).fromDateKey, '2026-11-01');
      expect(f.copyWith(toDateKey: null).toDateKey, '2026-11-30');
    });
  });

  group('快捷区间口径（固定基准日）', () {
    test('monthDateKeyRange 生成整月，基准日取快照末日不读时钟', () {
      final DateTime base = tryParseDateKey('2026-11-20')!;
      final DateKeyRange r = monthDateKeyRange(base.year, base.month);
      expect(r.from, '2026-11-01');
      expect(r.to, '2026-11-30');
      expect(idsOf(KeepsakeFilter(fromDateKey: r.from, toDateKey: r.to)),
          <String>['k3', 'k4', 'k5']);
    });

    test('最近 7 天由 dateKeyAddDays 生成，跨月正确', () {
      final String? from = dateKeyAddDays('2026-11-02', -6);
      expect(from, '2026-10-27');
      expect(
          idsOf(KeepsakeFilter(fromDateKey: from, toDateKey: '2026-11-02')),
          <String>['k2', 'k3']);
    });
  });
}
