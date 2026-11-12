import 'package:Local_reader/core/model/book_document.dart';
import 'package:Local_reader/core/ui/components/glass/Page.dart';
import 'package:flutter/material.dart';

import '../../assembly/app_scope.dart';
import '../../assembly/route_args.dart';
import '../../core/common/design_tokens.dart';
import '../../core/model/book_identity.dart';
import '../../core/model/fixtures/demo_document.dart';
import '../../core/model/stats/excerpt_query.dart';
import '../../core/model/stats/excerpt_title_lookup.dart';
import '../../core/ui/components/glass/Nav.dart';
import '../../domain/repositories/book_repository.dart';
import '../../l10n/lr_localizations.dart';
import 'detail_sections.dart';

/// 书籍详情页：本地书与云端书公用这一套页面
class BookDetailPage extends StatelessWidget {
  const BookDetailPage({
    super.key,
    required this.book,
    required this.onOpenReader,
    required this.onOpenToc,
    required this.onOpenBookExcerpts,
  });

  final BookSummary book;
  final OpenReaderPage onOpenReader;
  final OpenTocPage onOpenToc;
  final OpenBookExcerpts onOpenBookExcerpts;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final BookSummary b = state.effective(book);
    final bool isCloud = BookIdentity.isCloudId(b.id);
    final BookDocument document = DemoDocumentFactory.from(b);
    final int resume = DemoDocumentFactory.resumeChapter(b);
    final ExcerptTitleLookup titles = ExcerptTitleLookup(
      (String id) => state.resolveBook(id)?.title,
    );
    final int excerptCount = ExcerptQuery.apply(
      excerpts: state.excerpts,
      filter: ExcerptFilter(bookId: b.id),
      titles: titles,
    ).length;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final List<_DetailBlock> blocks = <_DetailBlock>[
      if (b.progress > 0) _DetailBlock.progress,
      _DetailBlock.toc,
      _DetailBlock.synopsis,
      _DetailBlock.excerpt,
      _DetailBlock.info,
    ];

    return Scaffold(
      // 主题底色：浅色 / 暗色都由 colorScheme 提供，不再硬编码 0xFF15171C。
      backgroundColor: scheme.surface,
      appBar: DetailTopBar(
        isCloud: isCloud,
        onCloudCache: () => _cloudCache(context, state, b),
        onDelete: () => _delete(context, state, b),
        onResetProgress: () => _reset(context, state, b),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              scheme.surface,
              scheme.surfaceVariant.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: LrPage.builder(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DetailCoverInfo(
                book: b,
                isCloud: isCloud,
                onAuthorTap: () => _openEditor(context, b),
                onRetryCache: () => _refreshInfo(context, state, b),
              ),
              const SizedBox(height: LrSpacing.l),
              DetailTagRow(tags: <String>[
                context.t('detailTagSchool'),
                context.t('detailTagBattle'),
                context.t('detailTagYouth'),
                context.t('detailTagRomance'),
                context.t('detailTagHarem'),
              ]),
            ],
          ),
          itemCount: blocks.length,
          itemBuilder: (BuildContext context, int index) {
            final _DetailBlock block = blocks[index];
            if (block == _DetailBlock.progress) {
              return Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.l),
                child: DetailProgressCard(
                  chapterTitle: document.chapters.isEmpty
                      ? context.t('uiNoVolume')
                      : document.chapters[resume].title,
                  progress: b.progress,
                ),
              );
            }
            if (block == _DetailBlock.toc) {
              return Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.l),
                child: _TocEntry(
                  count: document.chapters.length,
                  onOpen: () => _openToc(context, b, resume),
                ),
              );
            }
            if (block == _DetailBlock.synopsis) {
              return Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.l),
                child: DetailSynopsis(paragraphs: <String>[
                  context.t('detailSynopsisDemo1'),
                  context.t('detailSynopsisDemo2'),
                  context.t('detailSynopsisDemo3'),
                ]),
              );
            }
            if (block == _DetailBlock.excerpt) {
              return Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.l),
                child: _BookExcerptCard(
                  count: excerptCount,
                  onOpen: () => onOpenBookExcerpts(b.id),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: LrSpacing.l),
              child: _BookInfoCard(
                book: b,
                isCloud: isCloud,
                commentCount: state.commentsFor(b.id).length,
                onOpenComments: () => _openComments(context, b),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum:
            const EdgeInsets.fromLTRB(LrSpacing.l, 0, LrSpacing.l, LrSpacing.m),
        child: DetailActionBar(
          isCloud: isCloud,
          started: b.progress > 0,
          onPrimary: () {
            final bool changed = isCloud
                ? state.addCloudBookToLibrary(b)
                : state.toggleFavorite(b.id);
            _hint(
              context,
              isCloud
                  ? (changed
                      ? '已加入本地书架（仅元数据）'
                      : '这本书已在书架中')
                  : (changed
                      ? context.t('uiAddedToFavorites')
                      : context.t('uiRemovedFromFavorites')),
            );
          },
          onSecondary: isCloud
              ? () => _openComments(context, b)
              : () => _openEditor(context, b),
          onRead: () {
            state.markAsRead(b.id);
            onOpenReader(b, resume);
          },
        ),
      ),
    );
  }

  Future<void> _openToc(
      BuildContext context, BookSummary b, int current) async {
    final int? picked = await onOpenToc(b, current);
    if (picked == null || !context.mounted) return;
    onOpenReader(b, picked);
  }

  void _cloudCache(BuildContext context, AppState state, BookSummary b) {
    final bool added = state.addCloudBookToLibrary(b);
    _hint(
      context,
      added ? '已加入本地书架（仅元数据，未下载正文）' : '这本书已在书架中',
    );
  }

  void _refreshInfo(BuildContext context, AppState state, BookSummary b) {
    state.markAsRead(b.id);
    _hint(context, '已刷新书籍信息并把本书排到最近观看');
  }

  void _reset(BuildContext context, AppState state, BookSummary b) {
    state.resetProgress(b.id);
    _hint(context, '阅读进度已重置');
  }

  Future<void> _delete(
      BuildContext context, AppState state, BookSummary b) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('移出书架'),
        content: Text('确定把《${b.title}》从书架移除吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final bool ok = state.removeBook(b.id);
    if (!context.mounted) return;
    _hint(context, ok ? '已移出书架' : '这本书不在可移出的书库中');
    if (ok) Navigator.of(context).pop();
  }

  void _openEditor(BuildContext context, BookSummary b) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DetailMetaEditorSheet(
          book: b,
          onSave:
              (String title, String author, Color spineColor, int volumeOrder) {
            AppScope.of(context).updateBook(
              b.id,
              title: title,
              author: author,
              spineColor: spineColor,
              volumeOrder: volumeOrder,
            );
            _hint(context, '已保存书籍信息');
          },
        ),
      ),
    );
  }

  void _openComments(BuildContext context, BookSummary b) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CommentSheet(book: b),
      ),
    );
  }

  void _hint(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 「这本书的摘录」入口：组件只显示条数与引导，深链只回传 bookId。
class _BookExcerptCard extends StatelessWidget {
  const _BookExcerptCard({required this.count, required this.onOpen});

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.t('bookExcerptTitle'),
        child: DetailExcerptEntry(count: count, onOpen: onOpen),
      );
}

