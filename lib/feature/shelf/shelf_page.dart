import 'package:flutter/material.dart';

import '../../domain/repositories/book_repository.dart';
import '../../core/model/library_scope.dart';
import '../../assembly/route_args.dart';
import '../../assembly/app_scope.dart';
import '../../l10n/lr_localizations.dart';
import '../../core/ui/components/book_spine.dart';
import '../../core/ui/components/glass.dart';
import '../../core/ui/components/page_scaffold.dart';
import '../../core/ui/components/page_scroll_header.dart';
import '../../core/ui/components/shelf_toolbar.dart';
import '../../core/common/design_tokens.dart';
import 'cloud_shelf_view.dart';

/// 书架页（第三十轮按用户要求重排，严格组件式）。
///
/// 顶部是**随页面滚动**的 Hero 头（左侧主标题 + 子标题，右侧阅读历史 /
/// 导入 / 搜索；导入只在本地视图出现）。下面只有一栏工具条：左侧本地 /
/// 云端范围 + 分类（云端按 Wenku8 分类，本地按自定义分组），右侧布局与筛选。
/// 再往下**只展示数据**：本地分组 3D 书架 / 云端目录，不放设置、关于、提示。
/// 所有列表走 `SliverChildBuilderDelegate` / `ListView.separated` 懒加载。
class ShelfPage extends StatefulWidget {
  const ShelfPage({
    super.key,
    this.onOpenBook,
    this.onOpenSearch,
    this.onImport,
    this.onOpenReadingHistory,
  });

  final OpenBookDetail? onOpenBook;
  final OpenSearchPage? onOpenSearch;
  final ShowImport? onImport;
  final VoidCallback? onOpenReadingHistory;

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  LibraryScope _scope = LibraryScope.local;
  ShelfLayout _layout = ShelfLayout.shelf3d;
  String _categoryId = ShelfCategories.allId;
  String? _sourceId;
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<ShelfCategory> categories =
        ShelfCategories.forScope(_scope, 'uiAllCategories');
    final List<CategoryOption> options = <CategoryOption>[
      for (final ShelfCategory c in categories)
        CategoryOption(
          id: c.id,
          label: c.labelKey == null ? c.literalLabel! : context.t(c.labelKey!),
        ),
    ];
    final List<CategoryOption> sources = <CategoryOption>[
      for (final ShelfCategory s in ShelfCategories.cloudSources())
        CategoryOption(id: s.id, label: s.literalLabel!),
    ];

    return LrPage.slivers(
      header: PageScrollHeader(
        title: context.t('shelfHeroTitle'),
        subtitle: context.t('shelfHeroSubtitle'),
        actions: <HeaderAction>[
          HeaderAction(
            icon: Icons.history_outlined,
            tooltip: context.t('shelfHistoryTip'),
            onTap: widget.onOpenReadingHistory ?? () {},
          ),
          if (_scope == LibraryScope.local)
            HeaderAction(
              icon: Icons.add_to_photos_outlined,
              tooltip: context.t('shelfImportTip'),
              onTap: _onImport,
            ),
          HeaderAction(
            icon: Icons.search_outlined,
            tooltip: context.t('shelfSearchTip'),
            onTap: _openSearchPage,
          ),
        ],
      ),
      rawSlivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: LrSpacing.m),
            child: ShelfToolbar(
              scope: _scope,
              localLabel: context.t('wenkuShelfTabLocal'),
              cloudLabel: context.t('wenkuShelfTabCloud'),
              onScopeChanged: (LibraryScope v) => setState(() {
                _scope = v;
                _categoryId = v == LibraryScope.cloud
                    ? ShelfCategories.wenku8.first.id
                    : ShelfCategories.allId;
                _favoritesOnly = false;
              }),
              categoryLabel: context.t('shelfCategoryTip'),
              categoryOptions: options,
              selectedCategoryId: _categoryId,
              onCategoryChanged: (String v) => setState(() => _categoryId = v),
              layoutLabel: context.t('shelfLayoutTip'),
              onLayoutPressed: _cycleLayout,
              filterLabel: context.t('shelfFilterTip'),
              filterActive: _favoritesOnly,
              onFilterPressed: () =>
                  setState(() => _favoritesOnly = !_favoritesOnly),
              sources: sources,
              selectedSourceId: _sourceId,
              onSourceChanged: (String v) => setState(() => _sourceId = v),
            ),
          ),
        ),
        if (_scope == LibraryScope.cloud)
          SliverFillRemaining(
            hasScrollBody: true,
            child: CloudShelfView(
              onImport: _onImport,
              categoryId: _categoryId,
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => _ShelfRow(
                title: DemoBookRepository.shelfTitles[index],
                books: _localBooks(
                  state,
                  DemoBookRepository.shelfTitles[index],
                ),
                total: _localBooks(
                  state,
                  DemoBookRepository.shelfTitles[index],
                ).length,
                layout: _layout,
                favoritesOnly: _favoritesOnly,
                onOpen: _openBook,
                onImport: _onImport,
                onClearFavorites: () =>
                    setState(() => _favoritesOnly = false),
              ),
              childCount: DemoBookRepository.shelfTitles.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
      ],
    );
  }

  List<BookSummary> _localBooks(AppState state, String shelf) {
    final String category = _categoryId == ShelfCategories.allId ? '' : _categoryId;
    return state.library(
      query: '',
      shelf: category.isEmpty ? shelf : category,
      favoritesOnly: _favoritesOnly,
    );
  }

  void _cycleLayout() => setState(() {
        _layout = _layout == ShelfLayout.shelf3d
            ? ShelfLayout.grid
            : (_layout == ShelfLayout.grid ? ShelfLayout.list : ShelfLayout.shelf3d);
      });

  void _openSearchPage() => widget.onOpenSearch?.call('');

  void _openBook(BookSummary book) => widget.onOpenBook?.call(book);

  void _onImport() => widget.onImport?.call();
}

