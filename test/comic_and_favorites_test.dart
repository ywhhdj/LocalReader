import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/comic/comic_toc.dart';
import 'package:local_reader/core/data/book_repository.dart';
import 'package:local_reader/core/data/demo_document.dart';
import 'package:local_reader/core/data/library_query.dart';
import 'package:local_reader/core/favorites/favorite_routes.dart';
import 'package:local_reader/core/models/book_document.dart';
import 'package:local_reader/core/router/route_args.dart';
import 'package:local_reader/core/state/app_scope.dart';
import 'package:local_reader/core/state/app_settings.dart';
import 'package:local_reader/core/state/reader_style.dart';

void main() {
  group('ComicTocParser 分话识别', () {
    test('只保留图片，非图片文件被过滤', () {
      final ComicToc toc = ComicTocParser.fromPaths(<String>[
        'a/第1话/001.jpg',
        'a/第1话/readme.txt',
        'a/第1话/002.PNG',
        'a/第1话/Thumbs.db',
      ]);
      expect(toc.pageCount, 2);
      expect(toc.episodeCount, 1);
      expect(toc.pagePaths.first, contains('001.jpg'));
    });

    test('空输入返回空目录，不崩溃', () {
      expect(ComicTocParser.fromPaths(<String>[]).isEmpty, isTrue);
      expect(ComicToc.empty.pageCount, 0);
      expect(ComicToc.empty.episodeForPage(0), isNull);
    });

    test('阿拉伯数字话号按数值排序，第 10 话不会排到第 2 话前', () {
      final ComicToc toc = ComicTocParser.fromPaths(<String>[
        'x/第10话/001.jpg',
        'x/第2话/001.jpg',
        'x/第1话/001.jpg',
      ]);
      expect(toc.episodes.map((ComicEpisode e) => e.label).toList(),
          <String>['第 1 话', '第 2 话', '第 10 话']);
      expect(toc.episodes.map((ComicEpisode e) => e.number).toList(),
          <int?>[1, 2, 10]);
    });

    test('中文数字话号：第十话解析为 10', () {
      final ComicToc toc = ComicTocParser.fromPaths(<String>[
        'x/第十话/001.jpg',
        'x/第二话/001.jpg',
      ]);
      expect(toc.episodes.first.label, '第 2 话');
      expect(toc.episodes.last.label, '第 10 话');
    });

    test('英文 Chapter / Vol / # 三种写法', () {
      final ComicToc toc = ComicTocParser.fromPaths(<String>[
        'x/Chapter 3/001.jpg',
        'x/Vol.02/001.jpg',
        'x/#7/001.jpg',
      ]);
      expect(toc.episodes.map((ComicEpisode e) => e.label).toList(),
          <String>['Vol. 2', 'Chapter 3', '#7']);
    });

    test('番外排在全部正篇之后，标记为 special', () {
      final ComicToc toc = ComicTocParser.fromPaths(<String>[
        'x/番外  后日谈/001.jpg',
        'x/第2话/001.jpg',
        'x/第1话/001.jpg',
      ]);
      expect(toc.episodes.last.kind, ComicEpisodeKind.special);
      expect(toc.episodes.first.label, '第 1 话');
      expect(toc.episodes.last.label, contains('番外'));
    });

    test('未识别页归入「未分话」，不静默丢页，识别率可计算', () {
      final ComicToc toc = ComicTocParser.fromPaths(<String>[
        'x/第1话/001.jpg',
        'x/001.jpg',
        'x/002.jpg',
      ]);
      expect(toc.pageCount, 3);
      expect(toc.recognizedPages, 1);
      expect(toc.recognitionRate, closeTo(1 / 3, 0.0001));
      expect(
          toc.episodes
              .any((ComicEpisode e) => !e.recognized && e.label == '未分话'),
          isTrue);
      expect(
          toc.episodes.fold<int>(0, (int s, ComicEpisode e) => s + e.pageCount),
          3);
    });

    test('全部未识别时整本作为单话兜底', () {
      final ComicToc toc =
          ComicTocParser.fromPaths(<String>['001.jpg', '002.jpg']);
      expect(toc.isSplit, isFalse);
      expect(toc.episodeCount, 1);
      expect(toc.recognitionRate, 0);
      expect(toc.episodes.single.pageCount, 2);
    });

    test('话集排序后 pageStart 连续且覆盖全部页', () {
      final ComicToc toc = DemoComicFactory.toc();
      int cursor = 0;
      for (final ComicEpisode e in toc.episodes) {
        expect(e.pageStart, cursor);
        expect(e.pageCount, greaterThan(0));
        cursor = e.pageEndExclusive;
      }
      expect(cursor, toc.pageCount);
      expect(toc.pagePaths.length, toc.pageCount);
    });

    test('同一话内按文件名自然排序：001 / 002 / 010', () {
      final ComicToc toc = ComicTocParser.fromPaths(<String>[
        'x/第1话/010.jpg',
        'x/第1话/002.jpg',
        'x/第1话/001.jpg',
      ]);
      expect(toc.pagePaths.map((String p) => p.split('/').last).toList(),
          <String>['001.jpg', '002.jpg', '010.jpg']);
    });

    test('episodeForPage / headerForPage / pageForEpisode 一致', () {
      final ComicToc toc = DemoComicFactory.toc();
      for (int i = 0; i < toc.episodeCount; i++) {
        final int start = toc.pageForEpisode(i);
        expect(headerLabelFor(toc, start), toc.episodes[i].label);
        expect(toc.episodeIndexForPage(start), i);
        expect(headerLabelFor(toc, start + 1), isNull, reason: '只有话首带标题');
      }
      expect(toc.episodeForPage(-1), isNull);
      expect(toc.episodeForPage(toc.pageCount), isNull);
    });

    test('演示漫画目录覆盖 4 个正篇 + 番外 + 未分话', () {
      final ComicToc toc = DemoComicFactory.toc();
      expect(toc.pageCount, 10);
      expect(toc.isSplit, isTrue);
      expect(
          toc.episodes
              .where((ComicEpisode e) => e.kind == ComicEpisodeKind.special)
              .length,
          1);
      expect(toc.episodes.where((ComicEpisode e) => !e.recognized).length, 1);
      expect(toc.recognitionRate, closeTo(0.8, 0.0001));
    });
  });

  group('ComicLayoutMetrics 竖向偏移', () {
    test('prefixOffsets 单调递增且末项等于总高度', () {
      const ComicLayoutMetrics m =
          ComicLayoutMetrics(pageWidth: 300, pageGap: 10, headerHeight: 40);
      final List<ComicPageItem> items = <ComicPageItem>[
        const ComicPageItem(
            pageIndex: 0, aspectRatio: 0.6, headerLabel: '第 1 话'),
        const ComicPageItem(pageIndex: 1, aspectRatio: 0.6),
        const ComicPageItem(
            pageIndex: 2, aspectRatio: 0.8, headerLabel: '第 2 话'),
      ];
      final List<double> p = m.prefixOffsets(items);
      expect(p.length, 4);
      expect(p[0], 0);
      expect(p[1], 300 / 0.6 + 40 + 10);
      expect(p[2], p[1] + 300 / 0.6 + 10);
      expect(p[3], p[2] + 300 / 0.8 + 40 + 10);
    });

    test('pageAtOffset 二分落在正确区间并夹住越界', () {
      const ComicLayoutMetrics m = ComicLayoutMetrics(pageWidth: 300);
      final List<ComicPageItem> items = ComicLayoutMetrics.buildItems(
        DemoComicFactory.toc(),
      );
      final List<double> p = m.prefixOffsets(items);
      expect(m.pageAtOffset(p, -50), 0);
      expect(m.pageAtOffset(p, 0), 0);
      expect(m.pageAtOffset(p, p[1] - 0.01), 0);
      expect(m.pageAtOffset(p, p[1]), 1);
      expect(m.pageAtOffset(p, p[5] + 1), 5);
      expect(m.pageAtOffset(p, p.last + 999), items.length - 1);
    });

    test('buildItems 只在话首带 headerLabel', () {
      final ComicToc toc = DemoComicFactory.toc();
      final List<ComicPageItem> items = ComicLayoutMetrics.buildItems(
        toc,
        aspectRatios: DemoComicFactory.aspectRatios(toc.pageCount),
      );
      expect(items.length, toc.pageCount);
      final List<int> headers = <int>[
        for (int i = 0; i < items.length; i++)
          if (items[i].headerLabel != null) i,
      ];
      expect(
          headers, toc.episodes.map((ComicEpisode e) => e.pageStart).toList());
      expect(items.first.aspectRatio, 0.62);
    });

    test('宽高比被夹住，避免极端值让页高为 0 或爆炸', () {
      const ComicLayoutMetrics m = ComicLayoutMetrics(pageWidth: 300);
      expect(m.clampedRatio(0.01), 0.35);
      expect(m.clampedRatio(99), 3.0);
      expect(m.pageHeight(const ComicPageItem(pageIndex: 0, aspectRatio: 0.01)),
          300 / 0.35);
    });
  });

  group('ReaderStyle 漫画模式偏好', () {
    test('默认竖向，且不影响小说分页缓存键', () {
      const ReaderStyle a = ReaderStyle();
      final ReaderStyle b = a.copyWith(comicReadMode: ComicReadMode.paged);
      expect(a.comicReadMode, ComicReadMode.vertical);
      expect(b.comicReadMode, ComicReadMode.paged);
      expect(b.layoutKey, a.layoutKey, reason: '换漫画模式不该重排小说章节');
    });

    test('toMap / fromMap 往返，未知值回退默认', () {
      final ReaderStyle s =
          const ReaderStyle().copyWith(comicReadMode: ComicReadMode.paged);
      expect(ReaderStyle.fromMap(s.toMap()), s);
      expect(
        ReaderStyle.fromMap(<String, Object>{'comicReadMode': 'unknown'})
            .comicReadMode,
        ComicReadMode.vertical,
      );
    });

    test('值相等包含漫画模式', () {
      expect(const ReaderStyle(), const ReaderStyle().copyWith());
      expect(
        const ReaderStyle(),
        isNot(const ReaderStyle().copyWith(comicReadMode: ComicReadMode.paged)),
      );
    });

    test('normalized 不改动漫画模式（只管联网与动效）', () {
      final AppSettings s = const AppSettings(
        motion: false,
        reader: ReaderStyle(
            pageTurn: ReaderPageTurn.simulation,
            comicReadMode: ComicReadMode.paged),
      ).normalized();
      expect(s.reader.pageTurn, ReaderPageTurn.none);
      expect(s.reader.comicReadMode, ComicReadMode.paged);
    });
  });

  group('FavoriteRouter 收藏路由', () {
    const BookSummary book = BookSummary(
      id: 'b01',
      title: '雪国的旅行者',
      author: '川端 雪',
      spineColor: Color(0xFF4A6180),
      shelf: '最近阅读',
    );

    FavoriteEntry entry(FavoriteTarget t) => FavoriteEntry(
          bookId: 'b01',
          target: t,
          addedAt: DateTime.utc(2026, 11, 8),
        );

    test('detail / reader / excerpts 三种目标解析成强类型参数', () {
      expect(
          FavoriteRouter.resolve(entry(FavoriteTarget.detail), book)!.arguments,
          isA<DetailArgs>());
      expect(
          FavoriteRouter.resolve(entry(FavoriteTarget.reader), book)!.arguments,
          isA<ReaderArgs>());
      final FavoriteNavigation nav =
          FavoriteRouter.resolve(entry(FavoriteTarget.excerpts), book)!;
      expect(nav.route, FavoriteRouteName.excerpts);
      expect((nav.arguments as ExcerptLibraryArgs).initialBookId, 'b01');
    });

    test('routeNameFor 与 resolve 的 route 一致', () {
      for (final FavoriteTarget t in FavoriteTarget.values) {
        expect(
          FavoriteRouter.resolve(entry(t), book)!.route,
          FavoriteRouter.routeNameFor(t),
        );
      }
    });

    test('书籍不存在时返回 null，不跳空页面', () {
      expect(
          FavoriteRouter.resolve(entry(FavoriteTarget.detail), null), isNull);
    });

    test('FavoriteEntry 序列化往返与未知枚举回退', () {
      final FavoriteEntry e =
          entry(FavoriteTarget.excerpts).copyWith(note: '回头看');
      expect(FavoriteEntry.fromMap(e.toMap()), e);
      final FavoriteEntry fallback = FavoriteEntry.fromMap(<dynamic, dynamic>{
        'bookId': 'b02',
        'target': 'unknown',
      });
      expect(fallback.target, FavoriteTarget.detail);
      expect(fallback.bookId, 'b02');
    });
  });

  group('AppState 收藏与书架筛选', () {
    AppState make() => AppState(
          settingsStore: InMemorySettingsStore(),
          books: const DemoBookRepository(),
        );

    test('演示收藏 2 条，按添加时间倒序', () {
      final AppState s = make();
      expect(s.favoriteCount, 2);
      expect(s.favorites.first.bookId, 'b01');
      expect(s.favorites.last.bookId, 'b04');
      expect(s.isFavorite('b01'), isTrue);
      expect(s.isFavorite('b09'), isFalse);
      expect(() => s.favorites.add(s.favorites.first), throwsUnsupportedError);
    });

    test('toggle 加入 / 取消，且不会重复收藏同一本', () {
      final AppState s = make();
      expect(s.toggleFavorite('b09'), isTrue);
      expect(s.toggleFavorite('b09'), isFalse);
      expect(s.favoriteCount, 2);
      expect(s.addFavorite('b09'), isTrue);
      expect(s.addFavorite('b09'), isFalse);
      expect(s.favoriteCount, 3);
    });

    test('setFavoriteTarget 改跳转目标，removeFavorite 幂等', () {
      final AppState s = make();
      s.setFavoriteTarget('b01', FavoriteTarget.excerpts);
      expect(s.targetFor('b01'), FavoriteTarget.excerpts);
      expect(s.removeFavorite('b01'), isTrue);
      expect(s.removeFavorite('b01'), isFalse);
      expect(s.targetFor('b01'), isNull);
    });

    test('library(favoritesOnly) 只返回收藏书，且套用元数据覆盖层', () {
      final AppState s = make();
      final List<BookSummary> all = s.library();
      final List<BookSummary> fav = s.library(favoritesOnly: true);
      expect(all.length, 11);
      expect(fav.map((BookSummary b) => b.id).toSet(), <String>{'b01', 'b04'});
      s.updateBook('b01', title: '改过名字的书');
      expect(s.library(favoritesOnly: true).first.title, '改过名字的书');
    });

    test('收藏清空后 emptyKind 报 noFavorites，不误报书库为空', () {
      final AppState s = make();
      s.removeFavorite('b01');
      s.removeFavorite('b04');
      final int matched = s.library(favoritesOnly: true).length;
      expect(matched, 0);
      expect(
        s.emptyKind(matched: matched, query: '', favoritesOnly: true),
        LibraryEmptyKind.noFavorites,
      );
      expect(
        LibraryQuery.emptyKind(
            total: 11,
            matched: 0,
            query: '',
            favoritesOnly: true,
            favoriteCount: 0),
        LibraryEmptyKind.noFavorites,
      );
      expect(
        LibraryQuery.emptyKind(
            total: 11,
            matched: 0,
            query: '',
            favoritesOnly: true,
            favoriteCount: 2),
        LibraryEmptyKind.noLibrary,
      );
    });

    test('BookSummary.isComic 只认漫画格式，PDF 不算漫画', () {
      expect(const DemoBookRepository().byId('b11')!.isComic, isTrue);
      expect(
          const BookSummary(
            id: 'p',
            title: 'p',
            author: 'a',
            spineColor: Color(0xFF000000),
            shelf: 's',
            format: 'PDF',
          ).isComic,
          isFalse);
      final BookDocument comic = DemoDocumentFactory.from(
        const DemoBookRepository().byId('b11')!,
      );
      expect(comic.isComic, isTrue);
      expect(comic.chapters, isEmpty);
      expect(comic.comicPageCount, 10);
      expect(comic.requiresNativeRender, isTrue);
    });
  });
}

String? headerLabelFor(ComicToc toc, int page) => toc.headerForPage(page);
