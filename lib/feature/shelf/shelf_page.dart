import 'dart:ui';

import 'package:Local_reader/core/ui/components/glass/Page.dart';
import 'package:flutter/material.dart' hide Page;

import '../../domain/repositories/book_repository.dart';
import '../../core/model/library_scope.dart';
import '../../assembly/route_args.dart';
import '../../assembly/app_scope.dart';
import '../../l10n/lr_localizations.dart';
import '../../core/ui/components/glass/Nav.dart';
import '../../core/ui/components/book/book_cover_card.dart';
import '../../core/ui/components/shelf_toolbar.dart';
import '../../core/common/design_tokens.dart';
import 'cloud_shelf_view.dart';

/// 书架页 本地与云端统一为「图片 + 描述」封面卡宫格。
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
  ShelfLayout _layout = ShelfLayout.grid2;
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
      // ── 顶部：标题头 + 工具栏，一起吸顶 ──
      header: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PageScrollHeader(
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
          const SizedBox(height: LrSpacing.m),
          ShelfToolbar(
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
        ],
      ),
      // ── body：其余内容，正常滚动 ──
      rawSlivers: <Widget>[
        if (_scope == LibraryScope.cloud)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: LrSpacing.l),
            sliver: SliverFillRemaining(
              hasScrollBody: true,
              child: CloudShelfView(
                onImport: _onImport,
                categoryId: _categoryId,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: LrSpacing.l),
            sliver: SliverList(
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
          ),
      ],
    );
  }

  List<BookSummary> _localBooks(AppState state, String shelf) {
    final String category =
        _categoryId == ShelfCategories.allId ? '' : _categoryId;
    return state.library(
      query: '',
      shelf: category.isEmpty ? shelf : category,
      favoritesOnly: _favoritesOnly,
    );
  }

  void _cycleLayout() => setState(() {
        _layout = _layout == ShelfLayout.list
            ? ShelfLayout.grid2
            : (_layout == ShelfLayout.grid2
                ? ShelfLayout.grid3
                : ShelfLayout.list);
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
              const SizedBox(width: LrSpacing.xs),
              Text(context.tArgs('uiTotalBooksVolumeOrder', <Object?>[total]),
                  style: text.labelSmall),
              const SizedBox(width: LrSpacing.xs),
              Expanded(
                  child: Divider(color: Theme.of(context).dividerTheme.color)),
            ],
          ),
          const SizedBox(height: LrSpacing.m),
          if (books.isEmpty)
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                      favoritesOnly
                          ? context.t('favoriteEmptyTitle')
                          : context.t('noResultTitle'),
                      style: text.titleMedium),
                  const SizedBox(height: LrSpacing.xs),
                  Text(
                      favoritesOnly
                          ? context.t('favoriteEmptyBody')
                          : context.t('noResultBody'),
                      style: text.bodySmall),
                  const SizedBox(height: LrSpacing.xs),
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
            // 统一「图片 + 描述」封面卡宫格；三种布局共用同一份数据，不重建书脊。
            _CoverGrid(
              books: books,
              layout: layout,
              onOpen: onOpen,
            ),
        ],
      ),
    );
  }
}

/// 本地分组的封面卡宫格：列表 / 两栏 / 三栏，共用同一份 `List<BookSummary>`。
/// 卡片样式对齐用户给的 `BookCoverCard`（封面 0.7、进度条、类型角标、书名 + 作者）。
class _CoverGrid extends StatelessWidget {
  const _CoverGrid({
    required this.books,
    required this.layout,
    required this.onOpen,
  });

  final List<BookSummary> books;
  final ShelfLayout layout;
  final ValueChanged<BookSummary> onOpen;

  int get _columns =>
      layout == ShelfLayout.grid3 ? 3 : (layout == ShelfLayout.grid2 ? 2 : 1);

  @override
  Widget build(BuildContext context) {
    if (layout == ShelfLayout.list) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: books.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int i) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.menu_book_outlined, size: 18),
          title: Text(books[i].title),
          trailing: Text('${(books[i].progress * 100).round()}%'),
          onTap: () => onOpen(books[i]),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: books.length,
      itemBuilder: (BuildContext context, int i) {
        final BookSummary b = books[i];
        return BookCoverCard(
          book: CoverBook(
            id: b.id,
            title: b.title,
            author: b.author.isEmpty ? b.format : b.author,
            coverColor: b.spineColor,
            progress: b.progress,
            type: b.isComic ? CoverBookType.comic : CoverBookType.novel,
            subtitle: b.isComic ? '漫画' : '本地书籍',
          ),
          onClick: () => onOpen(b),
        );
      },
    );
  }
}
