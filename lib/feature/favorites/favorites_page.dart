
import 'package:Local_reader/core/model/navigation_spec.dart';
import 'package:Local_reader/core/ui/components/glass/Page.dart';
import 'package:Local_reader/feature/favorites/favorites_components.dart';
import 'package:flutter/material.dart';



/// 收藏页：HeaderNav（右侧小说 / 漫画分类图标）
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({
    super.key,
    required this.continueReading,
    required this.recentReads,
    required this.favorites,
    required this.recentLimit,
    required this.kind,
    required this.onKindChanged,
    required this.onOpen,
    this.onGoCollect,
  });

  final List<RailItem> continueReading;
  final List<RailItem> recentReads;
  final List<RailItem> favorites;
  final int recentLimit;
  final BookKind kind;
  final ValueChanged<BookKind> onKindChanged;
  final ValueChanged<RailItem> onOpen;
  final VoidCallback? onGoCollect;

  List<RailItem> _ofKind(List<RailItem> src) =>
      src.where((RailItem i) => i.kind == kind).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<RailItem> cont = _ofKind(continueReading)
      ..sort((RailItem a, RailItem b) => b.updatedAt.compareTo(a.updatedAt));
    final List<RailItem> recent =
        _ofKind(recentReads).take(recentLimit).toList(growable: false);
    final List<RailItem> fav = _ofKind(favorites);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LrPage.slivers(
        // ── 顶部：吸顶 + 毛玻璃；categoryIcons 改成两个 HeaderAction ──
        header: PageScrollHeader(
          title: '收藏',
          subtitle: '03/FAVORITY',
          actions: <HeaderAction>[
            HeaderAction(
              icon: Icons.menu_book_outlined,
              tooltip: '小说',
              active: kind == BookKind.novel,
              onTap: () => onKindChanged(BookKind.novel),
            ),
            HeaderAction(
              icon: Icons.photo_library_outlined,
              tooltip: '漫画',
              active: kind == BookKind.comic,
              onTap: () => onKindChanged(BookKind.comic),
            ),
          ],
        ),
        // ── 其余内容：三个 rail 原封不动 ──
        rawSlivers: <Widget>[
          SliverToBoxAdapter(
            child: RailSection(
              title: '继续阅读',
              items: cont,
              onOpen: onOpen,
              emptyHint: '还没有在读的书',
            ),
          ),
          SliverToBoxAdapter(
            child: RailSection(
              title: '最近阅读',
              trailing:
                  Text('最近 $recentLimit 条', style: theme.textTheme.labelSmall),
              items: recent,
              onOpen: onOpen,
              emptyHint: '最近还没有阅读记录',
            ),
          ),
          SliverToBoxAdapter(
            child: RailSection(
              title: '我的收藏',
              items: fav,
              onOpen: onOpen,
              emptyHint: '还没有收藏，去轻小说文库看看',
              onEmptyAction: onGoCollect,
              emptyActionLabel: '去收藏',
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}