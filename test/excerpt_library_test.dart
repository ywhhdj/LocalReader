import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/data/book_repository.dart';
import 'package:local_reader/core/state/app_scope.dart';
import 'package:local_reader/core/state/app_settings.dart';
import 'package:local_reader/core/stats/excerpt_capture.dart';
import 'package:local_reader/core/stats/excerpt_query.dart';
import 'package:local_reader/core/stats/reading_stats.dart';

final DateTime _d1 = DateTime.utc(2026, 10, 2);
final DateTime _d2 = DateTime.utc(2026, 11, 3);
final DateTime _d3 = DateTime.utc(2026, 11, 9);

Excerpt ex(
  String id, {
  String bookId = 'b01',
  String bookTitle = '纸白纪事',
  String chapterTitle = '第一章  纸白',
  String text = '书页翻过去的时候',
  DateTime? at,
  HighlightColor color = HighlightColor.amber,
  String note = '',
  bool user = false,
  String signature = '',
}) =>
    Excerpt(
      id: id,
      bookId: bookId,
      bookTitle: bookTitle,
      chapterTitle: chapterTitle,
      text: text,
      capturedAt: at ?? _d1,
      highlight: color,
      note: note,
      isUserAdded: user,
      signature: signature,
    );

List<Excerpt> sample() => <Excerpt>[
      ex('e1', text: '雪落在纸上', at: _d1, bookTitle: '第 2 卷'),
      ex('e2',
          text: '春樱落在阶前',
          at: _d2,
          bookTitle: '第 10 卷',
          color: HighlightColor.rose,
          note: '好看',
          bookId: 'b02',
          chapterTitle: '第三章  斜光'),
      ex('u1',
          text: '我自己摘的一句',
          at: _d3,
          bookTitle: '纸白纪事',
          color: HighlightColor.sage,
          user: true,
          note: '记一下',
          signature: 'b03|0|我自己摘的一句',
          bookId: 'b03'),
      ex('e3',
          text: '目录翻到最后一页',
          at: _d1,
          bookTitle: '第 2 卷',
          bookId: 'b01',
          color: HighlightColor.blue),
    ];

