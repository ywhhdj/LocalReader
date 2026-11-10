import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/data/library_query.dart';
import 'package:local_reader/core/stats/excerpt_capture.dart';
import 'package:local_reader/core/stats/excerpt_query.dart';
import 'package:local_reader/core/stats/excerpt_title_lookup.dart';
import 'package:local_reader/core/stats/reading_stats.dart';

/// 第二十一轮「规格单测扩充」之二：`ExcerptQuery` 自第十轮起承担
/// 筛选 / 排序 / 分组 / 汇总 / 导出五个出口，此前只覆盖了筛选与书名口径。
/// 本文件把其余出口、四种排序、四种分组与导出格式逐项补成可执行规格。
Excerpt ex(
  String id, {
  String bookId = 'b1',
  String bookTitle = '雪国的旅行者',
  String text = '雪落下来的时候，屋子里很安静。',
  DateTime? at,
  HighlightColor color = HighlightColor.amber,
  String note = '',
  bool user = false,
}) =>
    Excerpt(
      id: id,
      bookId: bookId,
      bookTitle: bookTitle,
      chapterTitle: '第一章',
      text: text,
      capturedAt: at ?? DateTime.utc(2026, 11, 8),
      highlight: color,
      note: note,
      isUserAdded: user,
    );

final DateTime d1 = DateTime.utc(2026, 10, 2);
final DateTime d2 = DateTime.utc(2026, 11, 8);
final DateTime d3 = DateTime.utc(2026, 11, 20);

final List<Excerpt> data = <Excerpt>[
  ex('e1', at: d1, bookTitle: '阿尔法', text: '第一句'),
  ex('e2',
      at: d2,
      bookTitle: '贝塔',
      color: HighlightColor.rose,
      note: '有批注',
      user: true),
  ex('e3', at: d3, bookId: 'b2', bookTitle: '伽马', text: '第三句'),
  ex('e4', at: d2, bookTitle: '贝塔', color: HighlightColor.rose, user: true),
];

List<String> ids(List<Excerpt> items) =>
    items.map((Excerpt e) => e.id).toList();

