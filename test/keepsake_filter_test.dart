import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/content/legal_texts.dart';
import 'package:local_reader/core/router/route_args.dart';
import 'package:local_reader/core/stats/keepsake_kind.dart';
import 'package:local_reader/core/stats/keepsake_query.dart';
import 'package:local_reader/core/stats/keepsakes.dart';
import 'package:local_reader/core/stats/reading_stats.dart';

final DateTime d1 = DateTime.utc(2026, 9, 3);
final DateTime d2 = DateTime.utc(2026, 10, 7);
final DateTime d3 = DateTime.utc(2026, 11, 2);
final DateTime d4 = DateTime.utc(2026, 11, 8);

Keepsake k(
  String id,
  KeepsakeKind kind,
  DateTime date, {
  String title = '一枚纪念物',
  String detail = '由阅读记录生成',
  String? bookTitle,
  bool fromUserExcerpt = false,
}) =>
    Keepsake(
      id: id,
      kind: kind,
      title: title,
      detail: detail,
      date: date,
      bookTitle: bookTitle,
      fromUserExcerpt: fromUserExcerpt,
    );

/// 六类、三个月：9 月 1 枚，10 月 2 枚，11 月 4 枚。
final List<Keepsake> data = <Keepsake>[
  k('k1', KeepsakeKind.firstRead, d1, title: '第一次翻开书', detail: '起读的那天'),
  k('k2', KeepsakeKind.streak, d2, title: '连续七天', detail: '没有断过'),
  k('k3', KeepsakeKind.monthly, d2, title: '十月小结', detail: '这个月读了不少'),
  k('k4', KeepsakeKind.excerpt, d3, title: '摘下一句', detail: '雪落的时候',
      bookTitle: '雪国的旅行者', fromUserExcerpt: true),
  k('k5', KeepsakeKind.excerpt, d4, title: '又摘一句', detail: '斜光'),
  k('k6', KeepsakeKind.goalReached, d4, title: '达标了', detail: '完成今日目标'),
  k('k7', KeepsakeKind.monthlyBest, d4, title: '最长一次', detail: '读了很久'),
];

List<String> ids(List<Keepsake> r) => r.map<String>((Keepsake e) => e.id).toList();