/// 单个本地分组：横向书架本身也是 `ListView.separated`，只构建可见书脊。
class _ShelfRow extends StatelessWidget {
  const _ShelfRow({
    required this.title,
    required this.books,
    required this.total,
    required this.layout,
    required this.favoritesOnly,
    required this.onOpen,
    required this.onImport,
    required this.onClearFavorites,
  });

  final String title;
  final List<BookSummary> books;
  final int total;
  final ShelfLayout layout;
  final bool favoritesOnly;
  final ValueChanged<BookSummary> onOpen;
  final ShowImport onImport;
  final VoidCallback onClearFavorites;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LrSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(title, style: text.titleLarge),
              const SizedBox(width: LrSpacing.s),
              Text(context.tArgs('uiTotalBooksVolumeOrder', <Object?>[total]),
                  style: text.labelSmall),
              const SizedBox(width: LrSpacing.s),
              Expanded(child: Divider(color: Theme.of(context).dividerTheme.color)),
            ],
          ),
          const SizedBox(height: LrSpacing.m),
          if (books.isEmpty)
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(favoritesOnly
                      ? context.t('favoriteEmptyTitle')
                      : context.t('noResultTitle'),
                      style: text.titleMedium),
                  const SizedBox(height: LrSpacing.s),
                  Text(favoritesOnly
                      ? context.t('favoriteEmptyBody')
                      : context.t('noResultBody'),
                      style: text.bodySmall),
                  const SizedBox(height: LrSpacing.s),
                  TextButton(
                    onPressed: favoritesOnly ? onClearFavorites : onImport,
                    child: Text(favoritesOnly
                        ? context.t('uiViewAllBooks')
                        : context.t('uiHowImportingWorks')),
                  ),
                ],
              ),
            )
          else if (layout == ShelfLayout.list)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: books.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int i) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book_outlined, size: 18),
                title: Text(books[i].title, style: text.bodyMedium),
                trailing: Text('${(books[i].progress * 100).round()}%',
                    style: text.labelSmall),
                onTap: () => onOpen(books[i]),
              ),
            )
          else
            SizedBox(
              height: layout == ShelfLayout.grid ? 200 : 232,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: LrSpacing.xs),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: books.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (BuildContext context, int i) {
                  final BookSummary b = books[i];
                  return GestureDetector(
                    onTap: () => onOpen(b),
                    child: BookSpine(
                      title: b.title,
                      author: b.author,
                      spineColor: b.spineColor,
                      progress: b.progress,
                      tilt: layout == ShelfLayout.grid ? 0 : -0.13 + (i % 3) * 0.045,
                      height: layout == ShelfLayout.grid
                          ? 168
                          : 182 - (i % 3) * 8,
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: LrSpacing.s),
          ShelfBoard(
            colors: SeasonPalette.all[AppScope.of(context).season.value]!.shelfWood,
          ),
        ],
      ),
    );
  }
}
