import 'package:Local_reader/core/model/book_document.dart';
import 'package:Local_reader/core/ui/components/glass/Page.dart';
import 'package:flutter/material.dart';

import '../../core/model/book_origin.dart';
import '../../domain/repositories/book_repository.dart';
import '../../core/model/fixtures/demo_document.dart';
import '../../assembly/route_args.dart';
import '../../assembly/app_scope.dart';
import '../../core/model/stats/excerpt_query.dart';
import '../../core/model/stats/excerpt_title_lookup.dart';
import '../../l10n/lr_localizations.dart';
import 'detail_sections.dart';
import '../../core/ui/components/glass/Nav.dart';
import '../../core/common/design_tokens.dart';
import '../../core/ui/theme/glass_theme.dart';

/// 书籍详情页
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
    final bool isCloud = BookOriginResolver.isCloud(b);
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final SeasonPalette palette =
        Theme.of(context).extension<LrSeasonTheme>()?.palette ??
            SeasonPalette.all[isDark ? SeasonStyle.winter : SeasonStyle.paper]!;

    final List<_DetailBlock> blocks = <_DetailBlock>[
      if (b.progress > 0) _DetailBlock.progress,
      _DetailBlock.toc,
      _DetailBlock.synopsis,
      _DetailBlock.excerpt,
      _DetailBlock.note,
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF15171C) : palette.seed,
      appBar: DetailTopBar(
        isCloud: isCloud,
        onCloudCache: () => _hint(context, context.t('detailStaticActionNote')),
        onDelete: () => _hint(context, context.t('detailStaticActionNote')),
        onResetProgress: () =>
            _hint(context, context.t('detailStaticActionNote')),
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
        child: LrPage.builder(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DetailCoverInfo(
                book: b,
                isCloud: isCloud,
                onAuthorTap: () => _openEditor(context, b),
                onRetryCache: () =>
                    _hint(context, context.t('detailStaticActionNote')),
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
            return GlassPanel(
              child: Text(context.t('detailStaticActionNote'),
                  style: Theme.of(context).textTheme.labelSmall),
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
            final bool added = state.toggleFavorite(b.id);
            _hint(
                context,
                added
                    ? context.t('uiAddedToFavorites')
                    : context.t('uiRemovedFromFavorites'));
          },
          onSecondary: isCloud
              ? () => _hint(context, context.t('detailStaticActionNote'))
              : () => _openEditor(context, b),
          onRead: () => onOpenReader(b, resume),
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
          },
        ),
      ),
    );
  }

  void _hint(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 历史契约里的卡片名保留：组件本体在 ui/components/detail_sections.dart。
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

enum _DetailBlock { progress, toc, synopsis, excerpt, note }

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
