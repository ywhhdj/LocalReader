import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'domain/repositories/book_repository.dart';
import 'domain/usecases/favorite_routes.dart';
import 'domain/usecases/import_session.dart';
import 'crash_guard.dart';
import 'data/platform/persistence.dart';
import 'data/platform/platform_bridges.dart';
import 'data/platform/sqlite_runtime.dart';
import 'data/storage/sqlite_progress_store.dart';
import 'feature/profile/pages/webdav_config_sheet.dart';
import 'assembly/route_args.dart';
import 'assembly/app_scope.dart';
import 'core/model/app_settings.dart';
import 'core/model/stats/keepsake_kind.dart';
import 'data/wenku/wenku8_bootstrap.dart';
import 'domain/repositories/wenku8_source.dart';
import 'feature/shelf/wenku_login_sheet.dart';
import 'feature/profile/pages/localized_texts_sheet.dart';
import 'feature/reader/reader/reader_style_sheet.dart';
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
  late final Wenku8Source _wenku8Source = Wenku8Bootstrap.build();

  /// app 层的导航回调在 `LocalReaderApp.build` 里创建，那个 context 位于
  /// MaterialApp **之上**，不包含 Navigator。直接 `Navigator.of(context)`
  /// / `showModalBottomSheet(context)` 会抛
  /// "Navigator operation requested with a context that does not include a Navigator"，
  /// 导致书架 / 我的 / 统计等入口点了全部失效。
  ///
  /// 统一挂一个 navigatorKey：build 阶段 key 还没挂载，但回调真正执行时
  /// （用户点击）一定已挂载，此时再取 state / context 即可。
  final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  void _push(String route, [Object? arguments]) {
    final NavigatorState? nav = _navigatorKey.currentState;
    if (nav == null) return;
    unawaited(nav.pushNamed<void>(route, arguments: arguments));
  }

  void _withNavContext(void Function(BuildContext ctx) body) {
    final BuildContext? ctx = _navigatorKey.currentContext;
    if (ctx != null) body(ctx);
  }

  /// SQLite 是**可选能力**：这里只拿门控 executor，默认不创建原生通道、
  /// 不跑迁移。用户代码 `SqliteRuntime.instance.setEnabled(true)` 才初始化。
  late final SqlExecutor _database = SqliteRuntime.instance.executor;
  late final PlatformTtsEvents _ttsEvents = PlatformTtsEvents();

  late final AppState _state = AppState(
    settingsStore: SqlSettingsStore(SqliteRuntime.instance.prefs),
    books: const DemoBookRepository(),
    wenku8Source: _wenku8Source,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  /// 启动顺序：**不做** SQLite 迁移、不查库。
  ///
  /// SQLite 属于可选初始化，只有用户代码调用
  /// `SqliteRuntime.instance.setEnabled(true)` 才会建表 + 预热一次。
  /// `_state.bootstrap()` 读的是门控 executor 的
  /// app_prefs 内存镜像，因此这里 0 次平台通道调用。
  Future<void> _boot() async {
    await _state.bootstrap();
    if (!mounted) return;
    // 连续崩溃进入安全模式：只保留最小可读路径，跳过设备探测 / 小组件刷新等可选初始化。
    if (CrashGuard.safeModeActive) return;
    try {
      final DeviceCapability detected =
          await const PlatformDeviceBridge().detectCapability();
      if (!mounted || detected.tier == DeviceTier.unknown) return;
      _state.updateSettings(
        _state.settings.copyWith(
          performance: _state.settings.performance.copyWith(device: detected),
        ),
      );
    } catch (_) {
      // 设备探测失败保持 unknown，不影响首屏。
    }
  }

  @override
  void dispose() {
    _ttsEvents.dispose();
    Wenku8Bootstrap.dispose(_wenku8Source);
    _state.dispose();
    super.dispose();
  }

  /// 导入向导的唯一跳转口：书架、文库、我的页、导入弹窗共用。
  void _openImportWizard({ImportStep step = ImportStep.intro}) {
    _push(AppRoutes.importWizard, ImportWizardArgs(initialStep: step));
  }

  /// 快速说明弹窗 + 向导入口，回调由 app 层注入，core 弹窗不构造路由。
  void _showImport() => _withNavContext((BuildContext ctx) {
        unawaited(showImportDialog(
          ctx,
          onOpenWizard: () => _openImportWizard(),
        ));
      });

  /// core 模型不依赖 Flutter：明暗枚举在这里唯一一次映射成 ThemeMode。
  static ThemeMode _resolveThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  /// 所有跳转与弹窗都延迟到回调执行时取 [_navigatorKey] 的 state / context，
  /// 绝不使用 `build` 传进来的、位于 MaterialApp 之上的 context。
  AppNavigation _navigation() {
    void openStats() => _push(
          AppRoutes.stats,
          const MineSectionArgs(MineSection.stats),
        );
    void openBookmarks() => _push(
          AppRoutes.bookmarks,
          const MineSectionArgs(MineSection.bookmarks),
        );
    void openSettings() => _push(
          AppRoutes.settings,
          const MineSectionArgs(MineSection.settings),
        );
    void openAbout() => _push(
          AppRoutes.about,
          const MineSectionArgs(MineSection.about),
        );
    void openSupport() => _push(
          AppRoutes.support,
          const MineSectionArgs(MineSection.support),
        );

    void openWebDav() =>
        _withNavContext((BuildContext ctx) => unawaited(WebDavSheet.open(ctx)));

    void openImportBooks() =>
        _push(AppRoutes.importBooks, const ImportBooksArgs());

    return AppNavigation(
      onOpenBook: (BookSummary book) {
        // 最近观看优先：书架 / 搜索 / 收藏下一次 build 就把它排到最前。
        _state.markAsRead(book.id);
        _push(AppRoutes.detail, DetailArgs(book: book));
      },
      onOpenSearch: (String query) =>
          _push(AppRoutes.search, SearchArgs(initialQuery: query)),
      onImport: _showImport,
      onOpenReadingHistory: openStats,
      onOpenReaderStyle: () => _withNavContext(
          (BuildContext ctx) => unawaited(ReaderStyleSheet.open(ctx))),
      onOpenFavorite: (FavoriteNavigation nav) {
        final Object args = nav.arguments;
        switch (nav.route) {
          case FavoriteRouteName.detail:
            if (args is DetailArgs) _push(AppRoutes.detail, args);
            break;
          case FavoriteRouteName.reader:
            if (args is ReaderArgs) _push(AppRoutes.reader, args);
            break;
          case FavoriteRouteName.excerpts:
            if (args is ExcerptLibraryArgs) _push(AppRoutes.excerpts, args);
            break;
        }
      },
      onOpenImportWizard: () => _openImportWizard(),
      onOpenLocalizedTexts: () => _withNavContext(
          (BuildContext ctx) => unawaited(showLocalizedTextsSheet(ctx))),
      onOpenFeatureMatrix: () =>
          _push(AppRoutes.featureMatrix, const FeatureMatrixArgs()),
      onOpenWenku8Login: () => _withNavContext(
          (BuildContext ctx) => unawaited(Wenku8LoginSheet.open(ctx))),
      onOpenWebDav: openWebDav,
      onOpenImportBooks: openImportBooks,
      onOpenStats: openStats,
      onOpenBookmarks: openBookmarks,
      onOpenSettings: openSettings,
      onOpenAbout: openAbout,
      onOpenSupport: openSupport,
      onResume: (BookSummary book, int chapter) {
        _state.markAsRead(book.id);
        _push(AppRoutes.reader, ReaderArgs(book: book, chapterIndex: chapter));
      },
      onOpenWidgetConfig: () => _withNavContext((BuildContext ctx) {
        unawaited(WidgetConfigSheet.open(
          ctx,
          // 小组件预览「查看本月纪念物」→ 纪念物册，带上本月 monthKey。
          onOpenKeepsakeMonth: (String monthKey) => _push(
                AppRoutes.keepsakes,
                KeepsakeLibraryArgs.fromCard(null, monthKey),
              ),
        ));
      }),
      onOpenCalendarMonth: (int year, int month) => _push(
            AppRoutes.calendarMonth,
            CalendarMonthArgs(year: year, month: month),
          ),
      // 统计页卡片 → 纪念物册：带上当前类型 / 月份筛选，不在册子里重置回全部。
      onOpenKeepsakeLibrary: (KeepsakeKind? kind, String? monthKey) => _push(
            AppRoutes.keepsakes,
            KeepsakeLibraryArgs.fromCard(kind, monthKey),
          ),
      onOpenKeepsakeMonth: (String monthKey) => _push(
            AppRoutes.keepsakes,
            KeepsakeLibraryArgs.fromCard(null, monthKey),
          ),
      onOpenExcerptLibrary: (String query, String? bookId) => _push(
            AppRoutes.excerpts,
            ExcerptLibraryArgs.forQuery(query, bookId: bookId),
          ),
    );
  }

  String _lastWidgetFingerprint = '';

  /// 小组件推送的唯一出口：只在配置真的变化时下发，避免每次 build 都跨通道。
  void _syncWidgetSpecs(BuildContext context) {
    if (CrashGuard.safeModeActive) return;
    final List<String> ids = <String>[
      for (final s in _state.widgetSpecs) s.id,
    ];
    final String fingerprint = '${ids.length}:${ids.join(',')}';
    if (fingerprint == _lastWidgetFingerprint) return;
    _lastWidgetFingerprint = fingerprint;
    final sync = AppServices.of(context).widgetSync;
    if (ids.isEmpty) {
      unawaited(sync.remove('localreader_widgets'));
      return;
    }
    unawaited(sync.push('localreader_widgets', <String, Object?>{
      'count': ids.length,
      'ids': ids,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  @override
  Widget build(BuildContext context) {
    final AppNavigation nav = _navigation();
    AppRoutes.bind(nav);
    return AppNavigationScope(
      navigation: nav,
      child: AppServices(
        database: _database,
        prefs: SqliteRuntime.instance.prefs,
        ttsEvents: _ttsEvents,
        wenku8Cache: Wenku8Bootstrap.cacheFor(_wenku8Source),
        child: AppScope(
          state: _state,
          child: AnimatedBuilder(
            animation: _state,
            child: const AppShell(),
            builder: (BuildContext context, Widget? shell) => PerformanceScope(
              budget: PerformanceBudget.resolve(
                _state.settings.performance,
                _state.settings.motion,
              ),
              child: MaterialApp(
                // app 层所有跳转都通过这个 key，不再依赖 build 的 context。
                navigatorKey: _navigatorKey,
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
                themeMode: _resolveThemeMode(_state.settings.themeMode),
                // 所有路由（含 push 出来的详情 / 搜索 / 我的子页）共用一张主题底色，
                // 页面里的透明 Scaffold 不再露出黑底或空白。
                builder: (BuildContext context, Widget? child) {
                  // 小组件配置（增 / 删 / 改 / 重置）此前只改内存态，桌面卡片永远不刷新。
                  // 这里按内容指纹做幂等推送，重建不会重复跨 channel。
                  _syncWidgetSpecs(context);
                  return _AppBackground(child: child);
                },
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

/// 全局主题底色：随 ThemeMode 与季节色板一起重建，浅色 / 暗色都有明确背景。
/// 四 tab 的透明 Scaffold、独立路由页、弹窗背后共用这一张渐变。
class _AppBackground extends StatelessWidget {
  const _AppBackground({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            scheme.surface,
            Color.lerp(scheme.surface, scheme.surfaceVariant, 0.55)!,
          ],
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
