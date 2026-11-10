import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'domain/repositories/book_repository.dart';
import 'domain/usecases/favorite_routes.dart';
import 'domain/usecases/import_session.dart';
import 'assembly/route_args.dart';
import 'assembly/app_scope.dart';
import 'core/model/app_settings.dart';
import 'core/model/stats/keepsake_kind.dart';
import 'data/wenku/wenku8_bootstrap.dart';
import 'domain/repositories/wenku8_source.dart';
import 'feature/shelf/wenku_login_sheet.dart';
import 'feature/profile/pages/localized_texts_sheet.dart';
import 'feature/reader/reader_style_sheet.dart';
import 'feature/profile/stats/widget_config_sheet.dart';
import 'l10n/lr_localizations.dart';
import 'core/ui/components/import_dialog.dart';
import 'core/ui/theme/glass_theme.dart';
import 'core/ui/theme/performance_scope.dart';
import 'core/model/performance_prefs.dart';
import 'assembly/app_navigation.dart';
import 'assembly/app_router.dart';
import 'assembly/app_services.dart';
import 'assembly/app_shell.dart';

class LocalReaderApp extends StatefulWidget {
  const LocalReaderApp({super.key});

  @override
  State<LocalReaderApp> createState() => _LocalReaderAppState();
}

class _LocalReaderAppState extends State<LocalReaderApp> {
  // 第二十三轮解锁：Wenku8 默认注入真实数据源；纯本地锁定态仍零请求。
  // 第二十九轮：云端缓存由同一装配层产生，设置页 / 关于页读同一实例。
  late final Wenku8Source _wenku8Source = Wenku8Bootstrap.build();

