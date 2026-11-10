import 'package:flutter/material.dart';

import '../../domain/repositories/book_repository.dart';
import '../../domain/usecases/library_query.dart';
import '../../assembly/route_args.dart';
import '../../assembly/app_scope.dart';
import '../../core/common/design_tokens.dart';
import '../../core/ui/theme/glass_theme.dart';
import '../../core/ui/components/glass.dart';
import '../../l10n/lr_localizations.dart';

/// 搜索结果页：独立的 /search 路由，结果按分组切片展示。
/// 排序、关键词、空状态分类全部走 core 的 LibraryQuery，页面不自己写筛选逻辑。
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
  LibrarySort _sort = LibrarySort.volume;

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
    final SeasonPalette palette = Theme.of(context).extension<LrSeasonTheme>()?.palette ??
        SeasonPalette.all[isDark ? SeasonStyle.winter : SeasonStyle.paper]!;

    final int total = state.books.cached.length;
    final List<BookSummary> results = state.library(query: _query, sort: _sort);
    final LibraryEmptyKind empty = LibraryQuery.emptyKind(
      total: total,
      matched: results.length,
      query: _query,
    );
    final Map<String, List<BookSummary>> groups = LibraryQuery.groupByShelf(
      results,
      shelfOrder: DemoBookRepository.shelfTitles,
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
                : <Color>[palette.seed, Color.lerp(palette.seed, Colors.white, 0.5)!],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(LrSpacing.l, LrSpacing.s, LrSpacing.l, LrSpacing.xxl),
          children: <Widget>[
            GlassPanel(
              borderRadius: LrRadius.pill,
              padding: const EdgeInsets.symmetric(horizontal: LrSpacing.m, vertical: LrSpacing.xs),
              child: Row(
                children: <Widget>[
                  Icon(Icons.search, size: 19, color: text.bodySmall?.color),
                  const SizedBox(width: LrSpacing.s),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: widget.initialQuery.isEmpty,
                      onChanged: (String v) => setState(() => _query = v.trim()),
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
                      child: const Icon(Icons.close, size: 17),
                    ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.m),
            Wrap(
              spacing: LrSpacing.s,
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
              padding: const EdgeInsets.symmetric(horizontal: LrSpacing.s),
              child: Row(
                children: <Widget>[
                  Text(
                    _query.isEmpty ? context.tArgs('uiAllBooks3', <Object?>[results.length]) : context.tArgs('uiFoundBooks', <Object?>[results.length, _query]),
                    style: text.labelSmall,
                  ),
                  const Spacer(),
                  Text(context.t('demoDataNote'), style: text.labelSmall),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.s),

            if (empty != LibraryEmptyKind.none)
              _EmptyState(
                kind: empty,
                query: _query,
                onImport: widget.onImport,
                onClear: _clear,
              )
            else
              ...groups.entries
                  .where((MapEntry<String, List<BookSummary>> e) => e.value.isNotEmpty)
                  .map<Widget>((MapEntry<String, List<BookSummary>> e) => _GroupSection(
                        shelf: e.key,
                        books: e.value,
                        onOpenBook: widget.onOpenBook,
                      )),

            const SizedBox(height: LrSpacing.l),
            GlassPanel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.lock_outline, size: 15, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: LrSpacing.s),
                  Expanded(child: Text(context.t('localOnlyNote'), style: text.bodySmall)),
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
}

class _SortChip extends StatelessWidget {
  const _SortChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: LrSpacing.m, vertical: LrSpacing.s),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withOpacity(0.14) : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(LrRadius.pill),
          border: Border.all(color: selected ? scheme.primary.withOpacity(0.5) : Colors.white.withOpacity(0.3)),
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

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.shelf,
    required this.books,
    required this.onOpenBook,
  });

  final String shelf;
  final List<BookSummary> books;
  final OpenBookDetail onOpenBook;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LrSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LrSpacing.s),
            child: Row(
              children: <Widget>[
                Text(shelf, style: text.titleLarge),
                const SizedBox(width: LrSpacing.s),
                Text(context.tArgs('uiBooks2', <Object?>[books.length]), style: text.labelSmall),
                const SizedBox(width: LrSpacing.s),
                Expanded(child: Divider(color: Theme.of(context).dividerTheme.color)),
              ],
            ),
          ),
          const SizedBox(height: LrSpacing.s),
          ...books.map<Widget>((BookSummary b) => Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.s),
                child: _ResultTile(book: b, onTap: () => onOpenBook(b)),
              )),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.book, required this.onTap});
  final BookSummary book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: LrSpacing.m, vertical: LrSpacing.m),
        child: Row(
          children: <Widget>[
            // 细书脊色条：与 3D 书架用同一份封面色，编辑后可立即看到
            Container(
              width: 6,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LrRadius.spine),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[book.spineColor, Color.lerp(book.spineColor, Colors.black, 0.3)!],
                ),
              ),
            ),
            const SizedBox(width: LrSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    context.tArgs('uiBookMetaLine', <Object?>[
                      book.author,
                      book.format,
                      book.volumeOrder == 0
                          ? ''
                          : lrTextArgs('uiVolumes2', <Object?>[book.volumeOrder]),
                    ]),
                    style: text.labelSmall,
                  ),
                ],
              ),
            ),
            if (book.progress > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: LrSpacing.s, vertical: LrSpacing.xs),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(LrRadius.pill),
                ),
                child: Text('${(book.progress * 100).round()}%', style: text.labelSmall),
              ),
            const SizedBox(width: LrSpacing.s),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(LrSpacing.l, LrSpacing.xl, LrSpacing.l, LrSpacing.xl),
      child: Column(
        children: <Widget>[
          Icon(
            noLibrary ? Icons.auto_stories_outlined : Icons.search_off_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: LrSpacing.m),
          Text(
            noLibrary ? context.t('emptyLibraryTitle') : context.t('noResultTitle'),
            style: text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LrSpacing.s),
          Text(
            noLibrary
                ? context.t('emptyLibraryBody')
                : (query.isEmpty ? context.t('noResultBody') : context.tArgs('uiCurrentN1', <Object?>[context.t('noResultBody'), query])),
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
          const SizedBox(height: LrSpacing.s),
          Text(context.t('demoDataNote'), style: text.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
