import 'package:flutter/material.dart';

import '../feature/shelf/mine_page.dart';
import '../feature/shelf/shelf_page.dart';
import '../l10n/lr_localizations.dart';
import '../core/ui/components/glass.dart';
import 'app_navigation.dart';

/// 三 tab 外壳（第二十九轮）：发现 / 书架 / 我的。
/// 统计、书签、设置、关于、赞助与反馈不再占底栏，改成「我的」里点选才打开。
/// 用 IndexedStack 保活，避免切换时 3D 书架透视状态被重建。
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
            label: lrText('uiDiscover')),
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
    //   DiscoverPage(onImport: nav.onImport),
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

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: GlassNavBar(
        items: _items,
        currentIndex: _index,
        onTap: (int i) => setState(() => _index = i),
      ),
    );
  }
}
