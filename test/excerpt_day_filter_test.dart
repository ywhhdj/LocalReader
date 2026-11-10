import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/router/route_args.dart';
import 'package:local_reader/core/stats/excerpt_capture.dart';
import 'package:local_reader/core/stats/excerpt_query.dart';
import 'package:local_reader/core/stats/reading_stats.dart';

Excerpt ex(String id, String at, {String bookId = 'b1'}) => Excerpt(
      id: id,
      bookId: bookId,
      bookTitle: '雪国的旅行者',
      chapterTitle: '第一章',
      text: '摘录 $id',
      capturedAt: DateTime.utc(
        int.parse(at.substring(0, 4)),
        int.parse(at.substring(5, 7)),
        int.parse(at.substring(8, 10)),
      ),
    );

final List<Excerpt> data = <Excerpt>[
  ex('e1', '2026-10-07'),
  ex('e2', '2026-11-08'),
  ex('e3', '2026-11-08', bookId: 'b2'),
  ex('e4', '2026-11-20'),
];

List<String> ids(List<Excerpt> items) => items.map((Excerpt e) => e.id).toList();

void main() {
  group('ExcerptLibraryArgs.fromDay 深链工厂', () {
    test('合法 dateKey 只带日期，不带 bookId / query', () {
      final ExcerptLibraryArgs a =
          ExcerptLibraryArgs.fromDay('2026-11-08');
      expect(a.initialDateKey, '2026-11-08');
      expect(a.isDayScoped, isTrue);
      expect(a.isBookScoped, isFalse);
      expect(a.initialQuery, isEmpty);
    });

    test('非法 / 空 dateKey 回落不带筛选', () {
      for (final String? k in <String?>[null, '', '2026-02-30', 'bad']) {
        final ExcerptLibraryArgs a = ExcerptLibraryArgs.fromDay(k);
        expect(a.initialDateKey, isNull);
        expect(a.isDayScoped, isFalse);
      }
    });

    test('第十六轮既有工厂行为不被回归', () {
      expect(ExcerptLibraryArgs.forBook('b9').isBookScoped, isTrue);
      expect(ExcerptLibraryArgs.forBook('').isBookScoped, isFalse);
      expect(ExcerptLibraryArgs.forQuery('雪', bookId: 'b9').isBookScoped,
          isTrue);
      expect(ExcerptLibraryArgs.forQuery('雪').initialQuery, '雪');
    });
  });

  group('matches / apply：按日筛选', () {
    test('dateKey 只命中那一天（含不同书）', () {
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(dateKey: '2026-11-08'),
          sort: ExcerptSort.oldest,
        )),
        <String>['e2', 'e3'],
      );
    });

    test('按日 ∧ 按书 ∧ 按色 ∧ 按范围可叠加', () {
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(
            dateKey: '2026-11-08',
            bookId: 'b2',
          ),
        )),
        <String>['e3'],
      );
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(
            dateKey: '2026-11-08',
            color: HighlightColor.rose,
          ),
        )),
        isEmpty,
      );
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(
            dateKey: '2026-11-08',
            scope: ExcerptScope.userOnly,
          ),
        )),
        isEmpty,
      );
    });

    test('不存在的日期返回空，不回落全部', () {
      expect(
        ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(dateKey: '2026-11-09'),
        ),
        isEmpty,
      );
    });

    test('按日不干扰关键词搜索', () {
      expect(
        ids(ExcerptQuery.apply(
          excerpts: data,
          filter: const ExcerptFilter(dateKey: '2026-11-08', query: 'e3'),
        )),
        <String>['e3'],
      );
    });

    test('dateKey 由 capturedAt 的 UTC 年月日生成，不带时分', () {
      final Excerpt withTime = Excerpt(
        id: 'et',
        bookId: 'b1',
        bookTitle: '书',
        chapterTitle: '章',
        text: '带时分',
        capturedAt: DateTime.utc(2026, 11, 8, 23, 59),
      );
      expect(
        ids(ExcerptQuery.apply(
          excerpts: <Excerpt>[withTime],
          filter: const ExcerptFilter(dateKey: '2026-11-08'),
        )),
        <String>['et'],
      );
    });
  });

  group('countForDay 与空状态分支', () {
    test('countForDay 算全量，不受当前筛选影响', () {
      expect(ExcerptQuery.countForDay(data, '2026-11-08'), 2);
      expect(ExcerptQuery.countForDay(data, '2026-11-09'), 0);
      expect(ExcerptQuery.countForDay(const <Excerpt>[], '2026-11-08'), 0);
    });

    test('该日全量 0 条 → dayHasNone（引导回日历换一天）', () {
      expect(
        ExcerptQuery.emptyKind(
          total: data.length,
          matched: 0,
          filter: const ExcerptFilter(dateKey: '2026-11-09'),
          scopedDayCount: 0,
        ),
        ExcerptEmptyKind.dayHasNone,
      );
    });

    test('该日有 2 条但被按书筛掉 → noResult，不误报 dayHasNone', () {
      expect(
        ExcerptQuery.emptyKind(
          total: data.length,
          matched: 0,
          filter: const ExcerptFilter(
            dateKey: '2026-11-08',
            bookId: 'ghost',
          ),
          scopedBookCount: 0,
          scopedDayCount: 2,
        ),
        ExcerptEmptyKind.bookHasNone,
        reason: '按书全量零条优先于按日（bookHasNone 先判）',
      );
      expect(
        ExcerptQuery.emptyKind(
          total: data.length,
          matched: 0,
          filter: const ExcerptFilter(
            dateKey: '2026-11-08',
            query: '不存在的词',
          ),
          scopedDayCount: 2,
        ),
        ExcerptEmptyKind.noResult,
      );
    });

    test('有命中 → none；全书库空 → noExcerpts', () {
      expect(
        ExcerptQuery.emptyKind(
            total: 4,
            matched: 2,
            filter: const ExcerptFilter(dateKey: '2026-11-08'),
            scopedDayCount: 2),
        ExcerptEmptyKind.none,
      );
      expect(
        ExcerptQuery.emptyKind(
            total: 0,
            matched: 0,
            filter: const ExcerptFilter(dateKey: '2026-11-08'),
            scopedDayCount: 0),
        ExcerptEmptyKind.noExcerpts,
      );
    });
  });

  group('ExcerptFilter 值语义与清空语义', () {
    test('dateKey 参与 == / hashCode', () {
      const ExcerptFilter a = ExcerptFilter(dateKey: '2026-11-08');
      const ExcerptFilter b = ExcerptFilter(dateKey: '2026-11-09');
      expect(a, isNot(b));
      expect(a, const ExcerptFilter(dateKey: '2026-11-08'));
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('isEmpty 含 dateKey；isDayScoped', () {
      expect(const ExcerptFilter().isEmpty, isTrue);
      expect(const ExcerptFilter(dateKey: '2026-11-08').isEmpty, isFalse);
      expect(const ExcerptFilter(dateKey: '2026-11-08').isDayScoped, isTrue);
    });

    test('clearDate 只清日期，不动 bookId / color / scope / query', () {
      const ExcerptFilter f = ExcerptFilter(
        dateKey: '2026-11-08',
        bookId: 'b1',
        color: HighlightColor.rose,
        scope: ExcerptScope.withNote,
        query: '雪',
      );
      final ExcerptFilter out = f.copyWith(clearDate: true);
      expect(out.dateKey, isNull);
      expect(out.bookId, 'b1');
      expect(out.color, HighlightColor.rose);
      expect(out.scope, ExcerptScope.withNote);
      expect(out.query, '雪');
    });

    test('copyWith(dateKey: null) 不能表示清空（显式开关纪律）', () {
      const ExcerptFilter f = ExcerptFilter(dateKey: '2026-11-08');
      expect(f.copyWith(dateKey: null).dateKey, '2026-11-08');
      expect(f.copyWith(clearDate: true).dateKey, isNull);
    });

    test('const ExcerptFilter() 清掉全部维度（重置按钮）', () {
      const ExcerptFilter dirty = ExcerptFilter(
        dateKey: '2026-11-08',
        bookId: 'b1',
        query: '雪',
      );
      expect(const ExcerptFilter().isEmpty, isTrue);
      expect(dirty.isEmpty, isFalse);
    });
  });
}
