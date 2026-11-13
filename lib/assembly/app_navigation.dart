import 'package:flutter/widgets.dart';

import '../domain/repositories/book_repository.dart';
import '../domain/usecases/favorite_routes.dart';
import '../core/model/stats/keepsake_kind.dart';

/// 导航目标由 app 层统一注入：feature 页面不构造路由、不互相 import。
/// 第二十九轮把散在 AppShell.build 里的十几个回调收成一个显式契约，
/// 我的页的五个入口与统计页的五个回调都从这里取值。
class AppNavigation {
  const AppNavigation({
    required this.onOpenBook,
    required this.onOpenSearch,
    required this.onImport,
    required this.onOpenReadingHistory,
    required this.onOpenReaderStyle,
    required this.onOpenFavorite,
    required this.onOpenImportWizard,
    required this.onOpenLocalizedTexts,
    required this.onOpenFeatureMatrix,
    required this.onOpenWenku8Login,
    required this.onOpenWebDav,
    required this.onOpenImportBooks,
    required this.onOpenStats,
    required this.onOpenBookmarks,
    required this.onOpenSettings,
    required this.onOpenAbout,
    required this.onOpenSupport,
    required this.onResume,
    required this.onOpenWidgetConfig,
    required this.onOpenCalendarMonth,
    required this.onOpenKeepsakeLibrary,
    required this.onOpenKeepsakeMonth,
    required this.onOpenExcerptLibrary,
  });

  final void Function(BookSummary book) onOpenBook;
  final void Function(String query) onOpenSearch;
  final VoidCallback onImport;
  final VoidCallback onOpenReadingHistory;
  final VoidCallback onOpenReaderStyle;
  final void Function(FavoriteNavigation nav) onOpenFavorite;
  final VoidCallback onOpenImportWizard;
  final VoidCallback onOpenLocalizedTexts;
  final VoidCallback onOpenFeatureMatrix;
  final VoidCallback onOpenWenku8Login;

  /// WebDAV 配置面板（五个真实备份动作的入口）。
  final VoidCallback onOpenWebDav;

  /// R13 导入书籍流程：此前路由已注册却没有任何入口。
  final VoidCallback onOpenImportBooks;

  /// 我的页五个「需选择才打开」的入口。
  final VoidCallback onOpenStats;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenSupport;

  /// 统计页的深链回调（统计不再是底栏 tab，但能力一行不减）。
  final void Function(BookSummary book, int chapter) onResume;
  final void Function() onOpenWidgetConfig;
  final void Function(int year, int month) onOpenCalendarMonth;
  final void Function(KeepsakeKind? kind, String? monthKey) onOpenKeepsakeLibrary;
  final void Function(String monthKey) onOpenKeepsakeMonth;
  final void Function(String query, String? bookId) onOpenExcerptLibrary;
}

/// 导航契约用 InheritedWidget 注入：AppShell 因此可以是 const，
/// AnimatedBuilder.child 的常量子树复用（二十七轮性能收口）不丢。
class AppNavigationScope extends InheritedWidget {
  const AppNavigationScope({
    super.key,
    required this.navigation,
    required super.child,
  });

  final AppNavigation navigation;

  static AppNavigation of(BuildContext context) {
    final AppNavigationScope? s =
        context.dependOnInheritedWidgetOfExactType<AppNavigationScope>();
    assert(s != null, 'AppNavigationScope 必须挂在 MaterialApp 之上');
    return s!.navigation;
  }

  @override
  bool updateShouldNotify(AppNavigationScope oldWidget) =>
      oldWidget.navigation != navigation;
}
