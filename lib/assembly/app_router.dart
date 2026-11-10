import 'dart:async';

import 'package:Local_reader/feature/settings/settings_page.dart';
import 'package:flutter/material.dart';

import '../feature/detail/book_detail_page.dart';
import '../feature/detail/toc_page.dart';
import '../feature/profile/excerpts/excerpt_library_page.dart';
import '../feature/profile/pages/feature_matrix_page.dart';
import '../feature/profile/pages/mine_section_page.dart';
import '../feature/profile/stats/stats_page.dart';
import 'app_navigation.dart';
import '../feature/profile/stats/keepsake_library_page.dart';
import '../feature/profile/stats/calendar_month_page.dart';
import '../feature/shelf/import_flow_page.dart';
import '../feature/reader/reader_page.dart';
import '../feature/shelf/search_page.dart';
import '../core/ui/components/import_dialog.dart';
import '../domain/repositories/book_repository.dart';
import 'route_args.dart';

/// 导航目标由 app 层统一注入
class AppRoutes {
  const AppRoutes._();

  static const String detail = '/detail';
  static const String toc = '/toc';
  static const String reader = '/reader';
  static const String search = '/search';
  static const String excerpts = '/excerpts';
  static const String importWizard = '/import';
  static const String calendarMonth = '/calendar';
  static const String keepsakes = '/keepsakes';
  static const String featureMatrix = '/features';
  static const String stats = '/mine/stats';
  static const String bookmarks = '/mine/bookmarks';
  static const String settings = '/mine/settings';
  static const String about = '/mine/about';
  static const String support = '/mine/support';

