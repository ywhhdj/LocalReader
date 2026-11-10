import 'package:flutter/material.dart';

import '../../core/data/book_repository.dart';
import '../../core/data/library_query.dart';
import '../../core/router/route_args.dart';
import '../../core/state/app_scope.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/book_spine.dart';
import '../../core/widgets/glass.dart';
import 'cloud_shelf_view.dart';
import '../../core/content/lr_localizations.dart';

/// 立体书架：数据来自 AppScope 注入的 BookRepository，季节样式来自全局 AppState。
/// 页面自身只保留「搜索词」这一个局部 UI 状态。
class ShelfPage extends StatefulWidget {
  const ShelfPage({
    super.key,
    this.onOpenBook,
    this.onOpenSearch,
    this.onImport,
  });

  /// 由 AppShell 注入：点书脊进详情页，页面自己不构造路由。
  final OpenBookDetail? onOpenBook;

  /// 独立搜索结果页入口，带上书架里已输入的关键词。
  final OpenSearchPage? onOpenSearch;

  /// 空状态「了解如何导入」入口，与搜索页共用 core 层弹窗。
  final ShowImport? onImport;

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

/// 书架页的两个视图（第二十二轮）。局部 UI 状态，不写回 AppSettings。
enum _ShelfView { local, cloud }

class _ShelfPageState extends State<ShelfPage> {
  _ShelfView _view = _ShelfView.local;
  String _query = '';
  bool _favoritesOnly = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final SeasonPalette palette = SeasonPalette.all[state.season.value]!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final TextTheme text = Theme.of(context).textTheme;
    final BookRepository repo = state.books;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? <Color>[const Color(0xFF15171C), const Color(0xFF1D2027)]
              : <Color>[
                  palette.seed,
                  Color.lerp(palette.seed, Colors.white, 0.55)!
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  LrSpacing.l, LrSpacing.m, LrSpacing.l, LrSpacing.xs),
              child: _viewSwitch(context, text),
            ),
            Expanded(
              child: _view == _ShelfView.cloud
                  ? CloudShelfView(onImport: _onImport)
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(LrSpacing.l,
                                LrSpacing.xl, LrSpacing.l, LrSpacing.m),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(context.t('uiShelf2'),
                                    style: text.displayMedium),
                                const SizedBox(height: LrSpacing.xs),
                                Text(
                                    context.t(
                                        'uiKeepWhatYouWantToReadWithinReach'),
                                    style: text.bodyMedium),
                                const SizedBox(height: LrSpacing.s),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      context.tArgs(
                                              'uiTotalBooksBooks', <Object?>[
                                            repo.cached.length,
                                            state.favoriteCount
                                          ]) +
                                          context.tArgs(
                                              'uiItemsgroupVolumeOrder',
                                              <Object?>[
                                                state.shelfCounts().length
                                              ]),
                                      style: text.labelSmall,
                                    ),
                                    const Spacer(),
                                    _SeasonButton(
                                      label: palette.label,
                                      onTap: () => _pickSeason(context),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: LrSpacing.l),
                            child: GlassPanel(
                              borderRadius: LrRadius.pill,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: LrSpacing.m,
                                  vertical: LrSpacing.xs),
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.search,
                                      size: 19, color: text.bodySmall?.color),
                                  const SizedBox(width: LrSpacing.s),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (String v) =>
                                          setState(() => _query = v.trim()),
                                      decoration: InputDecoration(
                                        isCollapsed: true,
                                        border: InputBorder.none,
                                        hintText:
                                            context.t('uiSearchTitleAuthor'),
                                        hintStyle: text.bodyMedium,
                                      ),
                                      style: text.bodyMedium,
                                    ),
                                  ),
                                  const SizedBox(width: LrSpacing.s),
                                  Tooltip(
                                    message: context.t('uiViewAllResults'),
                                    child: GestureDetector(
                                      onTap: _openSearchPage,
                                      child: Icon(Icons.arrow_forward_rounded,
                                          size: 19,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                    ),
                                  ),
                                  const SizedBox(width: LrSpacing.s),
                                  GestureDetector(
                                    onTap: _onImport,
                                    child: Icon(Icons.add_to_photos_outlined,
                                        size: 19,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                LrSpacing.l, LrSpacing.m, LrSpacing.l, 0),
                            child: Row(
                              children: <Widget>[
                                FilterChip(
                                  avatar: Icon(Icons.star_border,
                                      size: 16,
                                      color: _favoritesOnly
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null),
                                  label: Text(context.t('favoritesOnlyHint')),
                                  selected: _favoritesOnly,
                                  onSelected: (bool v) =>
                                      setState(() => _favoritesOnly = v),
                                ),
                                const SizedBox(width: LrSpacing.s),
                                Text(
                                  _favoritesOnly
                                      ? context.tArgs('uiBooks3',
                                          <Object?>[state.favoriteCount])
                                      : context.t(
                                          'uiTapTheStarOnTheDetailOrReaderPageToFavorite'),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: LrSpacing.xl)),
                        ...List<Widget>.generate(
                            DemoBookRepository.shelfTitles.length, (int i) {
                          final String shelf =
                              DemoBookRepository.shelfTitles[i];
                          final List<BookSummary> books = state.library(
                              query: _query,
                              shelf: shelf,
                              favoritesOnly: _favoritesOnly);
                          final int shelfTotal = state
                              .library(
                                  shelf: shelf, favoritesOnly: _favoritesOnly)
                              .length;
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(bottom: LrSpacing.xl),
                              child: _ShelfRow(
                                title: shelf,
                                total: shelfTotal,
                                books: books,
                                query: _query,
                                emptyKind: state.emptyKind(
                                  matched: state
                                      .library(
                                          query: _query,
                                          favoritesOnly: _favoritesOnly)
                                      .length,
                                  query: _query,
                                  favoritesOnly: _favoritesOnly,
                                ),
                                palette: palette,
                                onOpen: _openBook,
                                onImport: _onImport,
                                onClearQuery: _clearQuery,
                                onClearFavorites: () =>
                                    setState(() => _favoritesOnly = false),
                              ),
                            ),
                          );
                        }),
                        // 给玻璃底栏留出透出空间
                        const SliverToBoxAdapter(child: SizedBox(height: 120)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 本地 / 云端分段控件。云端侧只列来源（Wenku8 / 本地导入），不列自定义书源。
  Widget _viewSwitch(BuildContext context, TextTheme text) => GlassPanel(
        borderRadius: LrRadius.pill,
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final _ShelfView v in _ShelfView.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _view = v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: LrSpacing.m, vertical: LrSpacing.xs),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(LrRadius.pill),
                      color: _view == v
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.14)
                          : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          v == _ShelfView.local
                              ? Icons.library_books_outlined
                              : Icons.cloud_outlined,
                          size: 16,
                        ),
                        const SizedBox(width: LrSpacing.xs),
                        Text(
                          v == _ShelfView.local
                              ? lrText('wenkuShelfTabLocal')
                              : lrText('wenkuShelfTabCloud'),
                          style: text.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  /// 必须与输入框文本同步，否则点了「清空关键词」列表恢复了、框里还留着旧词。
  void _clearQuery() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// 搜索与排序统一走 AppState.library()（内含元数据覆盖层 + LibraryQuery），
  /// 页面不再自己写一遍筛选，避免与搜索结果页口径不一致。
  void _openSearchPage() {
    final OpenSearchPage? open = widget.onOpenSearch;
    if (open == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lrText('uiSearchNavigationIsNotWiredIntoThisPage'))));
      return;
    }
    open(_query);
  }

  void _openBook(BookSummary book) {
    final OpenBookDetail? open = widget.onOpenBook;
    if (open == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lrText('uiDetailNavigationIsNotWiredIntoThisPage'))));
      return;
    }
    // 导航目标由 app 层统一注入，feature 之间不互相依赖。
    open(book);
  }

  void _onImport() {
    // TODO(静态冻结): 接 SafController.pickDirectory()；届时把这里换成真实 SAF 流程，
    // 共享弹窗保留为「格式与权限说明」，不需要各页再写一份文案。
    final ShowImport? show = widget.onImport;
    if (show == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lrText('uiImportEntryIsNotWiredIntoThisPage'))));
      return;
    }
    show();
  }

  Future<void> _pickSeason(BuildContext context) async {
    final AppState state = AppScope.of(context);
    final SeasonStyle? picked = await showModalBottomSheet<SeasonStyle>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => GlassPanel(
        padding: const EdgeInsets.fromLTRB(
            LrSpacing.l, LrSpacing.l, LrSpacing.l, LrSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(context.t('uiVisualStyle'),
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: LrSpacing.m),
            ...SeasonStyle.values.map<Widget>((SeasonStyle s) {
              final SeasonPalette p = SeasonPalette.all[s]!;
              return ListTile(
                leading: CircleAvatar(backgroundColor: p.accent, radius: 12),
                title: Text(p.label,
                    style: Theme.of(context).textTheme.titleMedium),
                trailing: s == state.season.value
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.pop(ctx, s),
              );
            }),
          ],
        ),
      ),
    );
    if (picked != null) state.setSeason(picked);
  }
}

