import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/stats/keepsake_kind.dart';
import 'package:local_reader/core/stats/keepsake_query.dart';
import 'package:local_reader/core/stats/keepsakes.dart';
import 'package:local_reader/core/stats/stats_date.dart';
import 'package:local_reader/core/stats/widget_preview.dart';

Keepsake k(String id, KeepsakeKind kind, DateTime date, {String title = '一枚纪念物'}) =>
    Keepsake(
      id: id,
      kind: kind,
      title: title,
      detail: '由阅读记录生成',
      date: date,
    );

final DateTime oct = DateTime.utc(2026, 10, 7);
final DateTime nov2 = DateTime.utc(2026, 11, 2);
final DateTime nov8 = DateTime.utc(2026, 11, 8);
final DateTime nov9 = DateTime.utc(2026, 11, 9);

/// 11 月 4 枚：起读 1、摘录 2、月度小结 1；10 月 1 枚连续。
final List<Keepsake> data = <Keepsake>[
  k('k1', KeepsakeKind.monthly, nov2, title: '十月小结'),
  k('k2', KeepsakeKind.firstRead, DateTime.utc(2026, 11, 3), title: '第一次翻开书'),
  k('k3', KeepsakeKind.excerpt, nov8, title: '摘下一句'),
  k('k4', KeepsakeKind.excerpt, nov9, title: '又摘一句'),
  k('k5', KeepsakeKind.streak, oct, title: '连续七天'),
];

KeepsakeMonthPreview preview({
  DateTime? monthDate,
  KeepsakeKind? kind,
  List<Keepsake>? items,
}) =>
    KeepsakeMonthPreview.build(
      keepsakes: items ?? data,
      monthDate: monthDate ?? nov9,
      kind: kind,
    );

