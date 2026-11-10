import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/repositories/book_repository.dart';
import '../../../assembly/app_scope.dart';
import '../../../core/model/stats/excerpt_capture.dart';
import '../../../core/model/stats/excerpt_query.dart';
import '../../../core/model/stats/excerpt_title_lookup.dart';
import '../../../core/model/stats/reading_stats.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/theme/glass_theme.dart';
import '../../../core/ui/theme/season_scheme.dart';
import '../../../core/ui/components/glass.dart';
import 'excerpt_edit_sheet.dart';
import 'excerpt_export_sheet.dart';
import '../../../l10n/lr_localizations.dart';

/// 摘录管理页：搜索 / 按书 / 按色 / 按范围筛选，排序与分组，编辑批注与划线，
/// 删除自己摘的条目，导出当前筛选结果的纯文本预览。
class ExcerptLibraryPage extends StatefulWidget {
  const ExcerptLibraryPage({
    super.key,
    this.initialQuery = '',
    this.initialBookId,
    this.initialDateKey,
  });

  final String initialQuery;
  final String? initialBookId;

  /// 第二十一轮：阅读日历「查看当天摘录」深链。按日与按书是两个独立维度，
  /// 可叠加；非法 dateKey 由 `ExcerptLibraryArgs.fromDay` 拦下，页面不校验。
  final String? initialDateKey;

  @override
  State<ExcerptLibraryPage> createState() => _ExcerptLibraryPageState();
}

class _ExcerptLibraryPageState extends State<ExcerptLibraryPage> {
  late final TextEditingController _controller;
  late ExcerptFilter _filter;
  ExcerptSort _sort = ExcerptSort.newest;
  ExcerptGroup _group = ExcerptGroup.none;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _filter = ExcerptFilter(
      query: widget.initialQuery,
      bookId: widget.initialBookId,
      dateKey: widget.initialDateKey,
    );
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
        SeasonSchemes.resolve(state.season.value, isDark ? Brightness.dark : Brightness.light);

    // 唯一数据源：不缓存，阅读器新增 / 编辑 / 删除后本页同一次 build 即可见。
    final List<Excerpt> all = state.excerpts;

    // 书名口径的唯一裁决点：展示 / 搜索 / 排序 / 分组 / 筛选选项全部读
    // 书库当前名称（含详情页编辑覆盖层），解析不到才回落捕获时快照。
    // 页面只构造一次，传给所有查询出口，避免每个调用点各写一份 resolver。
    final ExcerptTitleLookup titles = ExcerptTitleLookup(
      (String id) => state.resolveBook(id)?.title,
    );

    final ExcerptSummary summary = ExcerptQuery.summarize(all, titles: titles);
    final List<Excerpt> results = ExcerptQuery.apply(
      excerpts: all,
      filter: _filter,
      sort: _sort,
      titles: titles,
    );
    final Map<String, List<Excerpt>> groups =
        ExcerptQuery.group(results, by: _group, titles: titles);

    // 深链口径：initialBookId 只给一个 id，展示书名**唯一出口**是书库解析
    // （含详情页编辑覆盖层），不能用 Excerpt.bookTitle 快照——否则详情页改成
    // 《新书名》后，这里的上下文卡和筛选 chip 还显示《旧书名》。
    // 一本书零摘录时 bookOptions(all) 里没有它，必须固定成 count=0 的选项，
    // 否则筛选器会变成看不见的幽灵条件，用户也不知道当前看的是哪一本。
    final String? scopedBookId = _filter.bookId;
    final BookSummary? scopedBook =
        scopedBookId == null ? null : state.resolveBook(scopedBookId);
    final bool scopedBookMissing = scopedBookId != null && scopedBook == null;
    final List<ExcerptBookOption> books = ExcerptQuery.bookOptions(
      all,
      pinnedBookId: scopedBookId,
      pinnedTitle: scopedBook?.title,
      titles: titles,
    );
    String scopedTitle = scopedBook?.title ?? '';
    if (scopedTitle.isEmpty && scopedBookId != null) {
      // 书库里找不到这本书：回落到选项标题（快照 / 未标注书名），不显示空书名号。
      for (final ExcerptBookOption o in books) {
        if (o.bookId == scopedBookId) {
          scopedTitle = o.title;
          break;
        }
      }
    }
    final int scopedCount = scopedBookId == null
        ? 0
        : ExcerptQuery.countForBook(all, scopedBookId);
    final int scopedDayCount = _filter.dateKey == null
        ? 0
        : ExcerptQuery.countForDay(all, _filter.dateKey!);
    final ExcerptEmptyKind empty = ExcerptQuery.emptyKind(
      total: all.length,
      matched: results.length,
      filter: _filter,
      scopedBookCount: scopedCount,
      scopedDayCount: scopedDayCount,
    );