class _SeasonButton extends StatelessWidget {
  const _SeasonButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        borderRadius: LrRadius.pill,
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.m, vertical: LrSpacing.s),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.palette_outlined, size: 15),
            const SizedBox(width: LrSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({
    required this.title,
    required this.total,
    required this.books,
    required this.query,
    required this.emptyKind,
    required this.palette,
    required this.onOpen,
    required this.onImport,
    required this.onClearQuery,
    required this.onClearFavorites,
  });

  final String title;
  final int total;
  final List<BookSummary> books;
  final String query;
  final LibraryEmptyKind emptyKind;
  final SeasonPalette palette;
  final ValueChanged<BookSummary> onOpen;
  final ShowImport onImport;
  final VoidCallback onClearQuery;
  final VoidCallback onClearFavorites;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LrSpacing.l),
          child: Row(
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: LrSpacing.s),
              Text(context.tArgs('uiTotalBooksVolumeOrder', <Object?>[total]),
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: LrSpacing.s),
              Expanded(
                  child: Divider(color: Theme.of(context).dividerTheme.color)),
            ],
          ),
        ),
        const SizedBox(height: LrSpacing.m),
        if (books.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: LrSpacing.l, vertical: LrSpacing.s),
            child: _EmptyShelfCard(
              kind: emptyKind,
              query: query,
              onImport: onImport,
              onClearQuery: onClearQuery,
              onClearFavorites: onClearFavorites,
            ),
          )
        else
          SizedBox(
            height: 232,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: LrSpacing.l),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int i) {
                final BookSummary b = books[i];
                final double tilt = -0.13 + (i % 3) * 0.045;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    BookSpine(
                      title: b.title,
                      author: b.author,
                      spineColor: b.spineColor,
                      progress: b.progress,
                      tilt: tilt,
                      height: 182 - (i % 3) * 8,
                      onTap: () => onOpen(b),
                    ),
                    const SizedBox(height: LrSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.only(left: LrSpacing.xs),
                      child: Text(
                        b.volumeOrder == 0
                            ? context.t('uiNoVolume')
                            : context
                                .tArgs('uiVolume3', <Object?>[b.volumeOrder]),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LrSpacing.l),
          child: ShelfBoard(colors: palette.shelfWood),
        ),
      ],
    );
  }
}

