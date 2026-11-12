import 'package:flutter/material.dart';

import '../../assembly/app_navigation.dart';
import '../../assembly/app_scope.dart';
import '../../core/common/design_tokens.dart';
import '../../core/model/book_identity.dart';
import '../../core/model/library_scope.dart';
import '../../core/model/wenku/wenku8_compliance.dart';
import '../../core/model/wenku/wenku8_models.dart';
import '../../core/model/wenku/wenku8_registry.dart';
import '../../core/model/wenku/wenku8_status.dart';
import '../../core/ui/components/book/book_cover_card.dart';
import '../../core/ui/components/glass/Nav.dart';
import '../../domain/repositories/book_repository.dart';
import '../../domain/usecases/cloud_book_projection.dart';
import '../../l10n/lr_localizations.dart';

/// 书架页「云端」子视图。
///
/// 之前 build 只 `return ListView()`，整页空白且没有背景；现在把状态卡、
/// 来源卡、搜索、榜单切换、合规说明与书目宫格全部接回来。
/// 书目点击与本地书一样进 `/detail`（BookDetailPage），不再分出第二套详情面板。
class CloudShelfView extends StatefulWidget {
  const CloudShelfView({
    super.key,
    this.onImport,
    this.onOpenBook,
    this.onGoCollect,
    this.categoryId = 'all',
    this.gridColumns = 2,
  });

  /// 「本地导入」来源的向导入口，由书架页透传（app 层注入）。
  final VoidCallback? onImport;

  /// 打开统一书籍详情页；云端书先投影成 BookSummary。
  final ValueChanged<BookSummary>? onOpenBook;

  /// 空态「去收藏」。
  final VoidCallback? onGoCollect;

  final String categoryId;

  /// 1 = 列表形态，2 / 3 = 书本格列数；由书架页布局按钮传入。
  final int gridColumns;

  @override
  State<CloudShelfView> createState() => _CloudShelfViewState();
}

class _CloudShelfViewState extends State<CloudShelfView> {
  String _sourceId = Wenku8Compliance.wenku8SourceId;
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool locked = state.wenku8Locked;
    final List<Wenku8Book> books = _visibleBooks(
      context,
      state.wenku8Listing?.books ?? const <Wenku8Book>[],
    );
    final ValueChanged<BookSummary> openBook =
        widget.onOpenBook ?? AppNavigationScope.of(context).onOpenBook;
    final VoidCallback goCollect =
        widget.onGoCollect ?? () => AppNavigationScope.of(context).onOpenSearch('');

