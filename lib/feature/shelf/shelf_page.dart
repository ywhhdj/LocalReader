import 'package:Local_reader/core/ui/components/glass/Page.dart';
import 'package:flutter/material.dart' hide Page;

import '../../assembly/app_navigation.dart';
import '../../assembly/app_scope.dart';
import '../../assembly/route_args.dart';
import '../../core/common/design_tokens.dart';
import '../../core/model/book_identity.dart';
import '../../core/model/fixtures/demo_document.dart';
import '../../core/model/library_scope.dart';
import '../../core/ui/components/book/book_cover_card.dart';
import '../../core/ui/components/glass/Nav.dart';
import '../../core/ui/components/shelf_toolbar.dart';
import '../../domain/repositories/book_repository.dart';
import '../../domain/usecases/library_query.dart';
import '../../l10n/lr_localizations.dart';
import 'cloud_shelf_view.dart';

/// 书籍类型过滤器
enum _BookTypeFilter { all, novel, comic }

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
  String? _sourceId;

  // 筛选与排序状态
  bool _favoritesOnly = false;
  LibrarySort _sort = LibrarySort.recent;
  _BookTypeFilter _typeFilter = _BookTypeFilter.all;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    // 回调一律有兜底
    final AppNavigation nav = AppNavigationScope.of(context);
    final OpenBookDetail openBook = widget.onOpenBook ?? nav.onOpenBook;
    final OpenSearchPage openSearch = widget.onOpenSearch ?? nav.onOpenSearch;
    final ShowImport showImport = widget.onImport ?? nav.onImport;
    final VoidCallback openHistory =
        widget.onOpenReadingHistory ?? nav.onOpenReadingHistory;

    // 统一获取全部图书（依赖底层的 LibrarySort 来实现“最近阅读”置顶）
    final List<BookSummary> allBooks = state.library(
      query: '',
      favoritesOnly: _favoritesOnly,
      sort: _sort,
    );

    // 基于类型进行前端过滤
    List<BookSummary> displayedBooks = allBooks;
    if (_typeFilter == _BookTypeFilter.novel) {
      displayedBooks =
          allBooks.where((BookSummary b) => !b.isComic).toList(growable: false);
    } else if (_typeFilter == _BookTypeFilter.comic) {
      displayedBooks =
          allBooks.where((BookSummary b) => b.isComic).toList(growable: false);
    }

    int columns = 2;
    if (_layout == ShelfLayout.list) columns = 1;
    if (_layout == ShelfLayout.grid3) columns = 3;

    return LrPage.slivers(
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
                onTap: openHistory,
              ),
              if (_scope == LibraryScope.local)
                HeaderAction(
                  icon: Icons.add_to_photos_outlined,
                  tooltip: context.t('shelfImportTip'),
                  onTap: showImport,
                ),
              HeaderAction(
                icon: Icons.search_outlined,
                tooltip: context.t('shelfSearchTip'),
                onTap: () => openSearch(''),
              ),
            ],
          ),
          const SizedBox(height: LrSpacing.m),
          // 工具栏：去掉了分类下拉框，筛选按钮替换为弹窗触发
          ShelfToolbar(
            scope: _scope,
            localLabel: context.t('wenkuShelfTabLocal'),
            cloudLabel: context.t('wenkuShelfTabCloud'),
            onScopeChanged: (LibraryScope v) => setState(() {
              _scope = v;
              _favoritesOnly = false;
            }),
            categoryLabel: '', // 移除内置分类下拉框
            categoryOptions: const <CategoryOption>[],
            selectedCategoryId: '',
            onCategoryChanged: (String v) {},
            layoutLabel: context.t('shelfLayoutTip'),
            onLayoutPressed: _cycleLayout,
            filterLabel: context.t('shelfFilterTip'),
            // 如果开启了任意筛选则点亮图标
            filterActive: _favoritesOnly || _typeFilter != _BookTypeFilter.all,
            onFilterPressed: () => _showFilterSheet(context),
            sources: const <CategoryOption>[],
            selectedSourceId: _sourceId,
            onSourceChanged: (String? v) => setState(() => _sourceId = v),
          ),
        ],
      ),
      rawSlivers: <Widget>[
        if (_scope == LibraryScope.cloud)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: LrSpacing.l),
            sliver: SliverFillRemaining(
              hasScrollBody: true,
              child: CloudShelfView(
                onImport: showImport,
                onOpenBook: openBook,
                onGoCollect: () => openSearch(''),
                categoryId: 'all',
                gridColumns: columns,
              ),
            ),
          )
        else if (displayedBooks.isEmpty)
          // 全局空状态
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: LrSpacing.l),
            sliver: SliverToBoxAdapter(
              child: GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _favoritesOnly
                          ? context.t('favoriteEmptyTitle')
                          : context.t('noResultTitle'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: LrSpacing.xs),
                    Text(
                      _favoritesOnly
                          ? context.t('favoriteEmptyBody')
                          : context.t('noResultBody'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: LrSpacing.xs),
                    TextButton(
                      onPressed: _favoritesOnly
                          ? () => setState(() => _favoritesOnly = false)
                          : showImport,
                      child: Text(_favoritesOnly
                          ? context.t('uiViewAllBooks')
                          : context.t('uiHowImportingWorks')),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          // 扁平化的全部图书列表/宫格
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: LrSpacing.l),
            sliver: SliverToBoxAdapter(
              child: _BookCollection(
                books: displayedBooks,
                layout: _layout,
                onOpen: openBook,
                onMore: (BookSummary b) =>
                    _openBookActions(context, state, b, openBook),
                coverBook: coverBookOf,
              ),
            ),
          ),
      ],
    );
  }

  void _cycleLayout() => setState(() {
        _layout = _layout == ShelfLayout.list
            ? ShelfLayout.grid2
            : (_layout == ShelfLayout.grid2
                ? ShelfLayout.grid3
                : ShelfLayout.list);
      });

  /// 底部上拉的筛选与排序面板
  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true, // 顶部的小横条提示可以下拉
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    LrSpacing.l, 0, LrSpacing.l, LrSpacing.l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 排序
                    Text('排序', style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: LrSpacing.xs,
                      children: <Widget>[
                        for (final LibrarySort s in LibrarySort.values)
                          ChoiceChip(
                            label: Text(LibraryQuery.sortLabels[s]!),
                            selected: _sort == s,
                            onSelected: (bool v) {
                              if (v) {
                                setSheetState(() => _sort = s);
                                setState(() {}); // 更新外层 UI
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: LrSpacing.l),

                    // 类型
                    Text('类型', style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: LrSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('全部'),
                          selected: _typeFilter == _BookTypeFilter.all,
                          onSelected: (bool v) {
                            if (v) {
                              setSheetState(
                                  () => _typeFilter = _BookTypeFilter.all);
                              setState(() {});
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('小说'),
                          selected: _typeFilter == _BookTypeFilter.novel,
                          onSelected: (bool v) {
                            if (v) {
                              setSheetState(
                                  () => _typeFilter = _BookTypeFilter.novel);
                              setState(() {});
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('漫画'),
                          selected: _typeFilter == _BookTypeFilter.comic,
                          onSelected: (bool v) {
                            if (v) {
                              setSheetState(
                                  () => _typeFilter = _BookTypeFilter.comic);
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: LrSpacing.l),

                    // 只看收藏
                    SwitchListTile(
                      title: const Text('只看收藏'),
                      contentPadding: EdgeInsets.zero,
                      value: _favoritesOnly,
                      onChanged: (bool v) {
                        setSheetState(() => _favoritesOnly = v);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: LrSpacing.m),

                    // 确认按钮
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('完成'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openBookActions(
    BuildContext context,
    AppState state,
    BookSummary book,
    OpenBookDetail openBook,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(LrSpacing.m),
              child: Text(
                book.title,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.of(ctx).pop();
                openBook(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: Text(state.isFavorite(book.id) ? '取消收藏' : '加入收藏'),
              onTap: () {
                final bool added = state.toggleFavorite(book.id);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(added ? '已加入收藏' : '已取消收藏')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('重置阅读进度'),
              onTap: () {
                state.resetProgress(book.id);
                Navigator.of(ctx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('阅读进度已重置')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('移出书架'),
              onTap: () {
                final bool ok = state.removeBook(book.id);
                Navigator.of(ctx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? '已移出书架' : '这本书不在可移出的书库中'),
                  ),
                );
              },
            ),
            const SizedBox(height: LrSpacing.s),
          ],
        ),
      ),
    );
  }
}

/// 把 BookSummary 映射成卡片投影
CoverBook coverBookOf(BookSummary b) {
  final bool cloud = BookIdentity.isCloudId(b.id);
  final int total = DemoDocumentFactory.chapterTitles.length;
  final int current = DemoDocumentFactory.resumeChapter(b) + 1;
  return CoverBook(
    id: b.id,
    title: b.title,
    author: b.author.isEmpty ? '未知作者' : b.author,
    subtitle: BookIdentity.sourceSubtitle(
        cloud ? BookOrigin.cloud : BookOrigin.local),
    coverColor: b.spineColor,
    progress: b.progress,
    type: b.isComic ? CoverBookType.comic : CoverBookType.novel,
    origin: cloud ? CoverBookOrigin.cloud : CoverBookOrigin.local,
    progressText: '$current/$total',
  );
}

/// 扁平化渲染的全部图书集合
class _BookCollection extends StatelessWidget {
  const _BookCollection({
    required this.books,
    required this.layout,
    required this.onOpen,
    required this.onMore,
    required this.coverBook,
  });

  final List<BookSummary> books;
  final ShelfLayout layout;
  final OpenBookDetail onOpen;
  final ValueChanged<BookSummary> onMore;
  final CoverBook Function(BookSummary) coverBook;

  int get _columns =>
      layout == ShelfLayout.grid3 ? 3 : (layout == ShelfLayout.grid2 ? 2 : 1);

  Widget _card(BookSummary b) => BookCoverCard(
        book: coverBook(b),
        display:
            layout == ShelfLayout.list ? CoverDisplay.list : CoverDisplay.grid,
        onClick: () => onOpen(b),
        onMore: () => onMore(b),
        onLongPress: () => onMore(b),
      );

  @override
  Widget build(BuildContext context) {
    if (layout == ShelfLayout.list) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[for (final BookSummary b in books) _card(b)],
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: _columns == 3 ? 0.46 : 0.53,
      ),
      itemCount: books.length,
      itemBuilder: (BuildContext context, int i) => _card(books[i]),
    );
  }
}