void main() {
  group('ExcerptFilter', () {
    test('isEmpty 与各项条件', () {
      expect(const ExcerptFilter().isEmpty, isTrue);
      expect(const ExcerptFilter(query: '雪').isEmpty, isFalse);
      expect(
          const ExcerptFilter(scope: ExcerptScope.userOnly).isEmpty, isFalse);
      expect(const ExcerptFilter(color: HighlightColor.rose).isEmpty, isFalse);
    });

    test('copyWith 用 clearBook / clearColor 显式清空，不被 null 混淆', () {
      const ExcerptFilter f =
          ExcerptFilter(bookId: 'b01', color: HighlightColor.rose);
      expect(f.copyWith(query: '雪').bookId, 'b01');
      expect(f.copyWith(query: '雪').color, HighlightColor.rose);
      expect(f.copyWith(clearBook: true).bookId, isNull);
      expect(f.copyWith(clearColor: true).color, isNull);
      expect(f.copyWith(scope: ExcerptScope.withNote).scope,
          ExcerptScope.withNote);
      expect(f, f.copyWith());
    });
  });

  group('筛选 matches / apply', () {
    final List<Excerpt> data = sample();

    test('关键词命中正文 / 书名 / 章节 / 批注，大小写不敏感', () {
      expect(
          ExcerptQuery.apply(
                  excerpts: data, filter: const ExcerptFilter(query: '雪落'))
              .single
              .id,
          'e1');
      expect(
          ExcerptQuery.apply(
                  excerpts: data, filter: const ExcerptFilter(query: '斜光'))
              .single
              .id,
          'e2');
      expect(
          ExcerptQuery.apply(
                  excerpts: data, filter: const ExcerptFilter(query: '好看'))
              .single
              .id,
          'e2');
      expect(
          ExcerptQuery.apply(
                  excerpts: data, filter: const ExcerptFilter(query: '第 2 卷'))
              .length,
          2);
      expect(
          ExcerptQuery.apply(
              excerpts: data, filter: const ExcerptFilter(query: 'BOOK')),
          isEmpty);
    });

    test('按书 / 按色 / 按范围，且可叠加', () {
      expect(
          ExcerptQuery.apply(
                  excerpts: data, filter: const ExcerptFilter(bookId: 'b02'))
              .length,
          1);
      expect(
          ExcerptQuery.apply(
                  excerpts: data,
                  filter: const ExcerptFilter(color: HighlightColor.blue))
              .single
              .id,
          'e3');
      expect(
          ExcerptQuery.apply(
                  excerpts: data,
                  filter: const ExcerptFilter(scope: ExcerptScope.userOnly))
              .single
              .id,
          'u1');
      expect(
          ExcerptQuery.apply(
                  excerpts: data,
                  filter: const ExcerptFilter(scope: ExcerptScope.withNote))
              .length,
          2);
      final List<Excerpt> both = ExcerptQuery.apply(
        excerpts: data,
        filter: const ExcerptFilter(
            scope: ExcerptScope.userOnly, color: HighlightColor.sage),
      );
      expect(both.single.id, 'u1');
    });

    test('返回不可变列表', () {
      final List<Excerpt> r = ExcerptQuery.apply(excerpts: data);
      expect(() => r.add(ex('x')), throwsUnsupportedError);
    });
  });

  group('排序', () {
    final List<Excerpt> data = sample();

    test('最近摘录：日期降序，u1 在最前', () {
      final List<Excerpt> r =
          ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.newest);
      expect(r.first.id, 'u1');
      expect(r.last.capturedAt, _d1);
    });

    test('最早摘录：日期升序，同日按 id 稳定', () {
      final List<Excerpt> r =
          ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.oldest);
      expect(r.first.capturedAt, _d1);
      expect(r.first.id, 'e1');
      expect(r[1].id, 'e3');
      expect(r.last.id, 'u1');
    });

    test('按书名自然排序：第 2 卷 在 第 10 卷 前', () {
      final List<Excerpt> r =
          ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.byBook);
      expect(r.first.bookTitle, '第 2 卷');
      expect(r.last.bookTitle, '纸白纪事');
    });

    test('按划线色：枚举顺序，同色内日期降序', () {
      final List<Excerpt> r =
          ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.byColor);
      expect(r.first.highlight, HighlightColor.amber);
      expect(r.last.highlight, HighlightColor.blue,
          reason: '枚举顺序 amber<rose<sage<blue');
    });
  });

  group('分组与统计', () {
    final List<Excerpt> data = sample();

    test('不分组只有一段', () {
      final Map<String, List<Excerpt>> g = ExcerptQuery.group(data);
      expect(g.keys.toList(), <String>['全部摘录']);
      expect(g['全部摘录']!.length, 4);
    });

    test('按书名 / 按色 / 按月份分组键正确', () {
      final Map<String, List<Excerpt>> byBook =
          ExcerptQuery.group(data, by: ExcerptGroup.book);
      expect(byBook['第 2 卷']!.length, 2);
      expect(byBook['第 10 卷']!.length, 1);

      final Map<String, List<Excerpt>> byColor =
          ExcerptQuery.group(data, by: ExcerptGroup.color);
      expect(byColor['琥珀']!.length, 1);
      expect(byColor['胭脂']!.length, 1);
      expect(byColor['靛蓝']!.length, 1);
      expect(byColor['青苔']!.length, 1);

      final Map<String, List<Excerpt>> byMonth =
          ExcerptQuery.group(data, by: ExcerptGroup.month);
      expect(byMonth['2026-10']!.length, 2);
      expect(byMonth['2026-11']!.length, 2);
    });

    test('分组顺序由已排序列表决定（最近优先 → 11 月在 10 月前）', () {
      final List<Excerpt> sorted =
          ExcerptQuery.apply(excerpts: data, sort: ExcerptSort.newest);
      final Map<String, List<Excerpt>> g =
          ExcerptQuery.group(sorted, by: ExcerptGroup.month);
      expect(g.keys.first, '2026-11');
    });

    test('summary 统计总数 / 用户数 / 批注数 / 按书 / 按色', () {
      final ExcerptSummary s = ExcerptQuery.summarize(data);
      expect(s.total, 4);
      expect(s.userCount, 1);
      expect(s.withNoteCount, 2);
      expect(s.perBook['第 2 卷'], 2);
      expect(s.perColor[HighlightColor.sage], 1);
      expect(() => s.perBook['x'] = 9, throwsUnsupportedError);
    });

    test('bookOptions 带 id 与条数，按书名自然排序', () {
      final List<ExcerptBookOption> opts = ExcerptQuery.bookOptions(data);
      expect(opts.length, 3);
      expect(opts.first.title, '第 2 卷');
      expect(opts.first.count, 2);
      expect(opts.first.bookId, 'b01');
      expect(opts.last.title, '纸白纪事');
    });

    test('日期格式化不依赖 intl', () {
      expect(ExcerptQuery.formatDate(_d3), '2026-11-09');
      expect(ExcerptQuery.formatMonth(_d1), '2026-10');
    });
  });

  group('空状态分类', () {
    test('有结果 → none', () {
      expect(
        ExcerptQuery.emptyKind(
            total: 4, matched: 2, filter: const ExcerptFilter(query: '雪')),
        ExcerptEmptyKind.none,
      );
    });
    test('一条都没有 → noExcerpts', () {
      expect(
        ExcerptQuery.emptyKind(
            total: 0, matched: 0, filter: const ExcerptFilter(query: '雪')),
        ExcerptEmptyKind.noExcerpts,
      );
    });
    test('有数据但筛选无果 → noResult', () {
      expect(
        ExcerptQuery.emptyKind(
            total: 4, matched: 0, filter: const ExcerptFilter(query: '不存在')),
        ExcerptEmptyKind.noResult,
      );
    });
    test('有数据、空筛选却零结果 → noExcerpts（数据异常，不误导去清筛选）', () {
      expect(
        ExcerptQuery.emptyKind(
            total: 4, matched: 0, filter: const ExcerptFilter()),
        ExcerptEmptyKind.noExcerpts,
      );
    });
  });

  group('纯文本导出', () {
    test('空列表返回提示语', () {
      expect(ExcerptExporter.toPlainText(<Excerpt>[]),
          ExcerptExporter.emptyMessage);
    });

    test('含标题、条数、书名章节、正文、批注、日期与颜色', () {
      final String out = ExcerptExporter.toPlainText(<Excerpt>[
        ex('e2',
            text: '春樱落在阶前', at: _d2, color: HighlightColor.rose, note: '好看'),
      ]);
      expect(out, contains('我的摘录'));
      expect(out, contains('共 1 条'));
      expect(out, contains('《纸白纪事》 · 第一章  纸白'));
      expect(out, contains('春樱落在阶前'));
      expect(out, contains('—— 好看'));
      expect(out, contains('2026-11-03 · 胭脂 · 演示'));
      expect(out.trim().endsWith(ExcerptExporter.separator), isTrue);
    });

    test('includeMetadata=false 时省略日期与颜色元信息行', () {
      final String out = ExcerptExporter.toPlainText(
        <Excerpt>[ex('u1', at: _d3, user: true, color: HighlightColor.sage)],
        includeMetadata: false,
      );
      expect(out, contains('书页翻过去的时候'), reason: 'ex() 默认正文');
      expect(out, isNot(contains('2026-11-09')));
      expect(out, isNot(contains('青苔')));
    });

    test('多条之间都有分隔符', () {
      final String out = ExcerptExporter.toPlainText(sample());
      expect(ExcerptExporter.separator.allMatches(out).length, 4);
    });
  });

  group('AppState 编辑守卫与闭环', () {
    AppState make() => AppState(
          settingsStore: InMemorySettingsStore(),
          books: const DemoBookRepository(),
        );

    ExcerptDraft draft(String text, {String sig = 'sig-1'}) => ExcerptDraft(
          bookId: 'b01',
          chapterIndex: 0,
          pageIndex: 0,
          text: text,
          signature: sig,
          highlight: HighlightColor.amber,
          origin: LineRef(
            bookId: 'b01',
            chapterIndex: 0,
            pageIndex: 0,
            blockIndex: 0,
            lineInBlock: 0,
            text: text,
          ),
        );

    test('updateExcerpt 只改用户条目，演示种子返回 false', () {
      final AppState s = make();
      expect(s.updateExcerpt('e1', note: '不该改'), isFalse);
      final Excerpt? added = s.addExcerpt(
        draft('新摘的一句'),
        bookTitle: '纸白纪事',
        chapterTitle: '第一章',
        capturedAt: _d3,
      );
      expect(added, isNotNull);
      expect(
          s.updateExcerpt(added!.id,
              note: '改过的批注', highlight: HighlightColor.rose),
          isTrue);
      final Excerpt updated = s.userExcerpts.single;
      expect(updated.note, '改过的批注');
      expect(updated.highlight, HighlightColor.rose);
    });

    test('编辑不改正文与 signature，去重口径保持有效', () {
      final AppState s = make();
      final Excerpt? added = s.addExcerpt(
        draft('去重依据'),
        bookTitle: 'A',
        chapterTitle: 'c',
      );
      s.updateExcerpt(added!.id, note: '批注', highlight: HighlightColor.blue);
      expect(s.userExcerpts.single.text, '去重依据');
      expect(s.userExcerpts.single.signature, 'sig-1');
      expect(s.hasSignature('sig-1'), isTrue);
      expect(
        s.addExcerpt(draft('去重依据'), bookTitle: 'A', chapterTitle: 'c'),
        isNull,
        reason: '改批注不应让同一句被再次存入',
      );
    });

    test('同值编辑返回 false，不触发无意义通知', () {
      final AppState s = make();
      final Excerpt? added =
          s.addExcerpt(draft('一句'), bookTitle: 'A', chapterTitle: 'c');
      int notifications = 0;
      s.addListener(() => notifications++);
      expect(s.updateExcerpt(added!.id, note: ''), isFalse);
      expect(notifications, 0);
      expect(s.updateExcerpt(added.id, note: '新批注'), isTrue);
      expect(notifications, 1);
    });

    test('采集 → 按用户筛选 → 改色筛选 → 删除，列表同步', () {
      final AppState s = make();
      s.addExcerpt(draft('第一句', sig: 's1'), bookTitle: 'A', chapterTitle: 'c');
      s.addExcerpt(draft('第二句', sig: 's2'), bookTitle: 'A', chapterTitle: 'c');

      List<Excerpt> mine = ExcerptQuery.apply(
        excerpts: s.excerpts,
        filter: const ExcerptFilter(scope: ExcerptScope.userOnly),
      );
      expect(mine.length, 2);

      s.updateExcerpt(mine.first.id, highlight: HighlightColor.rose);
      final List<Excerpt> rose = ExcerptQuery.apply(
        excerpts: s.excerpts,
        filter: const ExcerptFilter(color: HighlightColor.rose),
      );
      expect(rose.length, 1);
      expect(rose.single.highlight, HighlightColor.rose);

      expect(s.removeExcerpt(mine.first.id), isTrue);
      mine = ExcerptQuery.apply(
        excerpts: s.excerpts,
        filter: const ExcerptFilter(scope: ExcerptScope.userOnly),
      );
      expect(mine.length, 1);
      expect(s.excerpts.length, 5, reason: '4 条演示种子 + 1 条用户');
    });
  });
}
