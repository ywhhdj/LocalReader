import 'package:Local_reader/core/model/navigation_spec.dart'
    show SearchScope, SearchOrigin, BookKind, StatsDockView, FavoritesSection;

enum AppRoute {
  wenkuLibrary,
  favorites,
  shelf,
  mine,
  search,
  stats,
  settings,
  appearance,
  performance,
  widgets,
  dataStorage,
  cacheManage,
  backup,
  ttsEngine,
  bookDetail,
  reader,
}

const Map<AppRoute, String> kRoutePaths = <AppRoute, String>{
  AppRoute.wenkuLibrary: '/wenkuLibrary',
  AppRoute.favorites: '/favorites',
  AppRoute.shelf: '/shelf',
  AppRoute.mine: '/mine',
  AppRoute.search: '/search',
  AppRoute.stats: '/stats',
  AppRoute.settings: '/settings',
  AppRoute.appearance: '/settings/appearance',
  AppRoute.performance: '/settings/performance',
  AppRoute.widgets: '/settings/widgets',
  AppRoute.dataStorage: '/settings/dataStorage',
  AppRoute.cacheManage: '/settings/dataStorage/cache',
  AppRoute.backup: '/settings/dataStorage/backup',
  AppRoute.ttsEngine: '/settings/appearance/ttsEngine',
  AppRoute.bookDetail: '/bookDetail',
  AppRoute.reader: '/reader',
};

const List<AppRoute> kBottomTabs = <AppRoute>[
  AppRoute.wenkuLibrary, // 原名「发现」，改为「轻小说文库」
  AppRoute.favorites, // 新增 tab
  AppRoute.shelf,
  AppRoute.mine,
];

/// 搜索页入参：三处入口靠 origin 区分口径（docs/03 §3.9）。
class SearchSpecArgs {
  const SearchSpecArgs({
    this.initialQuery = '',
    this.scope = SearchScope.all,
    this.origin = SearchOrigin.shelf,
  });

  final String initialQuery;
  final SearchScope scope;
  final SearchOrigin origin;

  bool get isShelfSearch => origin == SearchOrigin.shelf;
  bool get isWenkuSearch => origin == SearchOrigin.wenku;
}

class FavoritesSpecArgs {
  const FavoritesSpecArgs({
    this.section = FavoritesSection.continueReading,
    this.kind = BookKind.novel,
  });

  final FavoritesSection section;
  final BookKind kind;
}

class StatsDockSpecArgs {
  const StatsDockSpecArgs({this.view = StatsDockView.overview, this.rangeDays = 30});

  final StatsDockView view;
  final int rangeDays;
}

class BookDetailSpecArgs {
  const BookDetailSpecArgs({required this.bookId, required this.isCloud});
  final String bookId;
  final bool isCloud;
}

class ReaderSpecArgs {
  const ReaderSpecArgs({required this.bookId, this.chapterIndex = 0});
  final String bookId;
  final int chapterIndex;
}

/// onGenerateRoute 的守卫结果：每个新路由都必须有 `args is` 校验，
/// 不允许页面自己 pushNamed、也不允许 feature 之间互相 import。
class RouteGuardResult {
  const RouteGuardResult(this.ok, {this.reason = ''});

  final bool ok;
  final String reason;
}

RouteGuardResult validateRoute(AppRoute route, Object? args) {
  switch (route) {
    case AppRoute.search:
      return args is SearchSpecArgs
          ? const RouteGuardResult(true)
          : const RouteGuardResult(false, reason: 'SearchSpecArgs required');
    case AppRoute.favorites:
      return args is FavoritesSpecArgs
          ? const RouteGuardResult(true)
          : const RouteGuardResult(false, reason: 'FavoritesSpecArgs required');
    case AppRoute.stats:
      return args is StatsDockSpecArgs
          ? const RouteGuardResult(true)
          : const RouteGuardResult(false, reason: 'StatsDockSpecArgs required');
    case AppRoute.bookDetail:
      return args is BookDetailSpecArgs
          ? const RouteGuardResult(true)
          : const RouteGuardResult(false, reason: 'BookDetailSpecArgs required');
    case AppRoute.reader:
      return args is ReaderSpecArgs
          ? const RouteGuardResult(true)
          : const RouteGuardResult(false, reason: 'ReaderSpecArgs required');
    case AppRoute.wenkuLibrary:
    case AppRoute.shelf:
    case AppRoute.mine:
    case AppRoute.settings:
    case AppRoute.appearance:
    case AppRoute.performance:
    case AppRoute.widgets:
    case AppRoute.dataStorage:
    case AppRoute.cacheManage:
    case AppRoute.backup:
    case AppRoute.ttsEngine:
      return const RouteGuardResult(true);
  }
}

/// 三处搜索入口的路由装配（页面只调用 AppNavigation，不构造路径）。
SearchSpecArgs searchArgsFor(AppRoute entry) {
  switch (entry) {
    case AppRoute.shelf:
      // 书架搜索 = 本地 + 云端两源
      return const SearchSpecArgs(origin: SearchOrigin.shelf);
    case AppRoute.wenkuLibrary:
      // 轻小说文库右上搜索 = 只查文库
      return const SearchSpecArgs(origin: SearchOrigin.wenku);
    default:
      return const SearchSpecArgs(origin: SearchOrigin.shelf);
  }
}