/// 书籍信息卡：展示编号、来源、格式等真实信息，替换原来的静态提示条。
class _BookInfoCard extends StatelessWidget {
  const _BookInfoCard({
    required this.book,
    required this.isCloud,
    required this.commentCount,
    required this.onOpenComments,
  });

  final BookSummary book;
  final bool isCloud;
  final int commentCount;
  final VoidCallback onOpenComments;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[
      MapEntry<String, String>('书籍编号', BookIdentity.displayId(book.id)),
      MapEntry<String, String>(
          '来源',
          BookIdentity.originLabel(
              isCloud ? BookOrigin.cloud : BookOrigin.local)),
      MapEntry<String, String>('格式', book.format),
      MapEntry<String, String>('编码', book.encoding),
      MapEntry<String, String>(
          '卷序', book.volumeOrder == 0 ? '未分卷' : '第 ${book.volumeOrder} 卷'),
      if (isCloud) MapEntry<String, String>('评论', '$commentCount 条'),
    ];
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('书籍信息', style: text.titleMedium),
          const SizedBox(height: LrSpacing.s),
          for (final MapEntry<String, String> row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 76,
                    child: Text(row.key, style: text.labelSmall),
                  ),
                  Expanded(child: Text(row.value, style: text.bodyMedium)),
                ],
              ),
            ),
          if (isCloud)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenComments,
                icon: const Icon(Icons.comment_outlined, size: 17),
                label: const Text('查看 / 写评论'),
              ),
            ),
        ],
      ),
    );
  }
}

/// 云端书籍评论面板：输入即写入全局状态，页面与信息卡同一次刷新可见。
class _CommentSheet extends StatefulWidget {
  const _CommentSheet({required this.book});

  final BookSummary book;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> comments = state.commentsFor(widget.book.id);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(
          LrSpacing.l, LrSpacing.l, LrSpacing.l, LrSpacing.xl),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('《${widget.book.title}》的评论', style: text.titleMedium),
            const SizedBox(height: LrSpacing.m),
            Expanded(
              child: comments.isEmpty
                  ? Text('还没有评论，写下第一条吧。', style: text.bodySmall)
                  : ListView.separated(
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int i) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.chat_bubble_outline, size: 18),
                        title: Text(comments[i], style: text.bodyMedium),
                      ),
                    ),
            ),
            const SizedBox(height: LrSpacing.s),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '写点什么…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: LrSpacing.s),
                FilledButton(
                  onPressed: () {
                    final bool ok =
                        state.addComment(widget.book.id, _controller.text);
                    if (!ok) return;
                    _controller.clear();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('评论已保存')),
                    );
                  },
                  child: const Text('发送'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _DetailBlock { progress, toc, synopsis, excerpt, info }

class _TocEntry extends StatelessWidget {
  const _TocEntry({required this.count, required this.onOpen});

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => GlassPanel(
        child: Row(
          children: <Widget>[
            const Icon(Icons.list_alt_outlined, size: 20),
            const SizedBox(width: LrSpacing.xs),
            Expanded(
              child: Text(context.tArgs('uiTotalChapters', <Object?>[count]),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            TextButton(
                onPressed: onOpen, child: Text(context.t('uiTableOfContents'))),
          ],
        ),
      );
}
