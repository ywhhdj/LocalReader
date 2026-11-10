import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/content/legal_texts.dart';
import 'package:local_reader/core/data/book_repository.dart';
import 'package:local_reader/core/data/library_query.dart';
import 'package:local_reader/core/state/app_scope.dart';
import 'package:local_reader/core/state/app_settings.dart';

BookSummary book(
  String id,
  String title, {
  String shelf = '本地书库',
  int volumeOrder = 0,
  double progress = 0,
  String author = '佚名',
}) =>
    BookSummary(
      id: id,
      title: title,
      author: author,
      spineColor: const Color(0xFF4A6180),
      shelf: shelf,
      volumeOrder: volumeOrder,
      progress: progress,
    );

void main() {
  group('自然排序 naturalCompare', () {
    test('第 2 卷排在 第 10 卷 之前（字典序会反过来）', () {
      expect(LibraryQuery.naturalCompare('第 2 卷', '第 10 卷'), lessThan(0));
      expect(LibraryQuery.naturalCompare('第 10 卷', '第 2 卷'), greaterThan(0));
    });

    test('中文数字：第二章 < 第十章 < 第十二章', () {
      expect(LibraryQuery.naturalCompare('第二章', '第十章'), lessThan(0));
      expect(LibraryQuery.naturalCompare('第十章', '第十二章'), lessThan(0));
    });

    test('中英混排数字与前缀相等时短串在前', () {
      expect(LibraryQuery.naturalCompare('卷2', '卷02'), lessThan(0));
      expect(LibraryQuery.naturalCompare('Book 3', 'Book 12'), lessThan(0));
      expect(LibraryQuery.naturalCompare('同一本书', '同一本书'), 0);
      expect(LibraryQuery.naturalCompare('甲', '甲乙'), lessThan(0));
    });
  });

  group('LibraryQuery.apply 排序', () {
    final List<BookSummary> books = <BookSummary>[
      book('b1', '未分卷的书'),
      book('b2', '第 10 卷', volumeOrder: 10),
      book('b3', '第 2 卷', volumeOrder: 2),
      book('b4', '第 2 卷·续', volumeOrder: 2),
      book('b5', '第 1 卷', volumeOrder: 1, progress: 0.8),
    ];

    test('按卷序：1 → 2 → 10，未分卷排最后', () {
      final List<BookSummary> r = LibraryQuery.apply(books: books);
      expect(r.map((BookSummary b) => b.id).toList(), <String>['b5', 'b3', 'b4', 'b2', 'b1']);
    });

    test('同卷内按书名自然排序', () {
      final List<BookSummary> r = LibraryQuery.apply(books: <BookSummary>[
        book('a', '第 10 章', volumeOrder: 1),
        book('b', '第 2 章', volumeOrder: 1),
      ]);
      expect(r.first.id, 'b');
    });

    test('按进度降序', () {
      final List<BookSummary> r = LibraryQuery.apply(books: books, sort: LibrarySort.progress);
      expect(r.first.progress, 0.8);
      expect(r.last.progress, 0);
    });

    test('按书名排序不受卷序影响', () {
      final List<BookSummary> r = LibraryQuery.apply(books: books, sort: LibrarySort.title);
      expect(r.first.title, '未分卷的书');
    });
  });

  group('搜索与分组', () {
    final List<BookSummary> books = <BookSummary>[
      book('b1', '雪国的旅行者', author: '川端 雪', shelf: '最近阅读', volumeOrder: 1),
      book('b2', '春樱手账', author: '林 未央', shelf: '本地书库', volumeOrder: 2),
      book('b3', 'PDF 手册', author: '编辑部', shelf: '本地书库', volumeOrder: 3),
    ];

    test('书名 / 作者匹配', () {
      expect(LibraryQuery.apply(books: books, query: '雪国').single.id, 'b1');
      expect(LibraryQuery.apply(books: books, query: '未央').single.id, 'b2');
    });

    test('格式与分组名也参与匹配，大小写不敏感', () {
      expect(LibraryQuery.apply(books: books, query: 'pdf').single.id, 'b3');
      expect(LibraryQuery.apply(books: books, query: '最近阅读').single.id, 'b1');
    });

    test('按分组过滤', () {
      final List<BookSummary> r = LibraryQuery.apply(books: books, shelf: '本地书库');
      expect(r.length, 2);
      expect(r.every((BookSummary b) => b.shelf == '本地书库'), isTrue);
    });

    test('无匹配返回空且不可变', () {
      final List<BookSummary> r = LibraryQuery.apply(books: books, query: '不存在的书');
      expect(r, isEmpty);
      expect(() => r.add(book('x', 'x')), throwsUnsupportedError);
    });

    test('shelfCounts 统计各分组册数', () {
      final Map<String, int> counts = LibraryQuery.shelfCounts(books);
      expect(counts['最近阅读'], 1);
      expect(counts['本地书库'], 2);
    });

    test('groupByShelf 保持给定分组顺序', () {
      final Map<String, List<BookSummary>> g = LibraryQuery.groupByShelf(
        books,
        shelfOrder: <String>['最近阅读', '本地书库'],
      );
      expect(g.keys.toList(), <String>['最近阅读', '本地书库']);
      expect(g['本地书库']!.length, 2);
    });
  });

  group('空状态分类', () {
    test('有结果 → none', () {
      expect(LibraryQuery.emptyKind(total: 10, matched: 3, query: '雪'), LibraryEmptyKind.none);
    });
    test('书库为空 → noLibrary（引导导入）', () {
      expect(LibraryQuery.emptyKind(total: 0, matched: 0, query: ''), LibraryEmptyKind.noLibrary);
      expect(LibraryQuery.emptyKind(total: 0, matched: 0, query: '雪'), LibraryEmptyKind.noLibrary);
    });
    test('有书但无匹配 → noResult（引导改关键词）', () {
      expect(LibraryQuery.emptyKind(total: 10, matched: 0, query: '雪'), LibraryEmptyKind.noResult);
    });
    test('有书、空关键词却无结果时也归为 noLibrary', () {
      expect(LibraryQuery.emptyKind(total: 10, matched: 0, query: '  '), LibraryEmptyKind.noLibrary);
    });
  });

  group('元数据覆盖层驱动书架重排', () {
    test('把某本未分卷的书改成第 1 卷后，它排到最前', () {
      final AppState state = AppState(
        settingsStore: InMemorySettingsStore(),
        books: const DemoBookRepository(),
      );
      final List<BookSummary> before = state.library();
      final BookSummary target = before.firstWhere((BookSummary b) => b.id == 'b06');
      expect(target.volumeOrder, 0);

      state.updateBook('b06', volumeOrder: 1);
      final List<BookSummary> after = state.library();
      expect(after.first.id, 'b06', reason: '卷序编辑应即时反映到共享查询出口');
      expect(after.first.title, target.title, reason: 'effective() 保持编辑后的展示数据');
    });
  });

  group('合规文案单一源', () {
    test('关键口径集中在 LegalTexts，不散在页面里', () {
      expect(LegalTexts.appDisclaimer, contains('不运营在线书库'));
      expect(LegalTexts.freeStatement, contains('自愿支持'));
      expect(LegalTexts.contentRights, contains('归各权利人所有'));
      expect(LegalTexts.issueGuidance, contains('Cookie'));
      expect(LegalTexts.archiveNotice, contains('CBZ/ZIP'));
    });

    test('aboutParagraphs 覆盖六条且顺序稳定', () {
      expect(LegalTexts.aboutParagraphs.length, 6);
      expect(LegalTexts.aboutParagraphs.first, LegalTexts.nonOfficial);
      expect(LegalTexts.aboutParagraphs.last, LegalTexts.thirdPartyService);
    });
  });
}
