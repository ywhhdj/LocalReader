import 'package:flutter/material.dart';

import 'package:Local_reader/assembly/app_navigation.dart';
import 'package:Local_reader/assembly/app_scope.dart';
import 'package:Local_reader/feature/favorites/favorites_components.dart'
    show RailItem;
import 'package:Local_reader/core/model/navigation_spec.dart'
    show AppDefaults, BookKind;
import 'package:Local_reader/core/model/wenku/wenku8_models.dart' show Wenku8Book;
import 'package:Local_reader/core/ui/components/book/book_cover_card.dart'
    show CoverBook;
import 'package:Local_reader/feature/favorites/favorites_page.dart'
    show FavoritesPage;
import 'package:Local_reader/feature/wenku/wenku_3d_shelf.dart'
    show ShelfRoundAction, ShelfSpineBook;
import 'package:Local_reader/feature/wenku/wenku_page.dart';
import 'package:Local_reader/feature/wenku/wenku_library_spec.dart'
    show RankKind, WenkuLibraryState, kRankingOrder;

/// 轻小说文库页
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
        author: b.author,
        subtitle: b.latestChapter,
        coverColor: b.coverColor,
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
        tint: source[i].coverColor,
      ),
  ];
  final Map<RankKind, List<CoverBook>> ranks = <RankKind, List<CoverBook>>{
    for (final RankKind k in kRankingOrder) k: cards,
  };

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
    onOpenBook: (CoverBook b) {
      // 详情跳转由装配层后续接 Wenku8DetailSheet；此处不构造路由。
    },
    onGoCollect: () => nav.onOpenSearch(''),
    onRefresh: () => state.refreshWenku8(),
    onExtract: (ShelfSpineBook b) {
      // 抽出即阅读：真实跳转需 BookSummary，留待阅读器接线。
    },
    // 截图右上三个圆按钮下沉到书架工具条；HeaderNav 右侧仍只有搜索。
    topActions: <Widget>[
      ShelfRoundAction(
        icon: Icons.history,
        tooltip: '阅读历史',
        onTap: nav.onOpenReadingHistory,
      ),
      ShelfRoundAction(
        icon: Icons.file_download_outlined,
        tooltip: '导入',
        onTap: nav.onImport,
      ),
      ShelfRoundAction(
        icon: Icons.search,
        tooltip: '搜索轻小说文库',
        onTap: () => nav.onOpenSearch(''),
      ),
    ],
  );
}

/// 收藏页
Widget buildFavoritesPage(BuildContext context) {
  final AppState state = AppScope.of(context);
  final List<RailItem> all = <RailItem>[
    for (final book in state.allBooks)
      RailItem(
        id: book.id,
        title: book.title,
        subtitle: book.format,
        author: book.author,
        coverColor: book.spineColor,
        progress: book.progress,
        kind: book.isComic ? BookKind.comic : BookKind.novel,
      ),
  ];
  return FavoritesPage(
    continueReading: all.where((RailItem i) => i.progress > 0).toList(),
    // 最近阅读只记录最近 10 条：条数由 RecentReadsPrefs.limit 裁决，页面不写死。
    recentReads: all,
    favorites: all,
    recentLimit: AppDefaults.recentReadsLimit,
    kind: BookKind.novel,
    onKindChanged: (BookKind k) {
      // 分类切换只过滤本地投影，不重新请求；真实偏好写入待接线。
    },
    onOpen: (RailItem i) {
      // 详情 / 阅读器跳转由装配层后续接线。
    },
    onGoCollect: () => AppNavigationScope.of(context).onOpenSearch(''),
  );
}
