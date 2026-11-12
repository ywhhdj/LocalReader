import 'package:flutter/material.dart';

import '../../domain/repositories/book_repository.dart';
import '../../domain/usecases/library_query.dart';
import '../../assembly/route_args.dart';
import '../../assembly/app_scope.dart';
import '../../core/common/design_tokens.dart';
import '../../core/ui/theme/glass_theme.dart';
import '../../core/ui/components/glass/Nav.dart';
import '../../core/model/book_identity.dart';
import '../../core/ui/components/book/book_cover_card.dart';
import '../../l10n/lr_localizations.dart';
import 'shelf_page.dart' show coverBookOf;

/// 搜索结果页：独立的 /search 路由，结果与书架列表共用 BookCoverCard。
/// 默认「最近观看优先」，排序、关键词、空状态分类全部走 core 的 LibraryQuery，
/// 页面不自己写筛选逻辑。
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.initialQuery = '',
    required this.onOpenBook,
    required this.onImport,
  });

  final String initialQuery;
  final OpenBookDetail onOpenBook;
  final ShowImport onImport;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  late String _query;
  // 与书架一致：最近观看优先，切换排序芯片才改变口径。
  LibrarySort _sort = LibrarySort.recent;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _controller = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final SeasonPalette palette =
        Theme.of(context).extension<LrSeasonTheme>()?.palette ??
            SeasonPalette.all[isDark ? SeasonStyle.winter : SeasonStyle.paper]!;

    final int total = state.books.cached.length;
    final List<BookSummary> results = state.library(query: _query, sort: _sort);
    final LibraryEmptyKind empty = LibraryQuery.emptyKind(
      total: total,
      matched: results.length,
      query: _query,
    );
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF15171C) : palette.seed,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(context.t('uiSearchLocalLibrary')),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? <Color>[const Color(0xFF15171C), const Color(0xFF1D2027)]
                : <Color>[
                    palette.seed,
                    Color.lerp(palette.seed, Colors.white, 0.5)!
                  ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              LrSpacing.xs, LrSpacing.xs, LrSpacing.xs, LrSpacing.xs),
          children: <Widget>[
            GlassPanel(
              borderRadius: LrRadius.spine,
              padding: const EdgeInsets.symmetric(
                  horizontal: LrSpacing.m, vertical: LrSpacing.xs),
              child: Row(
                children: <Widget>[
                  Icon(Icons.search, size: 19, color: text.bodySmall?.color),
                  const SizedBox(width: LrSpacing.xs),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: widget.initialQuery.isEmpty,
                      onChanged: (String v) =>
                          setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: context.t('uiTitleAuthorFormatGroup'),
                        hintStyle: text.bodyMedium,
                      ),
                      style: text.bodyMedium,
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: _clear,
                      child: Icon(Icons.close,
                          size: 17, color: text.bodySmall?.color),
                    ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.m),
            Wrap(
              spacing: LrSpacing.xs,
              children: <Widget>[
                for (final LibrarySort s in LibrarySort.values)
                  _SortChip(
                    label: LibraryQuery.sortLabels[s]!,
                    selected: _sort == s,
                    onTap: () => setState(() => _sort = s),
                  ),
              ],
            ),
            const SizedBox(height: LrSpacing.m),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LrSpacing.xs),
              child: Row(
                children: <Widget>[
                  Text(
                    _query.isEmpty
                        ? context
                            .tArgs('uiAllBooks3', <Object?>[results.length])
                        : context.tArgs(
                            'uiFoundBooks', <Object?>[results.length, _query]),
                    style: text.labelSmall,
                  ),
                  const Spacer(),
                  Text(context.t('demoDataNote'), style: text.labelSmall),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.xs),
            if (empty != LibraryEmptyKind.none)
              _EmptyState(
                kind: empty,
                query: _query,
                onImport: widget.onImport,
                onClear: _clear,
              )
            else
              _ResultList(
                books: results,
                onOpenBook: widget.onOpenBook,
                onMore: (BookSummary b) => _showBookActions(context, b),
              ),
            const SizedBox(height: LrSpacing.l),
            GlassPanel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.lock_outline,
                      size: 15, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: LrSpacing.xs),
                  Expanded(
                      child: Text(context.t('localOnlyNote'),
                          style: text.bodySmall)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
  }

  /// 列表卡片「…」：查看详情 / 收藏都落到真实动作，不留静默点击。
  void _showBookActions(BuildContext context, BookSummary book) {
    final AppState state = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(LrSpacing.m),
              child: Text(
                '《${book.title}》 · ${BookIdentity.displayId(book.id)}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onOpenBook(book);
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
            const SizedBox(height: LrSpacing.s),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.m, vertical: LrSpacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(LrRadius.pill),
          border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.5)
                  : scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? scheme.primary : null,
                fontWeight: selected ? FontWeight.w700 : null,
              ),
        ),
      ),
    );
  }
}

/// 搜索结果：与书架列表共用 BookCoverCard 的列表形态，
/// 展示编号、来源角标、章节进度与「…」菜单；顺序直接沿用 state.library 的
/// 最近观看优先，不再按分组打散。
class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.books,
    required this.onOpenBook,
    required this.onMore,
  });

  final List<BookSummary> books;
  final OpenBookDetail onOpenBook;
  final ValueChanged<BookSummary> onMore;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final BookSummary b in books)
            BookCoverCard(
              book: coverBookOf(b),
              display: CoverDisplay.list,
              onClick: () => onOpenBook(b),
              onMore: () => onMore(b),
              onLongPress: () => onMore(b),
            ),
        ],
      );
}

/// 空状态分类：书库为空引导导入，无匹配结果引导改关键词。
/// 两种状态的按钮完全不同，避免「暂无数据」这种什么都没说的提示。
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.kind,
    required this.query,
    required this.onImport,
    required this.onClear,
  });

  final LibraryEmptyKind kind;
  final String query;
  final ShowImport onImport;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool noLibrary = kind == LibraryEmptyKind.noLibrary;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(
          LrSpacing.l, LrSpacing.xl, LrSpacing.l, LrSpacing.xl),
      child: Column(
        children: <Widget>[
          Icon(
            noLibrary ? Icons.auto_stories_outlined : Icons.search_off_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: LrSpacing.m),
          Text(
            noLibrary
                ? context.t('emptyLibraryTitle')
                : context.t('noResultTitle'),
            style: text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LrSpacing.xs),
          Text(
            noLibrary
                ? context.t('emptyLibraryBody')
                : (query.isEmpty
                    ? context.t('noResultBody')
                    : context.tArgs('uiCurrentN1',
                        <Object?>[context.t('noResultBody'), query])),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LrSpacing.l),
          if (noLibrary)
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: Text(context.t('uiHowImportingWorks')),
            )
          else
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.backspace_outlined, size: 18),
              label: Text(context.t('uiClearKeyword')),
            ),
          const SizedBox(height: LrSpacing.xs),
          Text(context.t('demoDataNote'),
              style: text.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
