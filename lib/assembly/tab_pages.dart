import 'package:Local_reader/core/ui/components/CircleIconButton.dart';
import 'package:flutter/material.dart';

import 'app_navigation.dart';
import 'app_scope.dart';
import '../core/model/book_identity.dart';
import '../core/model/fixtures/demo_document.dart';
import '../core/model/navigation_spec.dart' show AppDefaults, BookKind;
import '../core/model/wenku/wenku8_models.dart' show Wenku8Book;
import '../core/ui/components/book/book_cover_card.dart'
    show CoverBook, CoverBookOrigin;
import '../domain/repositories/book_repository.dart' show BookSummary;
import '../domain/usecases/cloud_book_projection.dart';
import '../feature/favorites/favorites_components.dart' show RailItem;
import '../feature/favorites/favorites_page.dart' show FavoritesPage;
import '../feature/wenku/wenku_3d_shelf.dart'
    show  ShelfSpineBook;
import '../feature/wenku/wenku_library_spec.dart'
    show RankKind, WenkuLibraryState, kRankingOrder;
import '../feature/wenku/wenku_page.dart';

/// 轻小说文库页：卡片、书脊、榜单、推荐全部走同一套云端投影，
/// 点击后进入与本地书共用的 /detail 页面。
Widget buildWenkuLibraryPage(BuildContext context) {
  final AppState state = AppScope.of(context);
  final AppNavigation nav = AppNavigationScope.of(context);
  final List<Wenku8Book> source =
      state.wenku8Listing?.books ?? const <Wenku8Book>[];

  final List<CoverBook> cards = <CoverBook>[
    for (final Wenku8Book b in source)
      CoverBook(
        id: b.id,
        title: b.title,
        author: b.author.isEmpty ? '未知作者' : b.author,
        subtitle: b.latestChapter,
        coverColor: b.coverColor,
        origin: CoverBookOrigin.cloud,
        progressText: '共 ${b.volumeCount} 卷',
      ),
  ];
  final List<ShelfSpineBook> spines = <ShelfSpineBook>[
    for (int i = 0; i < source.length; i++)
      ShelfSpineBook(
        id: source[i].id,
        title: source[i].title,
        author: source[i].author,
        number: '0${i + 1}',
        code: '${i + 1}',
        sourceBadge: '云端',
        origin: CoverBookOrigin.cloud,
        tint: source[i].coverColor,
      ),
  ];
  final Map<RankKind, List<CoverBook>> ranks = <RankKind, List<CoverBook>>{
    for (final RankKind k in kRankingOrder) k: cards,
  };

  void openById(String id) {
    final BookSummary? book = cloudSummaryFor(source, id);
    if (book != null) {
      nav.onOpenBook(book);
    } else {
      // 目录里没有这本书时仍给出明确反馈，不做「点了没反应」。
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('《$id》暂时没有可打开的目录信息')),
      );
    }
  }

  return WenkuLibraryPage(
    state: WenkuLibraryState(
      empty: cards.isEmpty,
      // 「本站正式关闭」类提示页只是非书目，不推断停服、不触发 offline。
      noticeSeen: false,
    ),
    shelfBooks: spines,
    rankBooks: ranks,
    recommended: cards.take(8).toList(),
    onSearch: () => nav.onOpenSearch(''),
    onOpenBook: (CoverBook b) => openById(b.id),
    onGoCollect: () => nav.onOpenSearch(''),
    onRefresh: () => state.refreshWenku8(),
    onExtract: (ShelfSpineBook b) => openById(b.id),
    // 右上角三个圆按钮：历史 / 导入 / 搜索，全部接真实导航。
    topActions: <Widget>[
      CircleIconButton(
        icon: Icons.history,
        tooltip: '阅读历史',
        onPressed: nav.onOpenReadingHistory,
      ),
      CircleIconButton(
        icon: Icons.file_download_outlined,
        tooltip: '导入',
        onPressed: nav.onImport,
      ),
      CircleIconButton(
        icon: Icons.search,
        tooltip: '搜索轻小说文库',
        onPressed: () => nav.onOpenSearch(''),
      ),
    ],
  );
}

/// 收藏页：分类切换写入全局状态，条目点击打开统一详情页。
Widget buildFavoritesPage(BuildContext context) {
  final AppState state = AppScope.of(context);
  final AppNavigation nav = AppNavigationScope.of(context);
  final List<Wenku8Book> cloud =
      state.wenku8Listing?.books ?? const <Wenku8Book>[];
  final List<RailItem> all = <RailItem>[
    for (final BookSummary book in state.allBooks)
      RailItem(
        id: book.id,
        title: book.title,
        subtitle: book.format,
        author: book.author,
        coverColor: book.spineColor,
        progress: book.progress,
        kind: book.isComic ? BookKind.comic : BookKind.novel,
        origin: BookIdentity.isCloudId(book.id)
            ? CoverBookOrigin.cloud
            : CoverBookOrigin.local,
        progressText:
            '${DemoDocumentFactory.resumeChapter(book) + 1}/${DemoDocumentFactory.chapterTitles.length}',
      ),
  ];
  return FavoritesPage(
    continueReading:
        all.where((RailItem i) => i.progress > 0).toList(growable: false),
    // 最近阅读只记录最近 N 条：条数由 AppDefaults.recentReadsLimit 裁决。
    recentReads: all,
    favorites: all,
    recentLimit: AppDefaults.recentReadsLimit,
    kind: state.favoritesKind,
    onKindChanged: state.setFavoritesKind,
    onOpen: (RailItem i) {
      final BookSummary? local = state.resolveBook(i.id);
      if (local != null) {
        nav.onOpenBook(local);
        return;
      }
      final BookSummary? remote = cloudSummaryFor(cloud, i.id);
      if (remote != null) {
        nav.onOpenBook(remote);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('这本书已不在书库中')),
        );
      }
    },
    onGoCollect: () => nav.onOpenSearch(''),
  );
}