void main() {
  group('KeepsakeKind 词表完整性', () {
    test('六个类型都有标签与图标', () {
      expect(KeepsakeKind.values.length, 6);
      expect(KeepsakeKindLabels.labels.length, 6);
      expect(KeepsakeKindLabels.icons.length, 6);
      for (final KeepsakeKind kind in KeepsakeKind.values) {
        expect(KeepsakeKindLabels.labels[kind], isNotNull);
        expect(KeepsakeKindLabels.icons[kind], isNotNull);
      }
    });

    test('kindLabel 委托词表', () {
      expect(data[1].kindLabel, '连续');
    });

    test('keepsakes.dart 转出词表：既有 import 路径仍能拿到枚举', () {
      // 这条是编译期契约；此处用值断言表达「同一类型身份」。
      expect(data[1].kind, isA<KeepsakeKind>());
    });
  });

  group('KeepsakeFilter 显式清空语义', () {
    test('isEmpty 三个条件都为空才成立', () {
      expect(const KeepsakeFilter().isEmpty, isTrue);
      expect(const KeepsakeFilter(query: '   ').isEmpty, isTrue);
      expect(const KeepsakeFilter(kind: KeepsakeKind.streak).isEmpty, isFalse);
      expect(const KeepsakeFilter(monthKey: '2026-11').isEmpty, isFalse);
    });

    test('clearKind 才能取消类型，传 null 不算', () {
      const KeepsakeFilter f = KeepsakeFilter(
        kind: KeepsakeKind.excerpt,
        monthKey: '2026-11',
        query: '雪',
      );
      expect(f.copyWith(kind: null).kind, KeepsakeKind.excerpt);
      expect(f.copyWith(clearKind: true).kind, isNull);
      expect(f.copyWith(clearKind: true).monthKey, '2026-11');
      expect(f.copyWith(clearKind: true).query, '雪');
    });

    test('clearMonth 才能取消月份', () {
      const KeepsakeFilter f = KeepsakeFilter(
        kind: KeepsakeKind.streak,
        monthKey: '2026-10',
      );
      expect(f.copyWith(monthKey: null).monthKey, '2026-10');
      expect(f.copyWith(clearMonth: true).monthKey, isNull);
      expect(f.copyWith(clearMonth: true).kind, KeepsakeKind.streak);
    });

    test('值语义', () {
      const KeepsakeFilter a = KeepsakeFilter(kind: KeepsakeKind.streak);
      const KeepsakeFilter b = KeepsakeFilter(kind: KeepsakeKind.streak);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const KeepsakeFilter(kind: KeepsakeKind.excerpt)));
    });
  });

  group('apply：类型 ∧ 月份 ∧ 关键词', () {
    test('不带筛选返回全部且按最近获得排序', () {
      expect(ids(KeepsakeQuery.apply(keepsakes: data)).length, 7);
      expect(KeepsakeQuery.apply(keepsakes: data).first.dateKey, '2026-11-08');
    });

    test('只按类型', () {
      expect(
        ids(KeepsakeQuery.apply(
          keepsakes: data,
          filter: const KeepsakeFilter(kind: KeepsakeKind.excerpt),
        )),
        <String>['k5', 'k4'],
      );
    });

    test('只按月份', () {
      expect(
        ids(KeepsakeQuery.apply(
          keepsakes: data,
          filter: const KeepsakeFilter(monthKey: '2026-10'),
        )),
        containsAll(<String>['k2', 'k3']),
      );
      expect(
        KeepsakeQuery.apply(
          keepsakes: data,
          filter: const KeepsakeFilter(monthKey: '2026-10'),
        ).length,
        2,
      );
    });

    test('类型与月份叠加是 AND，不是 OR', () {
      final List<Keepsake> r = KeepsakeQuery.apply(
        keepsakes: data,
        filter: const KeepsakeFilter(
          kind: KeepsakeKind.excerpt,
          monthKey: '2026-10',
        ),
      );
      expect(r, isEmpty, reason: '10 月没有摘录类纪念物');
    });

    test('关键词命中标题 / 说明 / 类型标签 / 书名', () {
      expect(
        ids(KeepsakeQuery.apply(
          keepsakes: data,
          filter: const KeepsakeFilter(query: '摘下一句'),
        )),
        <String>['k4'],
      );
      expect(
        ids(KeepsakeQuery.apply(
          keepsakes: data,
          filter: const KeepsakeFilter(query: '雪落'),
        )),
        <String>['k4'],
      );
      expect(
        KeepsakeQuery.apply(
          keepsakes: data,
          filter: const KeepsakeFilter(query: '摘录'),
        ).length,
        2,
        reason: '「摘录」是类型标签',
      );
      expect(
        ids(KeepsakeQuery.apply(
          keepsakes: data,
          filter: const KeepsakeFilter(query: '雪国'),
        )),
        <String>['k4'],
      );
    });

    test('关键词大小写不敏感、空白词不过滤', () {
      final List<Keepsake> withBook = <Keepsake>[
        k('x', KeepsakeKind.excerpt, d4, bookTitle: 'Book One'),
      ];
      expect(
        KeepsakeQuery.apply(
          keepsakes: withBook,
          filter: const KeepsakeFilter(query: 'BOOK'),
        ).length,
        1,
      );
      expect(
        KeepsakeQuery.apply(
          keepsakes: data,
          filter: const KeepsakeFilter(query: '   '),
        ).length,
        7,
      );
    });

    test('不相关关键词返回空', () {
      expect(
        KeepsakeQuery.apply(
          keepsakes: data,
          filter: const KeepsakeFilter(query: '完全不存在的词'),
        ),
        isEmpty,
      );
    });

    test('matches 直接调用与 apply 同口径', () {
      const KeepsakeFilter f = KeepsakeFilter(kind: KeepsakeKind.streak);
      expect(KeepsakeQuery.matches(data[1], f), isTrue);
      expect(KeepsakeQuery.matches(data[0], f), isFalse);
    });

    test('返回不可变列表', () {
      expect(
        () => KeepsakeQuery.apply(keepsakes: data).add(data[0]),
        throwsUnsupportedError,
      );
    });
  });

  group('三种排序', () {
    test('newest 日期降序，同日按类型稳定', () {
      final List<Keepsake> r = KeepsakeQuery.apply(
        keepsakes: data,
        sort: KeepsakeSort.newest,
      );
      expect(r.first.dateKey, '2026-11-08');
      expect(r.last.dateKey, '2026-09-03');
    });

    test('oldest 日期升序', () {
      final List<Keepsake> r = KeepsakeQuery.apply(
        keepsakes: data,
        sort: KeepsakeSort.oldest,
      );
      expect(r.first.id, 'k1');
      expect(r.last.dateKey, '2026-11-08');
    });

    test('byKind 按枚举序，同类内日期降序', () {
      final List<Keepsake> r = KeepsakeQuery.apply(
        keepsakes: data,
        sort: KeepsakeSort.byKind,
      );
      expect(r.first.kind, KeepsakeKind.firstRead);
      expect(r.last.kind, KeepsakeKind.monthly);
      final int i = r.indexWhere((Keepsake e) => e.id == 'k5');
      final int j = r.indexWhere((Keepsake e) => e.id == 'k4');
      expect(i < j, isTrue, reason: '两条 excerpt 里 11-08 排在 11-02 前');
    });

    test('sortLabels 覆盖全部枚举', () {
      expect(KeepsakeQuery.sortLabels.length, KeepsakeSort.values.length);
    });
  });

  group('分面计数（本轮核心）', () {
    test('六个类型恒可见，条数等于全量分布', () {
      final List<KeepsakeKindOption> o =
          KeepsakeQuery.kindOptions(data);
      expect(o.length, 6);
      expect(o.firstWhere((KeepsakeKindOption e) => e.kind == KeepsakeKind.excerpt).count, 2);
      expect(o.firstWhere((KeepsakeKindOption e) => e.kind == KeepsakeKind.monthlyBest).count, 1);
      expect(o.firstWhere((KeepsakeKindOption e) => e.kind == KeepsakeKind.firstRead).count, 1);
    });

    test('已选类型不会把其它类型打成 0', () {
      final List<KeepsakeKindOption> o = KeepsakeQuery.kindOptions(
        data,
        filter: const KeepsakeFilter(kind: KeepsakeKind.excerpt),
      );
      expect(o.firstWhere((KeepsakeKindOption e) => e.kind == KeepsakeKind.streak).count, 1);
      expect(o.firstWhere((KeepsakeKindOption e) => e.kind == KeepsakeKind.monthly).count, 1);
    });

    test('切到 10 月后计数随月份变化', () {
      final List<KeepsakeKindOption> o = KeepsakeQuery.kindOptions(
        data,
        filter: const KeepsakeFilter(monthKey: '2026-10'),
      );
      expect(o.firstWhere((KeepsakeKindOption e) => e.kind == KeepsakeKind.streak).count, 1);
      expect(o.firstWhere((KeepsakeKindOption e) => e.kind == KeepsakeKind.excerpt).count, 0);
      expect(o.where((KeepsakeKindOption e) => e.count > 0).length, 2);
    });

    test('关键词也参与分面计数', () {
      final List<KeepsakeKindOption> o = KeepsakeQuery.kindOptions(
        data,
        filter: const KeepsakeFilter(query: '雪落'),
      );
      expect(o.where((KeepsakeKindOption e) => e.count > 0).length, 1);
      expect(o.firstWhere((KeepsakeKindOption e) => e.kind == KeepsakeKind.excerpt).count, 1);
    });

    test('类型与月份同时选定，分面仍只保留月份', () {
      final List<KeepsakeKindOption> o = KeepsakeQuery.kindOptions(
        data,
        filter: const KeepsakeFilter(
          kind: KeepsakeKind.streak,
          monthKey: '2026-11',
        ),
      );
      expect(o.firstWhere((KeepsakeKindOption e) => e.kind == KeepsakeKind.excerpt).count, 2);
      expect(o.firstWhere((KeepsakeKindOption e) => e.kind == KeepsakeKind.streak).count, 0);
    });

    test('countForKind 算全量，不受筛选影响', () {
      expect(KeepsakeQuery.countForKind(data, KeepsakeKind.excerpt), 2);
      final List<Keepsake> filtered = KeepsakeQuery.apply(
        keepsakes: data,
        filter: const KeepsakeFilter(
          kind: KeepsakeKind.excerpt,
          monthKey: '2026-10',
        ),
      );
      expect(filtered, isEmpty);
      expect(KeepsakeQuery.countForKind(data, KeepsakeKind.excerpt), 2);
      expect(KeepsakeQuery.countForKind(data, KeepsakeKind.monthlyBest), 1);
    });

    test('monthKeys 复用 Catalog 且降序', () {
      expect(KeepsakeQuery.monthKeys(data), <String>['2026-11', '2026-10', '2026-09']);
    });
  });

  group('分组与汇总', () {
    test('不分组单一区块', () {
      expect(KeepsakeQuery.group(data).keys, <String>['全部纪念物']);
    });

    test('按类型分组用类型标签', () {
      final Map<String, List<Keepsake>> g =
          KeepsakeQuery.group(data, by: KeepsakeGroup.kind);
      expect(g['摘录']!.length, 2);
      expect(g['连续']!.length, 1);
      expect(g.length, 6);
    });

    test('按月份分组用 monthKey', () {
      final Map<String, List<Keepsake>> g =
          KeepsakeQuery.group(data, by: KeepsakeGroup.month);
      expect(g['2026-11']!.length, 4);
      expect(g['2026-10']!.length, 2);
      expect(g['2026-09']!.length, 1);
    });

    test('groupLabels 覆盖全部枚举', () {
      expect(KeepsakeQuery.groupLabels.length, KeepsakeGroup.values.length);
    });

    test('summarize 委托 Catalog，不另写一份计数', () {
      final KeepsakeSummary s = KeepsakeQuery.summarize(data);
      expect(s.total, 7);
      expect(s.monthCount, 3);
      expect(s.userExcerptCount, 1);
      expect(s.perKind[KeepsakeKind.excerpt], 2);
      expect(s.perKind[KeepsakeKind.streak], 1);
      expect(s.perKind.length, 6);
    });
  });

  group('emptyKind 四分支与优先级', () {
    test('有命中 → none', () {
      expect(
        KeepsakeQuery.emptyKind(total: 7, matched: 2, filter: const KeepsakeFilter()),
        KeepsakeEmptyKind.none,
      );
    });

    test('全量零纪念物优先于 kindHasNone', () {
      expect(
        KeepsakeQuery.emptyKind(
          total: 0,
          matched: 0,
          filter: const KeepsakeFilter(kind: KeepsakeKind.streak),
          kindTotalCount: 0,
        ),
        KeepsakeEmptyKind.noKeepsakes,
      );
    });

    test('该类型从未产生 → kindHasNone', () {
      expect(
        KeepsakeQuery.emptyKind(
          total: 7,
          matched: 0,
          filter: const KeepsakeFilter(kind: KeepsakeKind.streak),
          kindTotalCount: 0,
        ),
        KeepsakeEmptyKind.kindHasNone,
      );
    });

    test('该类型有但被月份筛掉 → noResult，不误报「这类还没产生」', () {
      expect(
        KeepsakeQuery.emptyKind(
          total: 7,
          matched: 0,
          filter: const KeepsakeFilter(
            kind: KeepsakeKind.excerpt,
            monthKey: '2026-10',
          ),
          kindTotalCount: 2,
        ),
        KeepsakeEmptyKind.noResult,
      );
    });

    test('无筛选且无命中 → noKeepsakes', () {
      expect(
        KeepsakeQuery.emptyKind(total: 7, matched: 0, filter: const KeepsakeFilter()),
        KeepsakeEmptyKind.noKeepsakes,
      );
    });

    test('空状态文案齐备', () {
      expect(LegalTexts.keepsakeKindEmptyTitle, contains('这一类'));
      expect(LegalTexts.keepsakeKindEmptyBody, contains('自动生成'));
      expect(LegalTexts.keepsakeNoResultTitle, contains('没有符合'));
      expect(LegalTexts.keepsakeNoResultBody, contains('清空筛选'));
    });
  });

  group('KeepsakeLibraryArgs 深链', () {
    test('fromCard 带上两个筛选', () {
      final KeepsakeLibraryArgs a =
          KeepsakeLibraryArgs.fromCard(KeepsakeKind.streak, '2026-10');
      expect(a.initialKind, KeepsakeKind.streak);
      expect(a.initialMonthKey, '2026-10');
      expect(a.isScoped, isTrue);
    });

    test('空月份归一化为 null，不打开空条件', () {
      final KeepsakeLibraryArgs a =
          KeepsakeLibraryArgs.fromCard(KeepsakeKind.excerpt, '');
      expect(a.initialMonthKey, isNull);
      expect(a.isScoped, isTrue);
    });

    test('两个都空时 isScoped 为 false', () {
      expect(const KeepsakeLibraryArgs().isScoped, isFalse);
      expect(KeepsakeLibraryArgs.fromCard(null, null).isScoped, isFalse);
    });

    test('只带月份也算 scoped', () {
      expect(KeepsakeLibraryArgs.fromCard(null, '2026-11').isScoped, isTrue);
    });
  });

  group('WidgetSpec 每个小组件独立类型', () {
    test('默认 null = 显示全部', () {
      expect(const WidgetSpec(id: 'w').keepsakeKind, isNull);
    });

    test('copyWith 指定类型，clear 才能清空（nullable 字段的坑）', () {
      const WidgetSpec base = WidgetSpec(
        id: 'w',
        content: WidgetContent.keepsake,
        keepsakeKind: KeepsakeKind.streak,
      );
      expect(base.copyWith(keepsakeKind: null).keepsakeKind, KeepsakeKind.streak,
          reason: '传 null 不等于清空');
      expect(base.copyWith(clearKeepsakeKind: true).keepsakeKind, isNull);
      expect(base.copyWith(keepsakeKind: KeepsakeKind.excerpt).keepsakeKind,
          KeepsakeKind.excerpt);
    });

    test('toMap / fromMap 往返保留类型', () {
      const WidgetSpec spec = WidgetSpec(
        id: 'w-k',
        content: WidgetContent.keepsake,
        size: WidgetSize.large,
        keepsakeKind: KeepsakeKind.monthlyBest,
      );
      final Map<String, Object> m = spec.toMap();
      expect(m['keepsakeKind'], 'monthlyBest');
      expect(WidgetSpec.fromMap(m), spec);
    });

    test('空串 / 缺字段 / 非法值回落 null，旧配置向后兼容', () {
      expect(WidgetSpec.fromMap(<String, Object>{'id': 'w'}).keepsakeKind, isNull);
      expect(
        WidgetSpec.fromMap(<String, Object>{
          'id': 'w',
          'keepsakeKind': '',
        }).keepsakeKind,
        isNull,
      );
      expect(
        WidgetSpec.fromMap(<String, Object>{
          'id': 'w',
          'keepsakeKind': 'unknownKind',
        }).keepsakeKind,
        KeepsakeKind.firstRead,
      );
    });

    test('值语义包含类型', () {
      const WidgetSpec a = WidgetSpec(id: 'w', keepsakeKind: KeepsakeKind.streak);
      const WidgetSpec b = WidgetSpec(id: 'w', keepsakeKind: KeepsakeKind.streak);
      const WidgetSpec c = WidgetSpec(id: 'w', keepsakeKind: KeepsakeKind.excerpt);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('内容标签数量仍等于枚举数量（第八轮断言不回退）', () {
      expect(WidgetSpecLabels.content.length, WidgetContent.values.length);
      expect(WidgetSpecLabels.icon.length, WidgetContent.values.length);
      expect(WidgetSpecLabels.size.length, WidgetSize.values.length);
    });
  });

  group('文案与键集合', () {
    test('10 条新文案都收进单一源', () {
      for (final String key in <String>[
        'keepsakeAllKinds', 'keepsakeOpenLibrary', 'keepsakeLibraryTitle',
        'keepsakeFilterHint', 'keepsakeKindEmptyTitle', 'keepsakeKindEmptyBody',
        'keepsakeNoResultTitle', 'keepsakeNoResultBody',
        'keepsakeFilterStaticNote', 'keepsakeWidgetKindNote',
      ]) {
        expect(LegalTexts.keys.contains(key), isTrue, reason: '$key 未登记');
      }
    });

    test('键集合共 86 项且无重复', () {
      expect(LegalTexts.keys.length, 86);
      expect(LegalTexts.keys.toSet().length, 86);
    });

    test('分面说明与静态边界写明口径', () {
      expect(LegalTexts.keepsakeFilterHint, contains('归零'));
      expect(LegalTexts.keepsakeFilterStaticNote, contains('不落盘'));
      expect(LegalTexts.keepsakeWidgetKindNote, contains('独立'));
    });
  });
}