void main() {
  group('四种排序', () {
    test('newest / oldest 按 capturedAt，同日按 id 稳定', () {
      expect(
        ids(ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.newest)),
        <String>['e3', 'e2', 'e4', 'e1'],
      );
      expect(
        ids(ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.oldest)),
        <String>['e1', 'e2', 'e4', 'e3'],
      );
    });

    test('byBook 让同一本书的条目相邻，且书名序列与书库自然排序一致', () {
      final List<Excerpt> out =
          ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.byBook);
      // 不硬编码中文码点顺序：只断言「同书相邻」与「序列非递减」。
      final List<String> names = out.map((Excerpt e) => e.bookTitle).toList();
      expect(names.where((String n) => n == '贝塔').length, 2);
      expect(names.indexOf('贝塔') + 1, names.lastIndexOf('贝塔'),
          reason: '两条贝塔必须相邻');
      for (int i = 1; i < names.length; i++) {
        expect(
          LibraryQuery.naturalCompare(names[i - 1], names[i]),
          lessThanOrEqualTo(0),
        );
      }
      // 同书（贝塔）内部按日期倒序，同日再按 id。
      final List<Excerpt> beta =
          out.where((Excerpt e) => e.bookTitle == '贝塔').toList();
      expect(beta.first.id, 'e2');
    });

    test('byBook 传入 titleResolver 时按当前书名排', () {
      final ExcerptTitleLookup titles = ExcerptTitleLookup(
        (String id) => id == 'b2' ? 'A Book' : 'Z Book',
      );
      final List<Excerpt> out = ExcerptQuery.apply(
        excerpts: data,
        sort: ExcerptSort.byBook,
        titles: titles,
      );
      expect(out.first.bookId, 'b2', reason: '「A Book」应排在「Z Book」前');
      expect(out.last.bookId, isNot('b2'));
    });

    test('byColor 按划线色索引分组，组内日期倒序', () {
      final List<Excerpt> out =
          ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.byColor);
      expect(out.length, 4);
      expect(ids(out).first, isIn(<String>['e1', 'e3']));
    });

    test('apply 返回不可变列表', () {
      final List<Excerpt> out = ExcerptQuery.apply(excerpts: data);
      expect(() => out.add(ex('x')), throwsUnsupportedError);
    });
  });

  group('四种分组', () {
    test('none 只有一个「全部摘录」区块', () {
      final Map<String, List<Excerpt>> g =
          ExcerptQuery.group(data, by: ExcerptGroup.none);
      expect(g.keys, <String>['全部摘录']);
      expect(g.values.single.length, 4);
    });

    test('book 分组按书名，month 分组按 YYYY-MM', () {
      expect(ExcerptQuery.group(data, by: ExcerptGroup.book).keys.toSet(),
          <String>{'阿尔法', '贝塔', '伽马'});
      expect(ExcerptQuery.group(data, by: ExcerptGroup.month).keys.toSet(),
          <String>{'2026-10', '2026-11'});
    });

    test('color 分组按划线色标签', () {
      final Map<String, List<Excerpt>> g =
          ExcerptQuery.group(data, by: ExcerptGroup.color);
      expect(
          g.values.fold<int>(0, (int s, List<Excerpt> v) => s + v.length), 4);
    });

    test('groupKey 与 formatMonth / HighlightPalette 对齐', () {
      expect(ExcerptQuery.groupKey(data[0], ExcerptGroup.month), '2026-10');
      expect(ExcerptQuery.formatMonth(d2), '2026-11');
      expect(ExcerptQuery.formatDate(d2), '2026-11-08');
      expect(ExcerptQuery.groupKey(data[0], ExcerptGroup.none), '全部摘录');
    });
  });

  group('汇总与筛选选项', () {
    test('summarize 统计总数 / 我摘的 / 有批注 / 按书 / 按色', () {
      final ExcerptSummary s = ExcerptQuery.summarize(data);
      expect(s.total, 4);
      expect(s.userCount, 2);
      expect(s.withNoteCount, 1);
      expect(s.perBook['贝塔'], 2);
      expect(s.perColor[HighlightColor.rose], 2);
      expect(() => s.perBook['x'] = 9, throwsUnsupportedError);
    });

    test('countForBook 算全量，不受筛选影响', () {
      expect(ExcerptQuery.countForBook(data, 'b2'), 1);
      expect(ExcerptQuery.countForBook(data, 'none'), 0);
    });

    test('bookOptions：用 bookId 当值，零摘录书固定成可见 0 条选项', () {
      final List<ExcerptBookOption> opts = ExcerptQuery.bookOptions(
        data,
        pinnedBookId: 'ghost',
        pinnedTitle: '幽灵书',
      );
      expect(
          opts.any(
              (ExcerptBookOption o) => o.bookId == 'ghost' && o.count == 0),
          isTrue);
      for (final ExcerptBookOption o in opts) {
        expect(o.bookId, isNotEmpty);
      }
    });

    test('titleResolver 优先于快照，解析不到回落快照', () {
      final ExcerptTitleLookup titles = ExcerptTitleLookup(
        (String id) => id == 'b1' ? '新书名' : null,
      );
      final List<ExcerptBookOption> opts =
          ExcerptQuery.bookOptions(data, titles: titles);
      expect(opts.any((ExcerptBookOption o) => o.title == '新书名'), isTrue);
      expect(ExcerptQuery.summarize(data, titles: titles).perBook['新书名'], 3);
    });
  });

  group('范围 / 颜色 / 关键词筛选（既有能力回归）', () {
    test('scope 三档', () {
      expect(
        ids(ExcerptQuery.apply(
            excerpts: data,
            filter: const ExcerptFilter(scope: ExcerptScope.userOnly))),
        <String>['e2', 'e4'],
      );
      expect(
        ids(ExcerptQuery.apply(
            excerpts: data,
            filter: const ExcerptFilter(scope: ExcerptScope.withNote))),
        <String>['e2'],
      );
      expect(
        ExcerptQuery.apply(
                excerpts: data,
                filter: const ExcerptFilter(scope: ExcerptScope.all))
            .length,
        4,
      );
    });

    test('color / bookId / query 可叠加', () {
      final List<Excerpt> out = ExcerptQuery.apply(
        excerpts: data,
        filter: const ExcerptFilter(
          color: HighlightColor.rose,
          query: '第三',
        ),
      );
      expect(out, isEmpty, reason: '玫瑰色条目里没有「第三」');
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(color: HighlightColor.rose),
        )),
        <String>['e2', 'e4'],
      );
    });

    test('搜索命中正文 / 书名 / 章节 / 批注', () {
      for (final String q in <String>['第一句', '阿尔法', '第一章', '有批注']) {
        expect(
          ExcerptQuery.apply(excerpts: data, filter: ExcerptFilter(query: q))
              .isNotEmpty,
          isTrue,
          reason: q,
        );
      }
    });
  });

  group('空状态分类（既有四分支）', () {
    test('有命中 → none；全书库空 → noExcerpts', () {
      expect(
        ExcerptQuery.emptyKind(
            total: 4, matched: 2, filter: const ExcerptFilter()),
        ExcerptEmptyKind.none,
      );
      expect(
        ExcerptQuery.emptyKind(
            total: 0, matched: 0, filter: const ExcerptFilter()),
        ExcerptEmptyKind.noExcerpts,
      );
    });

    test('深链的书全量零摘录 → bookHasNone', () {
      expect(
        ExcerptQuery.emptyKind(
          total: 4,
          matched: 0,
          filter: const ExcerptFilter(bookId: 'ghost'),
          scopedBookCount: 0,
        ),
        ExcerptEmptyKind.bookHasNone,
      );
    });

    test('该书有摘录但被别的条件筛掉 → noResult', () {
      expect(
        ExcerptQuery.emptyKind(
          total: 4,
          matched: 0,
          filter: const ExcerptFilter(bookId: 'b1', query: '不存在'),
          scopedBookCount: 3,
        ),
        ExcerptEmptyKind.noResult,
      );
    });
  });

  group('ExcerptExporter 纯文本（静态边界）', () {
    test('空列表返回固定提示', () {
      expect(ExcerptExporter.toPlainText(const <Excerpt>[]),
          ExcerptExporter.emptyMessage);
    });

    test('标题 / 条数 / 分隔线 / 快照书名', () {
      final String out = ExcerptExporter.toPlainText(<Excerpt>[data[0]]);
      expect(out, contains('共 1 条'));
      expect(out, contains('《阿尔法》'));
      expect(out, contains('第一句'));
      expect(out, contains(ExcerptExporter.separator));
      expect(out, contains('2026-10-02'));
      expect(out, contains('演示'));
    });

    test('includeMetadata=false 时省略日期与色标', () {
      final String out = ExcerptExporter.toPlainText(
        <Excerpt>[data[0]],
        includeMetadata: false,
      );
      expect(out, isNot(contains('2026-10-02')));
      expect(out, contains('第一句'));
    });

    test('批注与「我摘的」只在存在时出现', () {
      final String withNote = ExcerptExporter.toPlainText(<Excerpt>[data[1]]);
      expect(withNote, contains('—— 有批注'));
      expect(withNote, contains('我摘的'));
      final String plain = ExcerptExporter.toPlainText(<Excerpt>[data[0]]);
      expect(plain, isNot(contains('—— ')));
    });

    test('导出只用快照书名，不受 titleResolver 影响（第十七轮口径）', () {
      final ExcerptTitleLookup titles =
          ExcerptTitleLookup((String _) => '改成新名');
      // 先确认展示层确实读到新名，再确认导出仍是旧名。
      expect(ExcerptQuery.summarize(data, titles: titles).perBook['改成新名'], 4);
      final String out = ExcerptExporter.toPlainText(<Excerpt>[data[0]]);
      expect(out, contains('《阿尔法》'));
      expect(out, isNot(contains('改成新名')));
    });
  });
}