void main() {
  group('「本月」口径', () {
    test('monthKey / monthLabel 走 stats_date，不读 DateTime.now()', () {
      final KeepsakeMonthPreview p = preview();
      expect(p.monthKey, '2026-11');
      expect(p.monthLabel, monthLabelOf(2026, 11));
      expect(p.monthKey, monthKeyOf(nov9));
    });

    test('传入不同基准日结果不同，证明没有隐式读系统时间', () {
      expect(preview(monthDate: oct).monthKey, '2026-10');
      expect(preview(monthDate: oct).totalInMonth, 1);
      expect(preview(monthDate: nov9).totalInMonth, 4);
    });
  });

  group('不带类型筛选', () {
    test('本月 4 枚、命中 4 枚、类型分布三档', () {
      final KeepsakeMonthPreview p = preview();
      expect(p.totalInMonth, 4);
      expect(p.matched, 4);
      expect(p.isEmpty, isFalse);
      expect(p.hasAnyInMonth, isTrue);
      expect(p.emptyKind, KeepsakeMonthEmptyKind.none);
      expect(p.perKind[KeepsakeKind.excerpt], 2);
      expect(p.perKind[KeepsakeKind.firstRead], 1);
      expect(p.perKind[KeepsakeKind.monthly], 1);
      expect(p.perKind.length, 6);
    });

    test('kindOptions 只列本月出现过的类型，按枚举序', () {
      final List<KeepsakeKindOption> o = preview().kindOptions;
      expect(o.map((KeepsakeKindOption e) => e.kind).toList(), <KeepsakeKind>[
        KeepsakeKind.firstRead,
        KeepsakeKind.excerpt,
        KeepsakeKind.monthly,
      ]);
      expect(o.firstWhere((KeepsakeKindOption e) => e.kind == KeepsakeKind.excerpt).count, 2);
    });

    test('headline / subline 由模型给出，页面不自己拼数字', () {
      final KeepsakeMonthPreview p = preview();
      expect(p.headline, contains('2026 年 11 月'));
      expect(p.headline, contains('4 枚'));
      // 最近一枚按日期降序是 11-09 的「又摘一句」。
      expect(p.latestInScope?.id, 'k4');
      expect(p.subline, contains('又摘一句'));
      expect(p.latest?.id, 'k4');
    });

    test('items 是本月 ∧ 类型的结果，与 KeepsakeQuery.apply 完全一致', () {
      final KeepsakeMonthPreview p = preview(kind: KeepsakeKind.excerpt);
      final List<Keepsake> direct = KeepsakeQuery.apply(
        keepsakes: data,
        filter: const KeepsakeFilter(kind: KeepsakeKind.excerpt, monthKey: '2026-11'),
      );
      expect(p.items.map((Keepsake e) => e.id).toList(),
          direct.map((Keepsake e) => e.id).toList());
      expect(p.matched, 2);
    });
  });

  group('按类型筛选', () {
    test('本月有该类型 → 只统计该类型，但 perKind 仍是本月全量', () {
      final KeepsakeMonthPreview p = preview(kind: KeepsakeKind.excerpt);
      expect(p.matched, 2);
      expect(p.totalInMonth, 4, reason: '全月条数不受类型筛选影响');
      expect(p.perKind[KeepsakeKind.firstRead], 1);
      expect(p.headline, contains('摘录'));
      expect(p.latestInScope?.id, 'k4');
      expect(p.emptyKind, KeepsakeMonthEmptyKind.none);
    });

    test('本月有纪念物但该类型 0 枚 → kindHasNone', () {
      final KeepsakeMonthPreview p = preview(kind: KeepsakeKind.streak);
      expect(p.matched, 0);
      expect(p.totalInMonth, 4);
      expect(p.perKind[KeepsakeKind.streak], 0);
      expect(p.latestInScope, isNull);
      expect(p.latest, isNotNull, reason: '本月全量仍有一枚，供空状态区分口径');
      expect(p.emptyKind, KeepsakeMonthEmptyKind.kindHasNone);
      expect(p.headline, contains('暂无纪念物'));
      expect(p.subline, isEmpty);
      expect(p.kindOptions.isNotEmpty, isTrue);
    });

    test('10 月切到 excerpt → 同样是 kindHasNone', () {
      final KeepsakeMonthPreview p =
          preview(monthDate: oct, kind: KeepsakeKind.excerpt);
      expect(p.totalInMonth, 1);
      expect(p.matched, 0);
      expect(p.emptyKind, KeepsakeMonthEmptyKind.kindHasNone);
    });
  });

  group('空状态优先级', () {
    test('本月零纪念物 → noMonth（优先于 kindHasNone）', () {
      final KeepsakeMonthPreview p = preview(
        monthDate: DateTime.utc(2026, 8, 1),
        kind: KeepsakeKind.streak,
      );
      expect(p.totalInMonth, 0);
      expect(p.hasAnyInMonth, isFalse);
      expect(p.emptyKind, KeepsakeMonthEmptyKind.noMonth);
      expect(p.kindOptions, isEmpty);
      expect(p.latest, isNull);
    });

    test('全量零纪念物 → noMonth', () {
      final KeepsakeMonthPreview p = preview(items: const <Keepsake>[]);
      expect(p.totalInMonth, 0);
      expect(p.emptyKind, KeepsakeMonthEmptyKind.noMonth);
    });
  });

  group('静态边界文档口径', () {
    test('预览不缓存：每次 build 从传入列表重算', () {
      final List<Keepsake> first = <Keepsake>[data.first];
      final KeepsakeMonthPreview a =
          KeepsakeMonthPreview.build(keepsakes: first, monthDate: nov9);
      final List<Keepsake> second = <Keepsake>[data.first, data[2]];
      final KeepsakeMonthPreview b =
          KeepsakeMonthPreview.build(keepsakes: second, monthDate: nov9);
      expect(a.matched, 1);
      expect(b.matched, 2, reason: '同一份模型不持有旧列表引用');
    });
  });
}