    return Scaffold(
      backgroundColor: isDark ? palette.seed : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(context.t('uiExcerptLibrary')),
        actions: <Widget>[
          IconButton(
            tooltip: context.t('uiExportCurrentResultsPlainTextPreview'),
            onPressed: results.isEmpty
                ? null
                : () => unawaited(ExcerptExportSheet.open(
                      context,
                      excerpts: results,
                      filterDescription: _filterDescription(scopedTitle),
                    )),
            icon: const Icon(Icons.ios_share_outlined, size: 20),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? <Color>[palette.seed, Color.lerp(palette.seed, Colors.black, 0.35)!]
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
                      onChanged: (String v) => setState(
                        () => _filter = _filter.copyWith(query: v.trim()),
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: context.t('uiTextTitleChapterNote'),
                        hintStyle: text.bodyMedium,
                      ),
                      style: text.bodyMedium,
                    ),
                  ),
                  if (_filter.query.isNotEmpty)
                    GestureDetector(
                      onTap: _clearQuery,
                      child: const Icon(Icons.close, size: 17),
                    ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LrSpacing.s),
              child: Text(context.t('excerptSearchTitleNote'), style: text.labelSmall),
            ),
            const SizedBox(height: LrSpacing.m),

            // 第二十一轮：按天深链的可见 chip。不把 dateKey 变成幽灵筛选条件，
            // 清除后回到全部摘录；与纪念物册的日期 chip 同一套交互。
            if (_filter.dateKey != null) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.s),
                child: Wrap(
                  spacing: LrSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    InputChip(
                      avatar: const Icon(Icons.today_outlined, size: 16),
                      label: Text(
                        '${context.t('excerptDayScopedTitle')} · ${_filter.dateKey}',
                        style: text.labelLarge,
                      ),
                      onDeleted: () => setState(
                        () => _filter = _filter.copyWith(clearDate: true),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                    ),
                    Text(context.t('excerptDayFilterNote'), style: text.labelSmall),
                  ],
                ),
              ),
            ],
            // 深链上下文：明确告诉用户「当前只看哪一本」，且随时能退回全部书。
            if (scopedBookId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.m),
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.menu_book_outlined, size: 17,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: LrSpacing.s),
                          Expanded(
                            child: Text(
                              context.tArgs('uiItemsN1', <Object?>[context.t('bookExcerptTitle'), scopedTitle, scopedCount]),
                              style: text.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(
                              () => _filter = _filter.copyWith(clearBook: true),
                            ),
                            child: Text(context.t('uiAllBooks')),
                          ),
                        ],
                      ),
                      const SizedBox(height: LrSpacing.xs),
                      Text(context.t('bookExcerptScopedNote'), style: text.bodySmall),
                      if (scopedBookMissing) ...<Widget>[
                        const SizedBox(height: LrSpacing.xs),
                        Text(context.t('bookExcerptMissingNote'), style: text.labelSmall),
                      ],
                      if (scopedCount == 0) ...<Widget>[
                        const SizedBox(height: LrSpacing.xs),
                        Text(context.t('bookExcerptPinnedNote'), style: text.labelSmall),
                      ],
                    ],
                  ),
                ),
              ),

            // 摘要：来自 ExcerptSummary，页面不算数
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LrSpacing.s),
              child: Text(
                context.tArgs('uiTotalYours', <Object?>[summary.total, summary.userCount]) +
                context.tArgs('uiNoteItemsItems', <Object?>[summary.withNoteCount, results.length]),
                style: text.labelSmall,
              ),
            ),
            const SizedBox(height: LrSpacing.s),

            Text(context.t('uiScope2'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Wrap(
              spacing: LrSpacing.s,
              children: <Widget>[
                for (final ExcerptScope s in ExcerptScope.values)
                  ChoiceChip(
                    label: Text(ExcerptQuery.scopeLabels[s]!),
                    selected: _filter.scope == s,
                    onSelected: (bool _) => setState(
                      () => _filter = _filter.copyWith(scope: s),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: LrSpacing.s),

            Text(context.t('uiByBook'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Wrap(
              spacing: LrSpacing.s,
              runSpacing: LrSpacing.xs,
              children: <Widget>[
                ChoiceChip(
                  label: Text(context.t('uiAllBooks')),
                  selected: _filter.bookId == null,
                  onSelected: (bool _) => setState(
                    () => _filter = _filter.copyWith(clearBook: true),
                  ),
                ),
                for (final ExcerptBookOption b in books)
                  ChoiceChip(
                    label: Text('${b.title} · ${b.count}'),
                    selected: _filter.bookId == b.bookId,
                    onSelected: (bool _) => setState(
                      () => _filter = _filter.copyWith(bookId: b.bookId),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: LrSpacing.s),

            Text(context.t('uiHighlight'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.xs),
            Wrap(
              spacing: LrSpacing.s,
              runSpacing: LrSpacing.xs,
              children: <Widget>[
                ChoiceChip(
                  label: Text(context.t('uiAllColors')),
                  selected: _filter.color == null,
                  onSelected: (bool _) => setState(
                    () => _filter = _filter.copyWith(clearColor: true),
                  ),
                ),
                for (final HighlightColor c in HighlightColor.values)
                  ChoiceChip(
                    label: Text(HighlightPalette.labels[c]!),
                    selected: _filter.color == c,
                    onSelected: (bool _) => setState(
                      () => _filter = _filter.copyWith(color: c),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: LrSpacing.m),

            Row(
              children: <Widget>[
                Expanded(
                  child: _DropdownRow<ExcerptSort>(
                    label: context.t('uiSort'),
                    value: _sort,
                    items: ExcerptSort.values,
                    labels: ExcerptQuery.sortLabels,
                    onChanged: (ExcerptSort v) => setState(() => _sort = v),
                  ),
                ),
                const SizedBox(width: LrSpacing.s),
                Expanded(
                  child: _DropdownRow<ExcerptGroup>(
                    label: context.t('uiGroup'),
                    value: _group,
                    items: ExcerptGroup.values,
                    labels: ExcerptQuery.groupLabels,
                    onChanged: (ExcerptGroup v) => setState(() => _group = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: LrSpacing.m),

            if (empty != ExcerptEmptyKind.none)
              _EmptyState(
                kind: empty,
                filter: _filter,
                bookTitle: scopedTitle,
                onReset: _resetFilter,
              )
            else
              ...groups.entries.map<Widget>(
                (MapEntry<String, List<Excerpt>> e) => _ExcerptSection(
                      title: e.key,
                      excerpts: e.value,
                      onEdit: _edit,
                      onDelete: _delete,
                    ),
              ),

            const SizedBox(height: LrSpacing.l),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(context.t('excerptReadOnlyNote'), style: text.bodySmall),
                  const SizedBox(height: LrSpacing.s),
                  Text(context.t('excerptLocalNote'), style: text.bodySmall),
                  const SizedBox(height: LrSpacing.s),
                  Text(context.t('excerptExportSnapshotNote'), style: text.bodySmall),
                  const SizedBox(height: LrSpacing.s),
                  Text(context.t('demoDataNote'), style: text.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _filterDescription(String scopedTitle) {
    final List<String> parts = <String>[ExcerptQuery.scopeLabels[_filter.scope]!];
    if (_filter.bookId != null) {
      parts.add(scopedTitle.isEmpty ? lrText('uiSelectedBook') : '《$scopedTitle》');
    }
    if (_filter.color != null) parts.add(HighlightPalette.labels[_filter.color]!);
    if (_filter.dateKey != null) parts.add(lrTextArgs('uiDays', <Object?>[_filter.dateKey]));
    if (_filter.query.isNotEmpty) parts.add(lrTextArgs('uiKeyword', <Object?>[_filter.query]));
    parts.add(ExcerptQuery.sortLabels[_sort]!);
    return parts.join(' · ');
  }

  void _clearQuery() {
    _controller.clear();
    setState(() => _filter = _filter.copyWith(query: ''));
  }

  void _resetFilter() {
    _controller.clear();
    setState(() => _filter = const ExcerptFilter());
  }

  Future<void> _edit(Excerpt e) async {
    if (!e.isUserAdded) return;
    await ExcerptEditSheet.open(context, e);
  }

  void _delete(Excerpt e) {
    if (!e.isUserAdded) return;
    final AppState state = AppScope.of(context);
    final bool removed = state.removeExcerpt(e.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(removed ? lrText('uiExcerptDeleted') : lrText('uiItemsexcerpts'))),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.labels,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final Map<T, String> labels;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: LrSpacing.m, vertical: LrSpacing.xs),
      child: Row(
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: LrSpacing.s),
          Expanded(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              isDense: true,
              items: <DropdownMenuItem<T>>[
                for (final T item in items)
                  DropdownMenuItem<T>(
                    value: item,
                    child: Text(labels[item] ?? '$item',
                        style: Theme.of(context).textTheme.labelLarge),
                  ),
              ],
              onChanged: (T? v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExcerptSection extends StatelessWidget {
  const _ExcerptSection({
    required this.title,
    required this.excerpts,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final List<Excerpt> excerpts;
  final Future<void> Function(Excerpt) onEdit;
  final void Function(Excerpt) onDelete;

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
                Text(title, style: text.titleLarge),
                const SizedBox(width: LrSpacing.s),
                Text(context.tArgs('uiItems2', <Object?>[excerpts.length]), style: text.labelSmall),
                const SizedBox(width: LrSpacing.s),
                Expanded(child: Divider(color: Theme.of(context).dividerTheme.color)),
              ],
            ),
          ),
          const SizedBox(height: LrSpacing.s),
          ...excerpts.map<Widget>((Excerpt e) => Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.s),
                child: _ExcerptCard(
                  excerpt: e,
                  onEdit: () => onEdit(e),
                  onDelete: () => onDelete(e),
                ),
              )),
        ],
      ),
    );
  }
}

class _ExcerptCard extends StatelessWidget {
  const _ExcerptCard({
    required this.excerpt,
    required this.onEdit,
    required this.onDelete,
  });

  final Excerpt excerpt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color color = HighlightPalette.spine(excerpt.highlight);
    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(LrRadius.pill),
                ),
              ),
              const SizedBox(width: LrSpacing.m),
              Expanded(
                child: Text(excerpt.text, style: text.bodyLarge?.copyWith(height: 1.7)),
              ),
            ],
          ),
          if (excerpt.note.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: LrSpacing.s),
            Padding(
              padding: const EdgeInsets.only(left: LrSpacing.l),
              child: Text('—— ${excerpt.note.trim()}', style: text.bodySmall),
            ),
          ],
          const SizedBox(height: LrSpacing.m),
          Divider(color: Theme.of(context).dividerTheme.color, height: 1),
          const SizedBox(height: LrSpacing.s),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: LrSpacing.s, vertical: 2),
                decoration: BoxDecoration(
                  color: HighlightPalette.lineTint(excerpt.highlight),
                  borderRadius: BorderRadius.circular(LrRadius.pill),
                ),
                child: Text(
                  excerpt.isUserAdded ? context.t('uiYours') : context.t('uiSampleReadOnly'),
                  style: text.labelSmall,
                ),
              ),
              const SizedBox(width: LrSpacing.s),
              Expanded(
                child: Text(
                  '《${excerpt.bookTitle}》· ${excerpt.chapterTitle} · '
                  '${ExcerptQuery.formatDate(excerpt.capturedAt)}',
                  style: text.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (excerpt.isUserAdded) ...<Widget>[
                IconButton(
                  tooltip: context.t('uiEditNoteHighlight'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: context.t('uiDeleteExcerpt'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.kind,
    required this.filter,
    required this.bookTitle,
    required this.onReset,
  });

  final ExcerptEmptyKind kind;
  final ExcerptFilter filter;
  final String bookTitle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool noExcerpts = kind == ExcerptEmptyKind.noExcerpts;
    final bool bookHasNone = kind == ExcerptEmptyKind.bookHasNone;
    final bool dayHasNone = kind == ExcerptEmptyKind.dayHasNone;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(LrSpacing.l, LrSpacing.xl, LrSpacing.l, LrSpacing.xl),
      child: Column(
        children: <Widget>[
          Icon(
            (noExcerpts || bookHasNone || dayHasNone)
                ? Icons.format_quote_outlined
                : Icons.filter_alt_off_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: LrSpacing.m),
          Text(
            noExcerpts
                ? context.t('excerptEmptyTitle')
                : (bookHasNone
                    ? context.t('bookExcerptEmptyTitle')
                    : (dayHasNone
                        ? context.t('excerptDayEmptyTitle')
                        : context.t('excerptNoResultTitle'))),
            style: text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (bookHasNone && bookTitle.isNotEmpty) ...<Widget>[
            const SizedBox(height: LrSpacing.xs),
            Text('《$bookTitle》', style: text.titleMedium, textAlign: TextAlign.center),
          ],
          const SizedBox(height: LrSpacing.s),
          Text(
            noExcerpts
                ? context.t('excerptEmptyBody')
                : (bookHasNone
                    ? context.t('bookExcerptEmptyBody')
                    : (dayHasNone
                        ? context.t('excerptDayEmptyBody')
                        : context.t('excerptNoResultBody'))),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (!noExcerpts && !filter.isEmpty) ...<Widget>[
            const SizedBox(height: LrSpacing.l),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_outlined, size: 17),
              label: Text(
                dayHasNone
                    ? context.t('uiClearDateFilter')
                    : (bookHasNone ? context.t('uiAllBooks2') : context.t('uiClearFilters')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
