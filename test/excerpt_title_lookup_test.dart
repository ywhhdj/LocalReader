import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/content/legal_texts.dart';
import 'package:local_reader/core/stats/excerpt_query.dart';
import 'package:local_reader/core/stats/excerpt_title_lookup.dart';
import 'package:local_reader/core/stats/reading_stats.dart';

final DateTime d1 = DateTime.utc(2026, 11, 2);
final DateTime d2 = DateTime.utc(2026, 11, 4);
final DateTime d3 = DateTime.utc(2026, 11, 6);

/// 关键场景：b01 在详情页被改名「A·雪国修订」，但摘录捕获时快照是「Z·雪国旧版」。
Excerpt e(
  String id,
  String bookId,
  String snapshot, {
  String text = '一句摘录。',
  DateTime? at,
}) =>
    Excerpt(
      id: id,
      bookId: bookId,
      bookTitle: snapshot,
      chapterTitle: '第一章',
      text: text,
      capturedAt: at ?? d1,
    );

final List<Excerpt> data = <Excerpt>[
  e('e1', 'b01', 'Z·雪国旧版', at: d1),
  e('e2', 'b01', 'Z·雪国旧版', text: '第二句。', at: d3),
  e('e3', 'b04', 'A·秋笺原版', at: d2),
  e('e4', 'lost', '旧导入书名', at: d3),
];

/// 书库当前名称：b01 已改名、b04 不变、lost 解析不到。
String? resolve(String id) {
  switch (id) {
    case 'b01':
      return 'A·雪国修订';
    case 'b04':
      return 'B·秋笺新装';
    default:
      return null;
  }
}

final ExcerptTitleLookup titles = ExcerptTitleLookup(resolve);

List<String> ids(List<Excerpt> r) =>
    r.map<String>((Excerpt e) => e.id).toList();

