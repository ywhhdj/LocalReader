import 'package:flutter/material.dart';

import '../../assembly/app_scope.dart';
import '../../core/model/library_scope.dart';
import '../../core/common/design_tokens.dart';
import '../../core/ui/components/glass/Nav.dart';
import '../../core/ui/components/wenku8_detail_sheet.dart';
import '../../core/ui/components/book/book_cover_card.dart';
import '../../core/model/wenku/wenku8_compliance.dart';
import '../../core/model/wenku/wenku8_models.dart';
import '../../core/model/wenku/wenku8_registry.dart';
import '../../domain/repositories/wenku8_source.dart';
import '../../l10n/lr_localizations.dart';

/// 书架页「云端」子视图
class CloudShelfView extends StatefulWidget {
  const CloudShelfView({
    super.key,
    this.onImport,
    this.categoryId = 'all',
    this.gridColumns = 2,
    this.onGoCollect,
  });

  /// 「本地导入」来源的向导入口，由书架页透传（app 层注入）。
  final VoidCallback? onImport;

  /// 云端分类 id 由书架页工具条传入；组件不自己拼请求 URL。
  final String categoryId;

  /// 宫格列数由书架页布局按钮传入（列表 / 两栏 / 三栏共用同一份云端数据）。
  final int gridColumns;

  /// 空态「去收藏」：由 app 层注入，页面不自己拼路由。
  final VoidCallback? onGoCollect;

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
    final BookSource source =
        Wenku8Registry.byId(_sourceId) ?? Wenku8Registry.sources.first;
    final Wenku8Listing? listing = state.wenku8Listing;

    return ListView();
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
                onPressed: widget.onImport,
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
                onChanged: state.setWenku8Keyword,
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
                onTap: () {
                  _search.clear();
                  state.setWenku8Keyword('');
                },
                child: const Icon(Icons.close, size: 16),
              ),
          ],
        ),
      );

  Widget _emptyCard(
          BuildContext context, TextTheme text, VoidCallback? onGoCollect) =>
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

  Future<void> _openDetail(
      BuildContext context, AppState state, Wenku8Book book) async {
    final Wenku8Detail? detail = await state.wenku8Detail(book.id);
    if (detail == null || !context.mounted) return;
    await Wenku8DetailSheet.open(
      context,
      detail: detail,
      added: state.isWenku8BookAdded(book.id),
      onAdd: (Wenku8Book b) {
        final bool ok = state.addWenku8BookToLibrary(b);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                ok ? context.t('wenkuAddedNote') : context.t('wenkuBookAdded')),
          ),
        );
      },
    );
  }
}

/// 云端书单 v2：**图片 + 描述封面卡宫格**，不是线性列表、更不是立体书架。
/// 三档列数共用同一份 List<Wenku8Book>；空态由调用方的 _emptyCard 负责。
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

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns < 1 ? 1 : (columns > 3 ? 3 : columns),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        itemCount: books.length,
        itemBuilder: (BuildContext context, int i) {
          final Wenku8Book b = books[i];
          return BookCoverCard(
            book: CoverBook(
              id: b.id,
              title: b.title,
              author: b.author,
              coverColor: b.coverColor,
              type: CoverBookType.novel,
              subtitle: '云端 · ${b.volumeCount} 卷',
              badgeAdded: isAdded(b.id),
            ),
            onClick: () => onOpen(b),
          );
        },
      );
}
