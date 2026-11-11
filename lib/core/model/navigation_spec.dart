// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖
// 合并状态 E13：已落入工程路径 lib/core/model/navigation_spec.dart；同名类型已隔离；未编译 / 未运行 / 未下载依赖。
// 设计源：scaffold/navigation_spec.dart（交付包内保留，作为规格基线）
// 建议落点：lib/core/model/navigation_spec.dart
//           （生产实现按 PLAN.md §4 拆入 app_settings.dart / shelf_prefs.dart /
//            recent_reads_prefs.dart / tts_engine_prefs.dart / route_args.dart）
// 对应需求：R1 R2 R4 R6 R9 R11 R12
// 纯 Dart，无 Flutter 依赖，便于模型级测试。

/// 底部 4 个 tab（R3 改名 + R4 新增）。
enum NavTab { wenkuLibrary, favorites, shelf, mine }

const List<NavTab> kAppNavTabs = <NavTab>[
  NavTab.wenkuLibrary,
  NavTab.favorites,
  NavTab.shelf,
  NavTab.mine,
];

/// 云端书架布局：列表 / 两栏 / 三栏（R1）。
enum ShelfGridMode { list, grid2, grid3 }

int columnsOf(ShelfGridMode mode) {
  switch (mode) {
    case ShelfGridMode.list:
      return 1;
    case ShelfGridMode.grid2:
      return 2;
    case ShelfGridMode.grid3:
      return 3;
  }
}

/// 主题（R11）。followSystem 时由 MaterialApp 的 ThemeMode.system 解析。
enum ThemePref { followSystem, dark, light }

/// 界面语言（R11）。
enum AppLanguagePref { followSystem, zh, en }

/// 搜索范围与来源（R12）。
enum SearchScope { all, title, author, tag, id }

enum SearchOrigin { shelf, wenku }

/// 书籍大类（R4 顶部右侧分类图标）。
enum BookKind { novel, comic }

/// 收藏页三条垂直分区（R4）。
enum FavoritesSection { continueReading, recentReads, myFavorites }

/// 统计页底部 Dock（R8）。
enum StatsDockView { overview, charts, books, marks, touch }

/// 设置分组（R9）。
enum SettingsSection { appearance, performance, widgets, dataStorage }

/// 全应用默认值（唯一裁决点，生产里并入 AppSettings.normalized()）。
class AppDefaults {
  const AppDefaults._();

  /// R1：默认开启网络（改造前 dev 是 pureLocal=true / onlineDirectory=false）。
  static const bool pureLocal = false;
  static const bool onlineDirectory = true;

  /// R4：最近阅读只记录最近 10 条。
  static const int recentReadsLimit = 10;
  static const int recentReadsMin = 1;
  static const int recentReadsMax = 50;

  /// R1：云端默认宫格两栏。
  static const ShelfGridMode shelfGridMode = ShelfGridMode.grid2;

  /// R6：漫画默认竖直、页直接拼接。
  static const bool comicVerticalByDefault = true;

  /// R7：预取窗口口径。
  static const int comicWindowPages = 4;
  static const int novelChapterRadius = 1;

  static const ThemePref theme = ThemePref.followSystem;
  static const AppLanguagePref language = AppLanguagePref.followSystem;
  static const String headerNavClassName = 'HeaderNav';
}

/// 最近阅读条数偏好（R4）：上限唯一裁决点，页面不自己写「保留 10 条」。
// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class RecentReadsPrefs {
  const RecentReadsPrefs({this.limit = AppDefaults.recentReadsLimit});

  final int limit;

  RecentReadsPrefs normalized() => RecentReadsPrefs(
        limit: limit < AppDefaults.recentReadsMin
            ? AppDefaults.recentReadsMin
            : (limit > AppDefaults.recentReadsMax
                ? AppDefaults.recentReadsMax
                : limit),
      );

  List<T> trim<T>(List<T> items) =>
      items.length <= normalized().limit
          ? items
          : items.sublist(0, normalized().limit);

  @override
  bool operator ==(Object other) =>
      other is RecentReadsPrefs && other.normalized().limit == normalized().limit;

  @override
  int get hashCode => normalized().limit.hashCode;
}

/// 导航与布局快照：集中所有「设了没反应」类陷阱的归一化。
// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class NavigationSpec {
  const NavigationSpec({
    this.tabs = kAppNavTabs,
    this.pureLocal = AppDefaults.pureLocal,
    this.onlineDirectory = AppDefaults.onlineDirectory,
    this.gridMode = AppDefaults.shelfGridMode,
    this.gridEnabled = true,
    this.comicVertical = AppDefaults.comicVerticalByDefault,
    this.theme = AppDefaults.theme,
    this.language = AppDefaults.language,
    this.headerNavClassName = AppDefaults.headerNavClassName,
  });

  final List<NavTab> tabs;
  final bool pureLocal;
  final bool onlineDirectory;
  final ShelfGridMode gridMode;
  final bool gridEnabled;
  final bool comicVertical;
  final ThemePref theme;
  final AppLanguagePref language;
  final String headerNavClassName;

  bool get onlineEnabled => !pureLocal && onlineDirectory;

  /// 归一化：纯本地总开关仍强制清零联网项；非宫格模式把列数锁回默认；
  /// 竖直漫画锁回单页 / 左→右（沿用 dev AppSettings.normalized 的口径）。
  NavigationSpec normalized() => NavigationSpec(
        tabs: tabs,
        pureLocal: pureLocal,
        onlineDirectory: pureLocal ? false : onlineDirectory,
        gridMode: gridEnabled ? gridMode : ShelfGridMode.list,
        gridEnabled: gridEnabled,
        comicVertical: comicVertical,
        theme: theme,
        language: language,
        headerNavClassName: headerNavClassName,
      );

  @override
  bool operator ==(Object other) =>
      other is NavigationSpec &&
      other.onlineEnabled == onlineEnabled &&
      other.gridMode == gridMode &&
      other.comicVertical == comicVertical &&
      other.headerNavClassName == headerNavClassName;

  @override
  int get hashCode => Object.hash(onlineEnabled, gridMode, comicVertical);
}