  late final AppState _state = AppState(
    settingsStore: InMemorySettingsStore(),
    books: const DemoBookRepository(),
    wenku8Source: _wenku8Source,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_state.bootstrap());
  }

  @override
  void dispose() {
    Wenku8Bootstrap.dispose(_wenku8Source);
    _state.dispose();
    super.dispose();
  }

  /// 导入向导的唯一跳转口：书架、文库、我的页、导入弹窗共用。
  void _openImportWizard(BuildContext context,
      {ImportStep step = ImportStep.intro}) {
    Navigator.of(context).pushNamed<void>(
      AppRoutes.importWizard,
      arguments: ImportWizardArgs(initialStep: step),
    );
  }

  /// 快速说明弹窗 + 向导入口，回调由 app 层注入，core 弹窗不构造路由。
  void _showImport(BuildContext context) {
    unawaited(showImportDialog(
      context,
      onOpenWizard: () => _openImportWizard(context),
    ));
  }

  AppNavigation _navigation(BuildContext context) {
    void openStats() => Navigator.of(context).pushNamed<void>(
          AppRoutes.stats,
          arguments: const MineSectionArgs(MineSection.stats),
        );
    void openBookmarks() => Navigator.of(context).pushNamed<void>(
          AppRoutes.bookmarks,
          arguments: const MineSectionArgs(MineSection.bookmarks),
        );
    void openSettings() => Navigator.of(context).pushNamed<void>(
          AppRoutes.settings,
          arguments: const MineSectionArgs(MineSection.settings),
        );
    void openAbout() => Navigator.of(context).pushNamed<void>(
          AppRoutes.about,
          arguments: const MineSectionArgs(MineSection.about),
        );
    void openSupport() => Navigator.of(context).pushNamed<void>(
          AppRoutes.support,
          arguments: const MineSectionArgs(MineSection.support),
        );

    return AppNavigation(
      onOpenBook: (BookSummary book) {
        Navigator.of(context).pushNamed<void>(
          AppRoutes.detail,
          arguments: DetailArgs(book: book),
        );
      },
      onOpenSearch: (String query) {
        Navigator.of(context).pushNamed<void>(
          AppRoutes.search,
          arguments: SearchArgs(initialQuery: query),
        );
      },
      onImport: () => _showImport(context),
      onOpenReadingHistory: openStats,
      onOpenReaderStyle: () => unawaited(ReaderStyleSheet.open(context)),
      onOpenFavorite: (FavoriteNavigation nav) {
        final Object args = nav.arguments;
        switch (nav.route) {
          case FavoriteRouteName.detail:
            if (args is DetailArgs) {
              Navigator.of(context).pushNamed<void>(AppRoutes.detail, arguments: args);
            }
            break;
          case FavoriteRouteName.reader:
            if (args is ReaderArgs) {
              Navigator.of(context).pushNamed<void>(AppRoutes.reader, arguments: args);
            }
            break;
          case FavoriteRouteName.excerpts:
            if (args is ExcerptLibraryArgs) {
              Navigator.of(context).pushNamed<void>(AppRoutes.excerpts, arguments: args);
            }
            break;
        }
      },
      onOpenImportWizard: () => _openImportWizard(context),
      onOpenLocalizedTexts: () => unawaited(showLocalizedTextsSheet(context)),
      onOpenFeatureMatrix: () => Navigator.of(context).pushNamed<void>(
            AppRoutes.featureMatrix,
            arguments: const FeatureMatrixArgs(),
          ),
      onOpenWenku8Login: () => unawaited(Wenku8LoginSheet.open(context)),
      onOpenStats: openStats,
      onOpenBookmarks: openBookmarks,
      onOpenSettings: openSettings,
      onOpenAbout: openAbout,
      onOpenSupport: openSupport,
      onResume: (BookSummary book, int chapter) {
        Navigator.of(context).pushNamed<void>(
          AppRoutes.reader,
          arguments: ReaderArgs(book: book, chapterIndex: chapter),
        );
      },
      onOpenWidgetConfig: () => unawaited(WidgetConfigSheet.open(
        context,
        // 小组件预览「查看本月纪念物」→ 纪念物册，带上本月 monthKey。
        onOpenKeepsakeMonth: (String monthKey) {
          Navigator.of(context).pushNamed<void>(
            AppRoutes.keepsakes,
            arguments: KeepsakeLibraryArgs.fromCard(null, monthKey),
          );
        },
      )),
      onOpenCalendarMonth: (int year, int month) {
        Navigator.of(context).pushNamed<void>(
          AppRoutes.calendarMonth,
          arguments: CalendarMonthArgs(year: year, month: month),
        );
      },
      // 统计页卡片 → 纪念物册：带上当前类型 / 月份筛选，不在册子里重置回全部。
      onOpenKeepsakeLibrary: (KeepsakeKind? kind, String? monthKey) {
        Navigator.of(context).pushNamed<void>(
          AppRoutes.keepsakes,
          arguments: KeepsakeLibraryArgs.fromCard(kind, monthKey),
        );
      },
      onOpenKeepsakeMonth: (String monthKey) {
        Navigator.of(context).pushNamed<void>(
          AppRoutes.keepsakes,
          arguments: KeepsakeLibraryArgs.fromCard(null, monthKey),
        );
      },
      onOpenExcerptLibrary: (String query, String? bookId) {
        Navigator.of(context).pushNamed<void>(
          AppRoutes.excerpts,
          arguments: ExcerptLibraryArgs.forQuery(query, bookId: bookId),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppNavigation nav = _navigation(context);
    AppRoutes.bind(nav);
    return AppNavigationScope(
      navigation: nav,
      child: AppServices(
        wenku8Cache: Wenku8Bootstrap.cacheFor(_wenku8Source),
        child: AppScope(
          state: _state,
          child: AnimatedBuilder(
            animation: _state,
            // AppShell 是不随 state 变化的常量子树：走 AnimatedBuilder.child
            // 复用同一个 widget 实例，避免每次通知都重新分配并 diff 整棵外壳。
            child: const AppShell(),
            builder: (BuildContext context, Widget? shell) => PerformanceScope(
              budget: PerformanceBudget.resolve(
                _state.settings.performance,
                _state.settings.motion,
              ),
              child: MaterialApp(
                // 官方文档：title 与 onGenerateTitle 二选一，这里用后者做本地化标题。
                onGenerateTitle: (BuildContext ctx) => ctx.t('appTitle'),
                debugShowCheckedModeBanner: false,
                // 框架侧交给 flutter_localizations，应用侧文案交给自定义 delegate。
                locale: _state.appLocale,
                localizationsDelegates: <LocalizationsDelegate<dynamic>>[
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  const LrLocalizationsDelegate(),
                ],
                supportedLocales: LrLocalizations.supportedLocales,
                theme: GlassTheme.light(_state.season.value),
                darkTheme: GlassTheme.dark(_state.season.value),
                themeMode: ThemeMode.system,
                onGenerateRoute: AppRoutes.onGenerateRoute,
                home: shell,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
