import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/detail/book_detail_page.dart';
import '../../features/detail/toc_page.dart';
import '../../features/excerpts/excerpt_library_page.dart';
import '../../features/profile/feature_matrix_page.dart';
import '../../features/stats/keepsake_library_page.dart';
import '../../features/stats/calendar_month_page.dart';
import '../../features/import/import_flow_page.dart';
import '../../features/reader/reader_page.dart';
import '../../features/shelf/search_page.dart';
import '../content/import_dialog.dart';
import '../data/book_repository.dart';
import 'route_args.dart';

/// 导航目标由 app 层统一注入，对齐原 Kotlin 工程「分层单向、feature 之间不互相依赖」。
/// 页面不构造 MaterialPageRoute，只认路由名与参数类型；跨页跳转通过回调注入。
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

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case detail:
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
              onOpenToc: (BookSummary b, int current) => Navigator.of(context).pushNamed<int>(
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

      case toc:
        final Object? args = settings.arguments;
        if (args is TocArgs) {
          return MaterialPageRoute<int>(
            settings: settings,
            builder: (_) => TocPage(book: args.book, currentChapter: args.currentChapter),
          );
        }
        return _fallback(settings, '打开目录需要 TocArgs 参数');

      case reader:
        final Object? args = settings.arguments;
        if (args is ReaderArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (BuildContext context) => ReaderPage(
              book: args.book,
              chapterIndex: args.chapterIndex,
              onOpenToc: (BookSummary b, int current) => Navigator.of(context).pushNamed<int>(
                    toc,
                    arguments: TocArgs(book: b, currentChapter: current),
                  ),
            ),
          );
        }
        return _fallback(settings, '打开阅读器需要 ReaderArgs 参数');

      case search:
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

      case excerpts:
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

      case importWizard:
        final Object? args = settings.arguments;
        if (args is ImportWizardArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ImportFlowPage(initialStep: args.initialStep),
          );
        }
        return _fallback(settings, '打开导入向导需要 ImportWizardArgs 参数');

      case calendarMonth:
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

      case keepsakes:
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

      case featureMatrix:
        final Object? args = settings.arguments;
        if (args is FeatureMatrixArgs) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => FeatureMatrixPage(initialTab: args.normalizedTab),
          );
        }
        return _fallback(settings, '打开功能总览需要 FeatureMatrixArgs 参数');

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
