import 'package:flutter/material.dart';

import '../feature/shelf/mine_page.dart';
import '../feature/shelf/shelf_page.dart';
import '../l10n/lr_localizations.dart';
import '../core/ui/components/glass/Nav.dart';
import 'app_navigation.dart';
import 'tab_pages.dart';

/// 四 tab 外壳（E23）：轻小说文库 / 收藏 / 书架 / 我的。
/// 「发现」WenkuPage 退役；统计、书签、设置、关于、赞助仍从「我的」进入。
/// IndexedStack 保活，避免切换时立体书架的抽出状态被重建。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  List<GlassNavItem> get _items => <GlassNavItem>[
        GlassNavItem(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore,
            label: lrText('uiWenkuLibrary')),
        GlassNavItem(
            icon: Icons.favorite_border,
            activeIcon: Icons.favorite,
            label: lrText('uiFavorites')),
        GlassNavItem(
            icon: Icons.auto_stories_outlined,
            activeIcon: Icons.auto_stories,
            label: lrText('uiShelf')),
        GlassNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: lrText('uiProfile')),
      ];

  @override
  Widget build(BuildContext context) {
    final AppNavigation nav = AppNavigationScope.of(context);
    final List<Widget> pages = <Widget>[
      buildWenkuLibraryPage(context),
      buildFavoritesPage(context),
      ShelfPage(
        onOpenBook: nav.onOpenBook,
        onOpenSearch: nav.onOpenSearch,
        onImport: nav.onImport,
        onOpenReadingHistory: nav.onOpenReadingHistory,
      ),
      MinePage(
        onOpenWenku8Login: nav.onOpenWenku8Login,
        onOpenStats: nav.onOpenStats,
        onOpenBookmarks: nav.onOpenBookmarks,
        onOpenSettings: nav.onOpenSettings,
        onOpenAbout: nav.onOpenAbout,
        onOpenSupport: nav.onOpenSupport,
      ),
    ];

    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            scheme.surface,
            scheme.surfaceVariant.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Scaffold(
        // 底层渐变由 AppShell 提供；这里保持透明，四个 tab 共用同一张背景。
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: GlassNavBar(
          items: _items,
          currentIndex: _index,
          onTap: (int i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