void main() {
  group('ExcerptTitleLookup 三条口径', () {
    test('currentTitle 取书库当前名并去掉首尾空白', () {
      expect(titles.currentTitle('b01'), 'A·雪国修订');
      expect(titles.currentTitle('b04'), 'B·秋笺新装');
      expect(titles.currentTitle('lost'), isNull);
    });

    test('空白解析结果视为未解析到，不显示空标题', () {
      final ExcerptTitleLookup blank = ExcerptTitleLookup((String _) => '   ');
      expect(blank.currentTitle('b01'), isNull);
      expect(blank.titleOf(data.first), 'Z·雪国旧版');
    });

    test('titleOf 当前名优先、解析不到回落快照', () {
      expect(titles.titleOf(data[0]), 'A·雪国修订');
      expect(titles.titleOf(data[3]), '旧导入书名');
    });

    test('snapshotOf 空快照回落「未标注书名」', () {
      expect(ExcerptTitleLookup.snapshotOf(e('x', 'b99', '')),
          ExcerptTitleLookup.unknownTitle);
      expect(ExcerptTitleLookup.snapshotOf(e('x', 'b99', '   ')),
          ExcerptTitleLookup.unknownTitle);
      expect(
          titles.titleOf(e('x', 'lost', '')), ExcerptTitleLookup.unknownTitle);
    });

    test('值语义：同一 resolve 引用相等，不同 lambda 不等', () {
      expect(titles, ExcerptTitleLookup(resolve));
      expect(titles.hashCode, ExcerptTitleLookup(resolve).hashCode);
      expect(titles, isNot(ExcerptTitleLookup((String _) => '别的名字')));
    });
  });

  group('书名搜索是「当前名 ∪ 快照」并集', () {
    test('搜新名命中（第十六轮残留缺陷）', () {
      expect(titles.matchesBookTitle(data[0], '雪国修订'), isTrue);
      final List<Excerpt> r = ExcerptQuery.apply(
        excerpts: data,
        filter: const ExcerptFilter(query: '雪国修订'),
        titles: titles,
      );
      expect(ids(r), <String>['e2', 'e1']);
    });

    test('搜旧名也命中，导出里的旧名不会被搜丢', () {
      expect(titles.matchesBookTitle(data[0], '雪国旧版'), isTrue);
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(query: '雪国旧版'),
          titles: titles,
        )),
        <String>['e2', 'e1'],
      );
    });

    test('搜新名的一段子串同样命中', () {
      expect(titles.matchesBookTitle(data[0], '修订'), isTrue);
      expect(titles.matchesBookTitle(data[2], '新装'), isTrue);
    });

    test('大小写不敏感', () {
      expect(
          titles.matchesBookTitle(e('x', 'b01', 'Book One'), 'book'), isTrue);
      expect(
          titles.matchesBookTitle(e('x', 'b01', 'Book One'), 'BOOK'), isTrue);
    });

    test('空 / 纯空白关键词不应把整本筛没', () {
      expect(titles.matchesBookTitle(data[0], ''), isTrue);
      expect(titles.matchesBookTitle(data[0], '   '), isTrue);
    });

    test('不相关的词不命中', () {
      expect(titles.matchesBookTitle(data[0], '完全不存在的词'), isFalse);
      expect(
        ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(query: '完全不存在的词'),
          titles: titles,
        ),
        isEmpty,
      );
    });

    test('脏 id 解析不到时仍按快照书名搜到', () {
      expect(titles.currentTitle('lost'), isNull);
      expect(titles.matchesBookTitle(data[3], '旧导入'), isTrue);
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(query: '旧导入'),
          titles: titles,
        )),
        <String>['e4'],
      );
    });

    test('不带 titles 时保持旧快照语义（向后兼容）', () {
      expect(
        ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(query: '雪国修订'),
        ),
        isEmpty,
        reason: '既有调用不传 lookup 不应悄悄改变行为',
      );
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(query: '雪国旧版'),
        )),
        <String>['e2', 'e1'],
      );
    });

    test('正文 / 章节 / 批注搜索不受书名口径影响', () {
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(query: '第二句'),
          titles: titles,
        )),
        <String>['e2'],
      );
      expect(
        ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(query: '第一章'),
          titles: titles,
        ).length,
        4,
      );
    });

    test('matches 直接调用也走同一个并集出口', () {
      expect(
        ExcerptQuery.matches(
          data[0],
          const ExcerptFilter(query: '雪国修订'),
          titles: titles,
        ),
        isTrue,
      );
      expect(
        ExcerptQuery.matches(
          data[0],
          const ExcerptFilter(query: '雪国修订'),
        ),
        isFalse,
      );
    });
  });

  group('按书名排序 / 分组 / 汇总同步到当前名', () {
    test('byBook 排序用当前名：A·雪国修订 排在 B·秋笺新装 前', () {
      // naturalCompare 按 code unit：'A'(0x41) < 'B'(0x42) < 'Z'(0x5A) < '旧'(0x65E7)。
      // 快照口径首字符分别是 A / Z / 旧；当前名口径变成 A / B / 旧，b01 与 b04 的相对位置翻转。
      // 同标题内仍按 capturedAt 倒序，所以 e2(d3) 排在 e1(d1) 前。
      expect(
        ids(ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.byBook)),
        <String>['e3', 'e2', 'e1', 'e4'],
      );
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          sort: ExcerptSort.byBook,
          titles: titles,
        )),
        <String>['e2', 'e1', 'e3', 'e4'],
      );
      // 两条 b01 相邻且整体前移，才是「按当前名」而不是巧合。
      final List<String> withLookup = ids(ExcerptQuery.apply(
        excerpts: data,
        sort: ExcerptSort.byBook,
        titles: titles,
      ));
      expect(withLookup.indexOf('e2'), 0);
      expect(withLookup.indexOf('e1'), 1);
    });

    test('groupKey(book) 用当前名，不带 titles 回落快照', () {
      expect(ExcerptQuery.groupKey(data[0], ExcerptGroup.book, titles: titles),
          'A·雪国修订');
      expect(ExcerptQuery.groupKey(data[0], ExcerptGroup.book), 'Z·雪国旧版');
    });

    test('group(book) 的 section 标题与展示名一致，不再出现旧名', () {
      final Map<String, List<Excerpt>> g = ExcerptQuery.group(
        data,
        by: ExcerptGroup.book,
        titles: titles,
      );
      expect(g.keys, contains('A·雪国修订'));
      expect(g.keys, isNot(contains('Z·雪国旧版')));
      expect(g['A·雪国修订']!.length, 2);
      expect(g['B·秋笺新装']!.length, 1);
      expect(g['旧导入书名']!.length, 1, reason: '脏 id 回落快照');
    });

    test('其它分组不受书名口径影响', () {
      final Map<String, List<Excerpt>> g = ExcerptQuery.group(
        data,
        by: ExcerptGroup.month,
        titles: titles,
      );
      expect(g.keys.length, 3);
      expect(
        ExcerptQuery.group(data, by: ExcerptGroup.color, titles: titles)
            .keys
            .length,
        1,
      );
      expect(
        ExcerptQuery.group(data, titles: titles).keys,
        <String>['全部摘录'],
      );
    });

    test('summarize 的 perBook 用当前名，条数不变', () {
      final ExcerptSummary s = ExcerptQuery.summarize(data, titles: titles);
      expect(s.total, 4);
      expect(s.userCount, 0);
      expect(s.withNoteCount, 0);
      expect(s.perBook['A·雪国修订'], 2);
      expect(s.perBook['B·秋笺新装'], 1);
      expect(s.perBook['旧导入书名'], 1);
      expect(s.perBook.containsKey('Z·雪国旧版'), isFalse);
    });

    test('summarize 不带 titles 保持快照 key（向后兼容）', () {
      expect(ExcerptQuery.summarize(data).perBook['Z·雪国旧版'], 2);
    });

    test('newest / oldest / byColor 排序不因 lookup 改变', () {
      expect(
        ids(ExcerptQuery.apply(excerpts: data, titles: titles)),
        ids(ExcerptQuery.apply(excerpts: data)),
      );
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          sort: ExcerptSort.oldest,
          titles: titles,
        )),
        ids(ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.oldest)),
      );
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          sort: ExcerptSort.byColor,
          titles: titles,
        )),
        ids(ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.byColor)),
      );
    });
  });

  group('筛选选项共用同一 lookup', () {
    test('bookOptions(titles:) 与 titleResolver 等价', () {
      final List<ExcerptBookOption> viaLookup =
          ExcerptQuery.bookOptions(data, titles: titles);
      final List<ExcerptBookOption> viaResolver = ExcerptQuery.bookOptions(
        data,
        titleResolver: resolve,
      );
      expect(viaLookup, viaResolver);
    });

    test('titles 优先于 titleResolver，只有一个裁决点', () {
      final List<ExcerptBookOption> o = ExcerptQuery.bookOptions(
        data,
        titles: titles,
        titleResolver: (String _) => '不该被用到的名字',
      );
      expect(o.firstWhere((ExcerptBookOption e) => e.bookId == 'b01').title,
          'A·雪国修订');
    });

    test('选项标题用当前名，脏 id 回落快照', () {
      final List<ExcerptBookOption> o =
          ExcerptQuery.bookOptions(data, titles: titles);
      expect(o.firstWhere((ExcerptBookOption e) => e.bookId == 'b01').title,
          'A·雪国修订');
      expect(o.firstWhere((ExcerptBookOption e) => e.bookId == 'lost').title,
          '旧导入书名');
      expect(o.length, 3);
    });

    test('零摘录深链书通过 lookup 拿到当前名', () {
      final List<ExcerptBookOption> o = ExcerptQuery.bookOptions(
        data,
        pinnedBookId: 'b07',
        pinnedTitle: '星屑与旧钟',
        titles:
            ExcerptTitleLookup((String id) => id == 'b07' ? '星屑 · 新装版' : null),
      );
      expect(o.firstWhere((ExcerptBookOption e) => e.bookId == 'b07').title,
          '星屑 · 新装版');
    });
  });

  group('导出仍只用快照（回归红线）', () {
    test('改名后导出正文仍是捕获时的旧名', () {
      final String out = ExcerptExporter.toPlainText(
        <Excerpt>[data[0]],
        title: '我的摘录',
      );
      expect(out, contains('《Z·雪国旧版》'));
      expect(out, isNot(contains('A·雪国修订')));
    });

    test('导出不查书库、不依赖 lookup，签名保持向后兼容', () {
      final String out = ExcerptExporter.toPlainText(
        <Excerpt>[data[3]],
        includeMetadata: false,
      );
      expect(out, contains('《旧导入书名》'));
      expect(out, contains(ExcerptExporter.separator));
    });

    test('空列表导出固定提示', () {
      expect(ExcerptExporter.toPlainText(const <Excerpt>[]),
          ExcerptExporter.emptyMessage);
    });
  });

  group('文案与键集合', () {
    test('两条新文案都收进单一源', () {
      expect(LegalTexts.keys.contains('excerptSearchTitleNote'), isTrue);
      expect(LegalTexts.keys.contains('excerptExportSnapshotNote'), isTrue);
    });

    test('键集合共 76 项且无重复', () {
      expect(LegalTexts.keys.length, 76);
      expect(LegalTexts.keys.toSet().length, 76);
    });

    test('搜索说明写明新旧名都能找到，导出说明写明展示用当前名', () {
      expect(LegalTexts.excerptSearchTitleNote, contains('旧名'));
      expect(LegalTexts.excerptSearchTitleNote, contains('当前名称'));
      expect(LegalTexts.excerptExportSnapshotNote, contains('快照'));
      expect(LegalTexts.excerptExportSnapshotNote, contains('当前名称'));
    });
  });
}