    return ListView(
      padding: const EdgeInsets.only(bottom: LrSpacing.xxl),
      children: <Widget>[
        if (locked)
          _lockedCard(context, text, state)
        else
          _statusCard(context, text, state),
        const SizedBox(height: LrSpacing.m),
        _sourceRow(context, text),
        const SizedBox(height: LrSpacing.m),
        _localImportCard(context, text, state),
        if (!locked) ...<Widget>[
          const SizedBox(height: LrSpacing.m),
          _searchField(context, text, state),
          const SizedBox(height: LrSpacing.m),
          _feedChips(context, text, state),
        ],
        const SizedBox(height: LrSpacing.m),
        if (books.isEmpty)
          _emptyCard(context, text, goCollect)
        else
          CloudBookGrid(
            books: books,
            isAdded: state.isWenku8BookAdded,
            onOpen: (Wenku8Book b) => openBook(cloudBookSummary(b)),
            columns: widget.gridColumns,
          ),
        const SizedBox(height: LrSpacing.m),
        _complianceCard(context, text),
      ],
    );
  }

  Widget _sourceRow(BuildContext context, TextTheme text) {
    final BookSource current =
        Wenku8Registry.byId(_sourceId) ?? Wenku8Registry.sources.first;
    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.m),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_outlined,
              size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: LrSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(current.title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(current.subtitle, style: text.labelSmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '切换书籍来源',
            onSelected: (String v) => setState(() => _sourceId = v),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              for (final BookSource s in Wenku8Registry.sources)
                PopupMenuItem<String>(value: s.id, child: Text(s.title)),
            ],
            child: Chip(
              label: Text('切换来源', style: text.labelMedium),
              avatar: const Icon(Icons.swap_horiz, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _localImportCard(
          BuildContext context, TextTheme text, AppState state) =>
      GlassPanel(
        padding: const EdgeInsets.all(LrSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(lrText('wenkuLocalSourceNote'), style: text.bodySmall),
            const SizedBox(height: LrSpacing.xs),
            Text(lrText('cloudChannelsTitle'), style: text.titleMedium),
            const SizedBox(height: 4),
            Text(lrText('cloudChannelsNote'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.m),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: widget.onImport ??
                    () => AppNavigationScope.of(context).onImport(),
                icon: const Icon(Icons.file_download_outlined, size: 17),
                label:
                    Text(lrText('importWizardEntry'), style: text.labelLarge),
              ),
            ),
          ],
        ),
      );

  Widget _lockedCard(BuildContext context, TextTheme text, AppState state) =>
      GlassPanel(
        padding: const EdgeInsets.all(LrSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.lock_outline,
                size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: LrSpacing.m),
            Text(lrText('wenkuLockedTitle'), style: text.headlineMedium),
            const SizedBox(height: LrSpacing.xs),
            Text(lrText('wenkuLockedBody'), style: text.bodySmall),
            const SizedBox(height: LrSpacing.m),
            FilledButton.icon(
              onPressed: state.enableOnlineDirectory,
              icon: const Icon(Icons.cloud_outlined, size: 18),
              label: Text(lrText('wenkuUnlockButton'), style: text.labelLarge),
            ),
          ],
        ),
      );

  Widget _statusCard(BuildContext context, TextTheme text, AppState state) {
    final Wenku8Status s = state.wenku8Status;
    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.m),
      child: Row(
        children: <Widget>[
          Icon(
            Wenku8StatusLabels.isUsable(s)
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: LrSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(Wenku8StatusLabels.titles[s]!, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(Wenku8StatusLabels.hints[s]!, style: text.labelSmall),
              ],
            ),
          ),
          IconButton(
            tooltip: context.t('wenkuRefresh'),
            onPressed: () => state.refreshWenku8(),
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _feedChips(BuildContext context, TextTheme text, AppState state) =>
      Wrap(
        spacing: LrSpacing.xs,
        runSpacing: LrSpacing.xs,
        children: <Widget>[
          for (final Wenku8FeedKind f in Wenku8FeedKind.values)
            if (f != Wenku8FeedKind.search)
              ChoiceChip(
                label:
                    Text(Wenku8FeedLabels.labels[f]!, style: text.labelLarge),
                selected: state.wenku8Query.feed == f,
                onSelected: (bool _) => state.setWenku8Feed(f),
              ),
        ],
      );

  Widget _searchField(BuildContext context, TextTheme text, AppState state) =>
      GlassPanel(
        borderRadius: LrRadius.pill,
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.m, vertical: LrSpacing.xs),
        child: Row(
          children: <Widget>[
            Icon(Icons.search, size: 18, color: text.bodySmall?.color),
            const SizedBox(width: LrSpacing.xs),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (String v) {
                  setState(() {});
                  state.setWenku8Keyword(v);
                },
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: lrText('wenkuSearchHint'),
                  hintStyle: text.bodySmall,
                ),
                style: text.bodySmall,
              ),
            ),
            if (_search.text.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() {
                  _search.clear();
                  state.setWenku8Keyword('');
                }),
                child: const Icon(Icons.close, size: 16),
              ),
          ],
        ),
      );

  Widget _emptyCard(
          BuildContext context, TextTheme text, VoidCallback onGoCollect) =>
      GlassPanel(
        padding: const EdgeInsets.all(LrSpacing.l),
        child: Column(
          children: <Widget>[
            Icon(Icons.inbox_outlined,
                size: 34, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: LrSpacing.m),
            Text(lrText('wenkuEmptyTitle'), style: text.titleMedium),
            const SizedBox(height: LrSpacing.xs),
            Text(lrText('wenkuEmptyBody'),
                style: text.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: LrSpacing.m),
            FilledButton.icon(
              onPressed: onGoCollect,
              icon: const Icon(Icons.favorite_border, size: 18),
              label: Text(lrText('uiGoCollect')),
            ),
          ],
        ),
      );

  Widget _complianceCard(BuildContext context, TextTheme text) => GlassPanel(
        padding: const EdgeInsets.all(LrSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(lrText('wenkuOnlySources'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            ...Wenku8Compliance.rules.map<Widget>(
              (String rule) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $rule', style: text.labelSmall),
              ),
            ),
          ],
        ),
      );

  List<Wenku8Book> _visibleBooks(BuildContext context, List<Wenku8Book> books) {
    if (widget.categoryId == 'all' || widget.categoryId.isEmpty) return books;
    String label = '';
    for (final ShelfCategory c in ShelfCategories.wenku8) {
      if (c.id == widget.categoryId && c.labelKey != null) {
        label = context.t(c.labelKey!);
      }
    }
    if (label.isEmpty) return books;
    return books
        .where((Wenku8Book b) => b.tags.any((String t) => t.contains(label)))
        .toList();
  }

}

/// 云端书单：**图片 + 描述封面卡宫格**，列表 / 两栏 / 三栏共用同一份数据。
/// 右上角角标显示「云端」，列表形态显示 `WK-<bookid>` 展示编号。
class CloudBookGrid extends StatelessWidget {
  const CloudBookGrid({
    super.key,
    required this.books,
    required this.isAdded,
    required this.onOpen,
    this.columns = 2,
  });

  final List<Wenku8Book> books;
  final bool Function(String id) isAdded;
  final ValueChanged<Wenku8Book> onOpen;
  final int columns;

  CoverBook _cover(Wenku8Book b) => CoverBook(
        id: b.id,
        title: b.title,
        author: b.author.isEmpty ? '未知作者' : b.author,
        subtitle: BookIdentity.sourceSubtitle(BookOrigin.cloud),
        coverColor: b.coverColor,
        type: CoverBookType.novel,
        origin: CoverBookOrigin.cloud,
        badgeAdded: isAdded(b.id),
        progressText: '共 ${b.volumeCount} 卷',
      );

  Widget _card(Wenku8Book b, CoverDisplay display) => BookCoverCard(
        book: _cover(b),
        display: display,
        onClick: () => onOpen(b),
        onMore: () => onOpen(b),
        onLongPress: () => onOpen(b),
      );

  @override
  Widget build(BuildContext context) {
    final int cols = columns < 1 ? 1 : (columns > 3 ? 3 : columns);
    if (cols == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final Wenku8Book b in books) _card(b, CoverDisplay.list),
        ],
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: cols == 3 ? 0.46 : 0.53,
      ),
      itemCount: books.length,
      itemBuilder: (BuildContext context, int i) =>
          _card(books[i], CoverDisplay.grid),
    );
  }
}