/// 分组级空状态：与搜索结果页共用同一套分类与文案（LegalTexts），
/// 不出现「没有匹配的书籍」这种不区分原因的提示。
class _EmptyShelfCard extends StatelessWidget {
  const _EmptyShelfCard({
    required this.kind,
    required this.query,
    required this.onImport,
    required this.onClearQuery,
    required this.onClearFavorites,
  });

  final LibraryEmptyKind kind;
  final String query;
  final ShowImport onImport;
  final VoidCallback onClearQuery;
  final VoidCallback onClearFavorites;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool noLibrary = kind == LibraryEmptyKind.noLibrary;
    final bool noFavorites = kind == LibraryEmptyKind.noFavorites;
    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            noFavorites
                ? context.t('favoriteEmptyTitle')
                : (noLibrary
                    ? context.t('emptyLibraryTitle')
                    : context.t('noResultTitle')),
            style: text.titleMedium,
          ),
          const SizedBox(height: LrSpacing.s),
          Text(
            noFavorites
                ? context.t('favoriteEmptyBody')
                : (noLibrary
                    ? context.t('emptyLibraryBody')
                    : (query.isEmpty
                        ? context.t('noResultBody')
                        : context.tArgs('uiPhrase005',
                            <Object?>[context.t('noResultBody'), query]))),
            style: text.bodySmall,
          ),
          const SizedBox(height: LrSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: noFavorites
                ? TextButton.icon(
                    onPressed: onClearFavorites,
                    icon: const Icon(Icons.star_border, size: 16),
                    label: Text(context.t('uiViewAllBooks'),
                        style: text.labelLarge),
                  )
                : noLibrary
                    ? TextButton.icon(
                        onPressed: onImport,
                        icon: const Icon(Icons.folder_open_outlined, size: 16),
                        label: Text(context.t('uiHowImportingWorks'),
                            style: text.labelLarge),
                      )
                    : TextButton.icon(
                        onPressed: onClearQuery,
                        icon: const Icon(Icons.backspace_outlined, size: 16),
                        label: Text(context.t('uiClearKeyword'),
                            style: text.labelLarge),
                      ),
          ),
        ],
      ),
    );
  }
}
