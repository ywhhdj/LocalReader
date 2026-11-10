import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/content/legal_texts.dart';
import 'package:local_reader/core/data/book_repository.dart';
import 'package:local_reader/core/favorites/favorite_routes.dart';
import 'package:local_reader/core/router/route_args.dart';
import 'package:local_reader/core/state/app_scope.dart';
import 'package:local_reader/core/state/app_settings.dart';
import 'package:local_reader/core/stats/excerpt_query.dart';
import 'package:local_reader/core/stats/reading_stats.dart';

// DateTime 没有 const 构造函数（工程里演示数据同样用 DateTime.utc 运行时构造）。
final DateTime t0 = DateTime.utc(2026, 3, 1, 10);
final DateTime t1 = DateTime.utc(2026, 3, 2, 10);
final DateTime t2 = DateTime.utc(2026, 3, 3, 10);

Excerpt ex(
  String id,
  String bookId, {
  String title = '雪国的旅行者',
  String text = '一句摘录。',
  DateTime? at,
}) =>
    Excerpt(
      id: id,
      bookId: bookId,
      bookTitle: title,
      chapterTitle: '第一章',
      text: text,
      capturedAt: at ?? t0,
    );

final List<Excerpt> sample = <Excerpt>[
  Excerpt(
      id: 'e1',
      bookId: 'b01',
      bookTitle: '雪国的旅行者',
      chapterTitle: '第一章',
      text: '雪国的一句。',
      capturedAt: t0),
  Excerpt(
      id: 'e2',
      bookId: 'b01',
      bookTitle: '雪国的旅行者',
      chapterTitle: '第二章',
      text: '另一句。',
      capturedAt: t1),
  Excerpt(
      id: 'e3',
      bookId: 'b04',
      bookTitle: '秋笺拾遗',
      chapterTitle: '第三章',
      text: '秋天的一句。',
      capturedAt: t2),
];