  /// 装配层把导航契约交给路由表
  /// 具体跳转仍由页面的 `AppNavigationScope.of(context)` 读取，避免 core 反向依赖 app。
  static Object? _boundNavigation;
  static void bind(Object navigation) => _boundNavigation = navigation;
  static Object? get boundNavigation => _boundNavigation;

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.detail:
        final Object? args = settings.arguments;
        if (args is DetailArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) => BookDetailPage(
              book: args.book,
              onOpenReader: (BookSummary b, int chapter) {
                Navigator.of(context).pushNamed<void>(
                  reader,
                  arguments: ReaderArgs(book: b, chapterIndex: chapter),
                );
              },
              onOpenToc: (BookSummary b, int current) =>
                  Navigator.of(context).pushNamed<int>(
                toc,
                arguments: TocArgs(book: b, currentChapter: current),
              ),
              // 详情 → 摘录：与收藏 / 统计入口复用同一条 /excerpts 路由与强类型参数。
              onOpenBookExcerpts: (String bookId) {
                Navigator.of(context).pushNamed<void>(
                  excerpts,
                  arguments: ExcerptLibraryArgs.forBook(bookId),
                );
              },
            ),
          );
        }
        return _fallback(settings, '打开详情页需要 DetailArgs 参数');

      case AppRoutes.toc:
        final Object? args = settings.arguments;
        if (args is TocArgs) {
          return MaterialPageRoute<int>(
            settings: settings,
            builder: (_) =>
                TocPage(book: args.book, currentChapter: args.currentChapter),
          );
        }
        return _fallback(settings, '打开目录需要 TocArgs 参数');

      case AppRoutes.reader:
        final Object? args = settings.arguments;
        if (args is ReaderArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) => ReaderPage(
              book: args.book,
              chapterIndex: args.chapterIndex,
              onOpenToc: (BookSummary b, int current) =>
                  Navigator.of(context).pushNamed<int>(
                toc,
                arguments: TocArgs(book: b, currentChapter: current),
              ),
            ),
          );
        }
        return _fallback(settings, '打开阅读器需要 ReaderArgs 参数');

      case AppRoutes.search:
        final Object? args = settings.arguments;
        if (args is SearchArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) => SearchPage(
              initialQuery: args.initialQuery,
              onOpenBook: (BookSummary b) {
                Navigator.of(context).pushNamed<void>(
                  detail,
                  arguments: DetailArgs(book: b),
                );
              },
              onImport: () => unawaited(showImportDialog(
                context,
                onOpenWizard: () => Navigator.of(context).pushNamed<void>(
                  importWizard,
                  arguments: const ImportWizardArgs(),
                ),
              )),
            ),
          );
        }
        return _fallback(settings, '打开搜索页需要 SearchArgs 参数');

      case AppRoutes.excerpts:
        final Object? args = settings.arguments;
        if (args is ExcerptLibraryArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ExcerptLibraryPage(
              initialQuery: args.initialQuery,
              initialBookId: args.initialBookId,
              // 第二十一轮：日历「查看当天摘录」深链，按日与按书可叠加。
              initialDateKey: args.initialDateKey,
            ),
          );
        }
        return _fallback(settings, '打开摘录管理页需要 ExcerptLibraryArgs 参数');

      case AppRoutes.importWizard:
        final Object? args = settings.arguments;
        if (args is ImportWizardArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ImportFlowPage(initialStep: args.initialStep),
          );
        }
        return _fallback(settings, '打开导入向导需要 ImportWizardArgs 参数');

      case AppRoutes.calendarMonth:
        final Object? args = settings.arguments;
        if (args is CalendarMonthArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            // 第二十轮 · 日历 → 纪念物册：只把强类型 Args 交给装配层，
            // 页面不构造路由、不 import 另一个 feature。
            builder: (BuildContext ctx) => CalendarMonthPage(
              args: args,
              onOpenKeepsakeLibrary: (KeepsakeLibraryArgs a) =>
                  Navigator.of(ctx).pushNamed<void>(
                AppRoutes.keepsakes,
                arguments: a,
              ),
              // 第二十一轮：日历选中日 → 摘录管理页，只传强类型 Args。
              onOpenDayExcerpts: (ExcerptLibraryArgs a) =>
                  Navigator.of(ctx).pushNamed<void>(
                AppRoutes.excerpts,
                arguments: a,
              ),
            ),
          );
        }
        return _fallback(settings, '打开整月日历需要 CalendarMonthArgs 参数');

      case AppRoutes.keepsakes:
        final Object? args = settings.arguments;
        if (args is KeepsakeLibraryArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            // 第二十轮 · 纪念物册 → 日历：同一回调按 Args 区分「某日」与「整月」。
            builder: (BuildContext ctx) => KeepsakeLibraryPage(
              initialKind: args.initialKind,
              initialMonthKey: args.initialMonthKey,
              initialDateKey: args.initialDateKey,
              onOpenCalendarMonth: (CalendarMonthArgs a) =>
                  Navigator.of(ctx).pushNamed<void>(
                AppRoutes.calendarMonth,
                arguments: a,
              ),
            ),
          );
        }
        return _fallback(settings, '打开纪念物册需要 KeepsakeLibraryArgs 参数');

      case AppRoutes.featureMatrix:
        final Object? args = settings.arguments;
        if (args is FeatureMatrixArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => FeatureMatrixPage(initialTab: args.normalizedTab),
          );
        }
        return _fallback(settings, '打开功能总览需要 FeatureMatrixArgs 参数');

      case AppRoutes.stats:
        final Object? args = settings.arguments;
        if (args is MineSectionArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) {
              final AppNavigation nav = AppNavigationScope.of(context);
              return MineSectionPage(
                args: args,
                statsBuilder: (BuildContext _) => StatsPage(
                  onResume: nav.onResume,
                  onOpenWidgetConfig: nav.onOpenWidgetConfig,
                  onOpenExcerptLibrary: nav.onOpenExcerptLibrary,
                  onOpenCalendarMonth: nav.onOpenCalendarMonth,
                  onOpenKeepsakeLibrary: nav.onOpenKeepsakeLibrary,
                ),
                settingsBuilder: (_) => const SettingsPage(),
              );
            },
          );
        }
        return _fallback(settings, '打开统计需要 MineSectionArgs 参数');

      case AppRoutes.bookmarks:
      case AppRoutes.settings:
      case AppRoutes.about:
      case AppRoutes.support:
        final Object? sectionArgs = settings.arguments;
        if (sectionArgs is MineSectionArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (BuildContext ctx) => MineSectionPage(
              args: sectionArgs,
              statsBuilder: (_) => StatsPage(
                onResume: AppNavigationScope.of(ctx).onResume,
                onOpenWidgetConfig:
                    AppNavigationScope.of(ctx).onOpenWidgetConfig,
                onOpenExcerptLibrary:
                    AppNavigationScope.of(ctx).onOpenExcerptLibrary,
                onOpenCalendarMonth:
                    AppNavigationScope.of(ctx).onOpenCalendarMonth,
                onOpenKeepsakeLibrary:
                    AppNavigationScope.of(ctx).onOpenKeepsakeLibrary,
              ),
              settingsBuilder: (_) => const SettingsPage(),
            ),
          );
        }
        return _fallback(settings, '打开我的子页需要 MineSectionArgs 参数');

      default:
        return null;
    }
  }

  static Route<dynamic> _fallback(RouteSettings settings, String message) =>
      MaterialPageRoute<void>(
        settings: settings,
        builder: (BuildContext context) => Scaffold(
          appBar: AppBar(title: const Text('无法打开页面')),
          body: Center(child: Text(message)),
        ),
      );
}
