import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/favorites/favorite_routes.dart';
import 'core/import/import_session.dart';
import 'core/content/import_dialog.dart';
import 'core/content/localized_texts_sheet.dart';
import 'core/data/book_repository.dart';
import 'core/router/app_router.dart';
import 'core/router/route_args.dart';
import 'core/state/app_scope.dart';
import 'core/state/app_settings.dart';
import 'core/stats/keepsake_kind.dart';
import 'core/theme/glass_theme.dart';
import 'core/widgets/glass.dart';
import 'core/wenku/wenku8_bootstrap.dart';
import 'core/wenku/wenku8_source.dart';
import 'features/profile/profile_page.dart';
import 'features/reader/reader_style_sheet.dart';
import 'features/shelf/shelf_page.dart';
import 'features/stats/stats_page.dart';
import 'features/stats/widget_config_sheet.dart';
import 'features/wenku/wenku_page.dart';
import 'features/wenku/wenku_login_sheet.dart';
import 'core/content/lr_localizations.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static List<GlassNavItem> get _items => <GlassNavItem>[
        GlassNavItem(
            icon: Icons.auto_stories_outlined,
            activeIcon: Icons.auto_stories,
            label: lrText('uiShelf')),
        GlassNavItem(
            icon: Icons.menu_book_outlined,
            activeIcon: Icons.menu_book,
            label: lrText('uiLightNovels')),
        GlassNavItem(
            icon: Icons.insert_chart_outlined,
            activeIcon: Icons.insert_chart,
            label: lrText('uiStats')),
        GlassNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: lrText('uiProfile')),
      ];

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

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      ShelfPage(
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
      ),
      WenkuPage(onImport: () => _showImport(context)),
      StatsPage(
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
        onOpenExcerptLibrary: (String query, String? bookId) {
          Navigator.of(context).pushNamed<void>(
            AppRoutes.excerpts,
            arguments: ExcerptLibraryArgs.forQuery(query, bookId: bookId),
          );
        },
      ),
      ProfilePage(
        onOpenReaderStyle: () => unawaited(ReaderStyleSheet.open(context)),
        onOpenImportWizard: () => _openImportWizard(context),
        onOpenLocalizedTexts: () => unawaited(showLocalizedTextsSheet(context)),
        onOpenFeatureMatrix: () => Navigator.of(context).pushNamed<void>(
          AppRoutes.featureMatrix,
          arguments: const FeatureMatrixArgs(),
        ),
        onOpenWenku8Login: () => unawaited(Wenku8LoginSheet.open(context)),
        onOpenFavorite: (FavoriteNavigation nav) {
          final Object args = nav.arguments;
          switch (nav.route) {
            case FavoriteRouteName.detail:
              if (args is DetailArgs) {
                Navigator.of(context)
                    .pushNamed<void>(AppRoutes.detail, arguments: args);
              }
              break;
            case FavoriteRouteName.reader:
              if (args is ReaderArgs) {
                Navigator.of(context)
                    .pushNamed<void>(AppRoutes.reader, arguments: args);
              }
              break;
            case FavoriteRouteName.excerpts:
              if (args is ExcerptLibraryArgs) {
                Navigator.of(context)
                    .pushNamed<void>(AppRoutes.excerpts, arguments: args);
              }
              break;
          }
        },
      ),
    ];

    return Scaffold(
      extendBody: true, // 让玻璃底栏下方的内容透出模糊背景
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: GlassNavBar(
        items: _items,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}


class LocalReaderApp extends StatefulWidget {
  const LocalReaderApp({super.key});

  @override
  State<LocalReaderApp> createState() => _LocalReaderAppState();
}

class _LocalReaderAppState extends State<LocalReaderApp> {
  late final Wenku8Source _wenku8Source = Wenku8Bootstrap.build();

  // 设置与书库仍是内存实现（持久化 ❄️ 冻结）。
  late final AppState _state = AppState(
    settingsStore: InMemorySettingsStore(),
    books: const DemoBookRepository(),
    wenku8Source: _wenku8Source,
  );

  @override
  void initState() {
    super.initState();
    // 纯 Dart 内存存储，bootstrap 无副作用；未来换持久化实现时在这里 await。
    unawaited(_state.bootstrap());
  }

  @override
  void dispose() {
    Wenku8Bootstrap.dispose(_wenku8Source);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: AnimatedBuilder(
        animation: _state,
        // AppShell 是不随 state 变化的常量子树：走 AnimatedBuilder.child
        // 复用同一个 widget 实例，避免每次通知都重新分配并 diff 整棵外壳。
        child: const AppShell(),
        builder: (BuildContext context, Widget? shell) => MaterialApp(
          onGenerateTitle: (BuildContext ctx) => 'Local Reader',
          debugShowCheckedModeBanner: false,
          // 逐页接入多语言：locale / delegates / supportedLocales 三件套。
          // 框架侧（Material / Cupertino / 文本方向）交给 flutter_localizations，
          // 应用侧 200 键文案交给自定义 LrLocalizationsDelegate。
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
    );
  }
}