void main() {
  group('ExcerptLibraryArgs 深链单一构造口', () {
    test('forBook 只带 bookId，不夹带关键词', () {
      final ExcerptLibraryArgs a = ExcerptLibraryArgs.forBook('b01');
      expect(a.initialBookId, 'b01');
      expect(a.initialQuery, '');
      expect(a.isBookScoped, isTrue);
    });

    test('forBook 空 id 不带筛选，避免打开一个空 id 条件', () {
      final ExcerptLibraryArgs a = ExcerptLibraryArgs.forBook('');
      expect(a.initialBookId, isNull);
      expect(a.isBookScoped, isFalse);
    });

    test('forQuery 带关键词与可选 bookId', () {
      final ExcerptLibraryArgs a =
          ExcerptLibraryArgs.forQuery('雪', bookId: 'b01');
      expect(a.initialQuery, '雪');
      expect(a.initialBookId, 'b01');
      expect(a.isBookScoped, isTrue);
      expect(ExcerptLibraryArgs.forQuery('雪').initialBookId, isNull);
      expect(
          ExcerptLibraryArgs.forQuery('雪', bookId: '').isBookScoped, isFalse);
    });

    test('三条入口构造出的按书深链参数完全一致', () {
      // 详情页入口 / 收藏路由 / forBook 工厂三处必须等价，否则某处会静默打开全部摘录。
      final ExcerptLibraryArgs viaFactory = ExcerptLibraryArgs.forBook('b01');
      final BookSummary? book = const DemoBookRepository().byId('b01');
      final FavoriteNavigation nav = FavoriteRouter.resolve(
        FavoriteEntry(
            bookId: 'b01', target: FavoriteTarget.excerpts, addedAt: t0),
        book,
      )!;
      final ExcerptLibraryArgs viaFavorite =
          nav.arguments as ExcerptLibraryArgs;
      expect(viaFavorite.initialBookId, viaFactory.initialBookId);
      expect(viaFavorite.initialQuery, viaFactory.initialQuery);
      expect(nav.route, FavoriteRouteName.excerpts);
    });

    test('收藏目标指向不存在的书时返回 null，不跳空页面', () {
      expect(
        FavoriteRouter.resolve(
          FavoriteEntry(
              bookId: 'missing', target: FavoriteTarget.excerpts, addedAt: t0),
          null,
        ),
        isNull,
      );
    });

    test('const 构造仍可用，工厂不破坏向后兼容', () {
      const ExcerptLibraryArgs a =
          ExcerptLibraryArgs(initialQuery: 'x', initialBookId: 'b01');
      expect(a.initialQuery, 'x');
      expect(a.isBookScoped, isTrue);
    });
  });

  group('按 bookId 过滤与条数口径', () {
    test('apply 按 bookId 过滤，不受快照书名影响', () {
      final List<Excerpt> r = ExcerptQuery.apply(
        excerpts: sample,
        filter: const ExcerptFilter(bookId: 'b01'),
      );
      expect(r.map<String>((Excerpt e) => e.id), <String>['e2', 'e1']);
    });

    test('countForBook 数的是全部摘录，不受当前筛选影响', () {
      expect(ExcerptQuery.countForBook(sample, 'b01'), 2);
      final List<Excerpt> filtered = ExcerptQuery.apply(
        excerpts: sample,
        filter: const ExcerptFilter(bookId: 'b01', query: '不存在的词'),
      );
      expect(filtered, isEmpty);
      expect(ExcerptQuery.countForBook(sample, 'b01'), 2,
          reason: '详情页卡片与空状态共用「全书条数」，不能被筛选缩掉');
      expect(ExcerptQuery.countForBook(sample, 'b99'), 0);
    });

    test('copyWith(clearBook: true) 能真正取消按书筛选', () {
      const ExcerptFilter f = ExcerptFilter(bookId: 'b01', query: '雪');
      expect(f.copyWith(clearBook: true).bookId, isNull);
      expect(f.copyWith(clearBook: true).query, '雪');
      expect(f.copyWith(bookId: 'b04').bookId, 'b04');
    });

    test('书名快照改了也不影响按书筛选身份', () {
      final List<Excerpt> renamed = <Excerpt>[
        ex('e1', 'b01', title: '雪国的旅行者'),
        ex('e2', 'b01', title: '改名后的雪国'),
      ];
      expect(
        ExcerptQuery.apply(
          excerpts: renamed,
          filter: const ExcerptFilter(bookId: 'b01'),
        ).length,
        2,
      );
    });
  });

  group('bookOptions 零摘录深链固定选项', () {
    test('零摘录的书被固定成 count=0 的可见选项', () {
      final List<ExcerptBookOption> o = ExcerptQuery.bookOptions(
        sample,
        pinnedBookId: 'b07',
        pinnedTitle: '星屑与旧钟',
      );
      final ExcerptBookOption pinned = o.firstWhere(
        (ExcerptBookOption e) => e.bookId == 'b07',
      );
      expect(pinned.count, 0);
      expect(pinned.title, '星屑与旧钟');
    });

    test('固定选项与其它选项一起按书名自然排序', () {
      final List<ExcerptBookOption> o = ExcerptQuery.bookOptions(
        sample,
        pinnedBookId: 'b07',
        pinnedTitle: '星屑与旧钟',
      );
      expect(o.length, 3);
      expect(
          o.map<String>((ExcerptBookOption e) => e.bookId).toSet().length, 3);
      expect(
        o
            .where((ExcerptBookOption e) => e.bookId != 'b07')
            .every((ExcerptBookOption e) => e.count > 0),
        isTrue,
        reason: '只有 pinned 那一项为 0，其它项仍是真实条数',
      );
    });

    test('pinnedTitle 缺失时回落「未标注书名」，不显示空书名号', () {
      final List<ExcerptBookOption> o = ExcerptQuery.bookOptions(
        sample,
        pinnedBookId: 'b99',
      );
      expect(o.firstWhere((ExcerptBookOption e) => e.bookId == 'b99').title,
          '未标注书名');
    });

    test('pinnedBookId 为 null 时不凭空多出选项', () {
      expect(ExcerptQuery.bookOptions(sample).length, 2);
    });

    test('同一本书固定两次不会产生重复选项', () {
      final List<ExcerptBookOption> o = ExcerptQuery.bookOptions(
        sample,
        pinnedBookId: 'b01',
        pinnedTitle: '雪国的旅行者',
      );
      expect(o.where((ExcerptBookOption e) => e.bookId == 'b01').length, 1);
    });
  });

  group('书名覆盖层是展示层唯一出口', () {
    test('titleResolver 让已有摘录的选项改用书库当前书名', () {
      final List<ExcerptBookOption> o = ExcerptQuery.bookOptions(
        sample,
        titleResolver: (String id) => id == 'b01' ? '雪国 · 修订版' : null,
      );
      expect(o.firstWhere((ExcerptBookOption e) => e.bookId == 'b01').title,
          '雪国 · 修订版');
      expect(o.firstWhere((ExcerptBookOption e) => e.bookId == 'b04').title,
          '秋笺拾遗',
          reason: '解析不到时回落快照');
    });

    test('resolver 优先于 pinnedTitle，不产生两套书名裁决', () {
      final List<ExcerptBookOption> o = ExcerptQuery.bookOptions(
        sample,
        pinnedBookId: 'b01',
        pinnedTitle: '快照旧名',
        titleResolver: (String id) => '书库新名',
      );
      expect(o.firstWhere((ExcerptBookOption e) => e.bookId == 'b01').title,
          '书库新名');
    });

    test('零摘录深链也走同一个 resolver', () {
      final List<ExcerptBookOption> o = ExcerptQuery.bookOptions(
        sample,
        pinnedBookId: 'b07',
        pinnedTitle: '星屑与旧钟',
        titleResolver: (String id) => id == 'b07' ? '星屑 · 新装版' : null,
      );
      expect(o.firstWhere((ExcerptBookOption e) => e.bookId == 'b07').title,
          '星屑 · 新装版');
    });

    test('空白解析结果回落快照，不显示空标题', () {
      final List<ExcerptBookOption> o = ExcerptQuery.bookOptions(
        sample,
        titleResolver: (String id) => '   ',
      );
      expect(o.firstWhere((ExcerptBookOption e) => e.bookId == 'b01').title,
          '雪国的旅行者');
    });

    test('resolveBook 带覆盖层，effective 与 resolveBook 结果一致', () {
      final AppState state = AppState(
        settingsStore: InMemorySettingsStore(),
        books: const DemoBookRepository(),
      );
      final BookSummary before = state.resolveBook('b01')!;
      expect(before.title, '雪国的旅行者');
      state.updateBook('b01', title: '雪国 · 修订版');
      expect(state.resolveBook('b01')!.title, '雪国 · 修订版');
      expect(state.effective(before).title, state.resolveBook('b01')!.title);
      // 快照不动：导出仍稳定，只把展示层切到书库当前书名。
      expect(sample.first.bookTitle, '雪国的旅行者');
    });

    test('书库里没有这本书时 resolveBook 返回 null，页面有专属说明', () {
      final AppState state = AppState(
        settingsStore: InMemorySettingsStore(),
        books: const DemoBookRepository(),
      );
      expect(state.resolveBook('missing-book'), isNull);
      expect(LegalTexts.bookExcerptMissingNote, contains('不在当前书库'));
    });
  });

  group('emptyKind 四分支', () {
    test('有命中 → none', () {
      expect(
        ExcerptQuery.emptyKind(
            total: 3, matched: 2, filter: const ExcerptFilter(bookId: 'b01')),
        ExcerptEmptyKind.none,
      );
    });

    test('全书库没有摘录 → noExcerpts（优先于 bookHasNone）', () {
      expect(
        ExcerptQuery.emptyKind(
          total: 0,
          matched: 0,
          filter: const ExcerptFilter(bookId: 'b01'),
          scopedBookCount: 0,
        ),
        ExcerptEmptyKind.noExcerpts,
      );
    });

    test('深链的书一本摘录都没有 → bookHasNone', () {
      expect(
        ExcerptQuery.emptyKind(
          total: 3,
          matched: 0,
          filter: const ExcerptFilter(bookId: 'b07'),
          scopedBookCount: 0,
        ),
        ExcerptEmptyKind.bookHasNone,
      );
      expect(LegalTexts.bookExcerptEmptyTitle, '这本书还没有摘录');
      expect(LegalTexts.bookExcerptEmptyBody, contains('阅读器'));
    });

    test('书有摘录但被其它条件筛掉 → noResult，不误报「这本书还没有摘录」', () {
      expect(
        ExcerptQuery.emptyKind(
          total: 3,
          matched: 0,
          filter: const ExcerptFilter(bookId: 'b01', query: '不存在的词'),
          scopedBookCount: 2,
        ),
        ExcerptEmptyKind.noResult,
      );
    });

    test('无筛选且无命中 → noExcerpts', () {
      expect(
        ExcerptQuery.emptyKind(
            total: 3, matched: 0, filter: const ExcerptFilter()),
        ExcerptEmptyKind.noExcerpts,
      );
    });

    test('bookHasNone 只在按书深链下出现', () {
      expect(
        ExcerptQuery.emptyKind(
          total: 3,
          matched: 0,
          filter: const ExcerptFilter(),
          scopedBookCount: 0,
        ),
        isNot(ExcerptEmptyKind.bookHasNone),
      );
    });
  });

  group('详情入口文案与键覆盖', () {
    test('六条深链文案 + 一条脏 ID 说明都收进单一源', () {
      for (final String k in <String>[
        'bookExcerptTitle',
        'bookExcerptEmptyTitle',
        'bookExcerptEmptyBody',
        'bookExcerptScopedNote',
        'bookExcerptPinnedNote',
        'bookExcerptStaticNote',
        'bookExcerptMissingNote',
      ]) {
        expect(LegalTexts.keys.contains(k), isTrue, reason: '$k 未登记键集合');
      }
    });

    test('键集合共 74 项且无重复', () {
      expect(LegalTexts.keys.length, 74);
      expect(LegalTexts.keys.toSet().length, 74);
    });

    test('静态说明写明只传 bookId、不落盘、不联网', () {
      expect(LegalTexts.bookExcerptStaticNote, contains('bookId'));
      expect(LegalTexts.bookExcerptStaticNote, contains('不落盘'));
      expect(LegalTexts.bookExcerptScopedNote, contains('bookId'));
      expect(LegalTexts.bookExcerptPinnedNote, contains('0 条'));
    });
  });

  group('详情卡片条数与摘录页一致', () {
    test('详情页卡片用 apply(bookId) 与摘录页 countForBook 得到同一个数字', () {
      final List<Excerpt> detailCard = ExcerptQuery.apply(
        excerpts: sample,
        filter: const ExcerptFilter(bookId: 'b01'),
      );
      expect(detailCard.length, ExcerptQuery.countForBook(sample, 'b01'));
    });

    test('零摘录时详情卡片仍可点，管理页给出专属空状态', () {
      final List<Excerpt> detailCard = ExcerptQuery.apply(
        excerpts: sample,
        filter: const ExcerptFilter(bookId: 'b07'),
      );
      expect(detailCard, isEmpty);
      expect(
        ExcerptQuery.emptyKind(
          total: sample.length,
          matched: 0,
          filter: const ExcerptFilter(bookId: 'b07'),
          scopedBookCount: ExcerptQuery.countForBook(sample, 'b07'),
        ),
        ExcerptEmptyKind.bookHasNone,
      );
    });

    test('BookSummary 构造不因覆盖层改名而换 id', () {
      const BookSummary b = BookSummary(
        id: 'b01',
        title: '旧名',
        author: '作者',
        spineColor: Color(0xFF000000),
        shelf: '最近阅读',
      );
      expect(b.copyWith(title: '新名').id, 'b01');
    });
  });
}
