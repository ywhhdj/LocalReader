import 'package:flutter/material.dart';
import 'package:local_reader/core/stats/reading_stats.dart';

import '../../core/data/book_repository.dart';
import '../../core/data/demo_document.dart';
import '../../core/models/book_document.dart';
import '../../core/router/route_args.dart';
import '../../core/stats/excerpt_query.dart';
import '../../core/stats/excerpt_title_lookup.dart';
import '../../core/state/app_scope.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass.dart';
import '../../core/content/lr_localizations.dart';

/// 书籍详情页：导航目标由 app 层注入，页面自己不构造路由。
/// 数据来源是 AppScope.effective(book)，与书架、目录、阅读器看到同一份编辑结果。
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

  /// 由 app 层注入：只回传 bookId，本页面不构造路由、不 import 摘录 feature。
  final OpenBookExcerpts onOpenBookExcerpts;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final BookSummary b = state.effective(book);
    final BookDocument document = DemoDocumentFactory.from(b);
    final int resume = DemoDocumentFactory.resumeChapter(b);
    // 唯一查询出口：与摘录管理页读同一份 AppState.excerpts，按 bookId 过滤。
    // 每次 build 重取，阅读器新摘一条后回到详情立刻能看到条数变化。
    // 书名 lookup 与摘录管理页同源，保证两页的排序 / 分组口径不分裂。
    final ExcerptTitleLookup titles = ExcerptTitleLookup(
      (String id) => state.resolveBook(id)?.title,
    );
    final List<Excerpt> bookExcerpts = ExcerptQuery.apply(
      excerpts: state.excerpts,
      filter: ExcerptFilter(bookId: b.id),
      titles: titles,
    );
    final TextTheme text = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final SeasonPalette palette =
        Theme.of(context).extension<LrSeasonTheme>()?.palette ??
            SeasonPalette.all[isDark ? SeasonStyle.winter : SeasonStyle.paper]!;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF15171C) : palette.seed,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        actions: <Widget>[
          IconButton(
            tooltip: state.isFavorite(b.id)
                ? context.t('uiRemoveFavorite')
                : context.t('uiFavoriteThisBook'),
            icon: Icon(state.isFavorite(b.id) ? Icons.star : Icons.star_border),
            onPressed: () {
              final bool added = state.toggleFavorite(b.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(added
                        ? context.t('uiAddedToFavorites')
                        : context.t('uiRemovedFromFavorites'))),
              );
            },
          ),
          IconButton(
            tooltip: context.t('uiEditBookInfo'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _openEditor(context, b),
          ),
        ],
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
              LrSpacing.l, LrSpacing.s, LrSpacing.l, LrSpacing.xl),
          children: <Widget>[
            _CoverHero(book: b, palette: palette),
            const SizedBox(height: LrSpacing.l),
            _ProgressCard(book: b),
            const SizedBox(height: LrSpacing.l),
            _ChapterPreview(
              book: b,
              chapters: document.chapters,
              resume: resume,
              onOpenAll: () => _openToc(context, b, resume),
              onChapterTap: (int i) => onOpenReader(b, i),
            ),
            const SizedBox(height: LrSpacing.l),
            _BookExcerptCard(
              book: b,
              excerpts: bookExcerpts,
              // 书名在详情页是可编辑的覆盖层，筛选值必须是稳定的 id。
              onOpen: () => onOpenBookExcerpts(b.id),
            ),
            const SizedBox(height: LrSpacing.l),
            _SourceNote(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum:
            const EdgeInsets.fromLTRB(LrSpacing.l, 0, LrSpacing.l, LrSpacing.m),
        child: GlassPanel(
          borderRadius: LrRadius.pill,
          padding: const EdgeInsets.symmetric(
              horizontal: LrSpacing.s, vertical: LrSpacing.s),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _openToc(context, b, resume),
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: Text(context.t('uiTableOfContents'),
                      style: text.labelLarge),
                ),
              ),
              const SizedBox(width: LrSpacing.s),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => onOpenReader(b, resume),
                  icon: const Icon(Icons.auto_stories_outlined, size: 18),
                  label: Text(
                      b.progress > 0
                          ? context.t('uiContinueReading')
                          : context.t('uiStartReading'),
                      style: text.labelLarge),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 目录页 pop 出章节序号；由详情页决定新建阅读器，避免页面栈里堆两个阅读器。
  Future<void> _openToc(
      BuildContext context, BookSummary b, int current) async {
    final int? picked = await onOpenToc(b, current);
    if (picked == null) return;
    if (!context.mounted) return;
    onOpenReader(b, picked);
  }

  void _openEditor(BuildContext context, BookSummary b) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EditBookSheet(book: b),
      ),
    );
  }
}

class _CoverHero extends StatelessWidget {
  const _CoverHero({required this.book, required this.palette});

  final BookSummary book;
  final SeasonPalette palette;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 立体封面：书脊渐变高光 + 竖排衬线书名 + 书页侧边 + 层板投影
          Container(
            width: 116,
            height: 172,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(LrRadius.spine),
                right: Radius.circular(3),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(6, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(LrRadius.spine)),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: <Color>[
                          book.spineColor.withValues(alpha: 0.74),
                          book.spineColor,
                          Color.lerp(book.spineColor, Colors.black, 0.3)!,
                        ],
                        stops: const <double>[0, 0.3, 1],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 18, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Wrap(
                            direction: Axis.vertical,
                            spacing: 3,
                            runSpacing: 8,
                            children: book.title.runes
                                .take(8)
                                .map<Widget>((int r) => Text(
                                      String.fromCharCode(r),
                                      style: TextStyle(
                                          fontFamily: 'Noto Serif SC',
                                          fontFamilyFallback: const <String>[
                                            'Songti SC',
                                            'SimSun',
                                            'serif'
                                          ],
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white
                                              .withValues(alpha: 0.95)),
                                    ))
                                .toList(),
                          ),
                        ),
                        Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 7,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3)),
                    gradient: LinearGradient(colors: <Color>[
                      const Color(0xFFEFE9DC),
                      Color.lerp(const Color(0xFFEFE9DC), Colors.black, 0.18)!,
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: LrSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(book.title, style: text.headlineMedium),
                const SizedBox(height: LrSpacing.xs),
                Text(book.author, style: text.bodyMedium),
                const SizedBox(height: LrSpacing.m),
                Wrap(
                  spacing: LrSpacing.s,
                  runSpacing: LrSpacing.s,
                  children: <Widget>[
                    _Chip(label: book.format, icon: Icons.description_outlined),
                    _Chip(label: book.encoding, icon: Icons.translate_outlined),
                    _Chip(
                        label: book.volumeOrder == 0
                            ? context.t('uiNoVolume')
                            : context
                                .tArgs('uiVolume', <Object?>[book.volumeOrder]),
                        icon: Icons.layers_outlined),
                  ],
                ),
                const SizedBox(height: LrSpacing.m),
                Text(context.tArgs('uiLocalLibrary', <Object?>[book.shelf]),
                    style: text.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: LrSpacing.s, vertical: LrSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(LrRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: LrSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.book});
  final BookSummary book;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final int percent = (book.progress * 100).round();
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(context.t('uiReadingProgress'), style: text.titleLarge),
              const Spacer(),
              Text('$percent%', style: text.titleMedium),
            ],
          ),
          const SizedBox(height: LrSpacing.m),
          ClipRRect(
            borderRadius: BorderRadius.circular(LrRadius.pill),
            child: LinearProgressIndicator(
              value: book.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          const SizedBox(height: LrSpacing.s),
          Text(
            book.progress > 0
                ? context.tArgs('uiChaptersSampleData',
                    <Object?>[DemoDocumentFactory.resumeChapter(book) + 1])
                : context.t('uiNotStartedYet'),
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ChapterPreview extends StatelessWidget {
  const _ChapterPreview({
    required this.book,
    required this.chapters,
    required this.resume,
    required this.onOpenAll,
    required this.onChapterTap,
  });

  final BookSummary book;
  final List<Chapter> chapters;
  final int resume;
  final VoidCallback onOpenAll;
  final ValueChanged<int> onChapterTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(context.t('uiContents'), style: text.titleLarge),
              const SizedBox(width: LrSpacing.s),
              Text(context.tArgs('uiTotalChapters', <Object?>[chapters.length]),
                  style: text.labelSmall),
              const Spacer(),
              GestureDetector(
                onTap: onOpenAll,
                child: Text(context.t('uiViewAll'),
                    style: text.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: LrSpacing.s),
          ...chapters
              .take(3)
              .toList()
              .asMap()
              .entries
              .map<Widget>((MapEntry<int, Chapter> e) {
            final int i = e.key;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Text(
                '${i + 1}'.padLeft(2, '0'),
                style: text.titleMedium?.copyWith(
                  fontFamily: 'Noto Serif SC',
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.7),
                ),
              ),
              title: Text(e.value.title, style: text.bodyMedium),
              trailing: i == resume
                  ? Text(context.t('uiLastRead'), style: text.labelSmall)
                  : const Icon(Icons.chevron_right, size: 16),
              onTap: () => onChapterTap(i),
            );
          }),
        ],
      ),
    );
  }
}

/// 详情页里的「这本书的摘录」入口：显示条数与最近一条，深链只回传 bookId。
///
/// 零摘录时按钮**仍然可用**——跳过去会看到摘录管理页的专属空状态与引导，
/// 而不是一个点了没反应的禁用按钮。
class _BookExcerptCard extends StatelessWidget {
  const _BookExcerptCard({
    required this.book,
    required this.excerpts,
    required this.onOpen,
  });

  final BookSummary book;
  final List<Excerpt> excerpts;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = Theme.of(context).colorScheme.primary;
    final Excerpt? latest = excerpts.isEmpty ? null : excerpts.first;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.format_quote_outlined, size: 18, color: accent),
              const SizedBox(width: LrSpacing.s),
              Expanded(
                child:
                    Text(context.t('bookExcerptTitle'), style: text.titleLarge),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: LrSpacing.s, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(LrRadius.pill),
                ),
                child: Text(
                    context.tArgs('uiItems2', <Object?>[excerpts.length]),
                    style: text.labelSmall),
              ),
            ],
          ),
          const SizedBox(height: LrSpacing.m),
          if (latest == null)
            Text(context.t('bookExcerptEmptyBody'), style: text.bodySmall)
          else ...<Widget>[
            Text(
              '《${book.title}》 · ${latest.chapterTitle}',
              style: text.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: LrSpacing.xs),
            Text(
              latest.text,
              style: text.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: LrSpacing.m),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(context.t('bookExcerptStaticNote'),
                    style: text.labelSmall),
              ),
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_outward, size: 16),
                label: Text(context.t('uiViewAll')),
              ),
            ],
          ),
          const SizedBox(height: LrSpacing.xs),
          Text(context.t('excerptLocalNote'), style: text.labelSmall),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.book,
    required this.chapterCount,
    this.episodeCount,
    this.comicPageCount = 0,
  });
  final BookSummary book;
  final int chapterCount;
  final int? episodeCount;
  final int comicPageCount;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(context.t('uiBookInfo'), style: text.titleLarge),
          const SizedBox(height: LrSpacing.m),
          _InfoRow(
              label: context.t('uiSource'),
              value: context.t('uiImportedLocally'),
              text: text),
          _InfoRow(
              label: context.t('uiFormat'),
              value: '${book.format} · ${book.encoding}',
              text: text),
          _InfoRow(
            label: episodeCount == null
                ? context.t('uiChapters2')
                : context.t('uiEpisodes'),
            value: episodeCount == null
                ? context.tArgs('uiChaptersN1', <Object?>[
                    chapterCount,
                    book.volumeOrder == 0
                        ? lrText('uiNoVolume')
                        : lrTextArgs('uiVolumeN', <Object?>[book.volumeOrder])
                  ])
                : context.tArgs(
                    'uiEpisodesPages', <Object?>[episodeCount, comicPageCount]),
            text: text,
          ),
          _InfoRow(
              label: context.t('uiAuthorization'),
              value: context.t('uiSystemFilePickerDirectoryAuthorization'),
              text: text),
          const SizedBox(height: LrSpacing.s),
          Text(
            '${context.t('archiveNotice')} ' + context.t('uiScope'),
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.label, required this.value, required this.text});
  final String label;
  final String value;
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: LrSpacing.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: 56, child: Text(label, style: text.labelSmall)),
            Expanded(child: Text(value, style: text.bodyMedium)),
          ],
        ),
      );
}

class _SourceNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.gavel_outlined,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: LrSpacing.s),
              Text(context.t('uiAboutContent'), style: text.titleMedium),
            ],
          ),
          const SizedBox(height: LrSpacing.s),
          Text('${context.t('appDisclaimer')}\n${context.t('contentRights')}',
              style: text.bodySmall),
        ],
      ),
    );
  }
}

/// 编辑面板：书名 / 作者 / 封面色 / 卷序，写回 AppState 覆盖层。
/// 静态交付模式下仅存内存，重启后恢复演示数据——面板里明确写出这一点，不伪装成持久化。
class _EditBookSheet extends StatefulWidget {
  const _EditBookSheet({required this.book});
  final BookSummary book;

  @override
  State<_EditBookSheet> createState() => _EditBookSheetState();
}

class _EditBookSheetState extends State<_EditBookSheet> {
  late final TextEditingController _title;
  late final TextEditingController _author;
  late Color _color;
  late int _volume;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.book.title);
    _author = TextEditingController(text: widget.book.author);
    _color = widget.book.spineColor;
    _volume = widget.book.volumeOrder;
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<Color> choices = <Color>[
      widget.book.spineColor,
      ...SeasonPalette.all.values.map<Color>((SeasonPalette p) => p.accent),
    ];

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(
          LrSpacing.l, LrSpacing.l, LrSpacing.l, LrSpacing.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(context.t('uiEditBookInfo'), style: text.headlineMedium),
            const SizedBox(height: LrSpacing.m),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                  labelText: context.t('uiTitle'),
                  border: OutlineInputBorder()),
              style: text.bodyMedium,
            ),
            const SizedBox(height: LrSpacing.m),
            TextField(
              controller: _author,
              decoration: InputDecoration(
                  labelText: context.t('uiAuthor'),
                  border: OutlineInputBorder()),
              style: text.bodyMedium,
            ),
            const SizedBox(height: LrSpacing.m),
            Text(context.t('uiCoverColor'), style: text.titleMedium),
            const SizedBox(height: LrSpacing.s),
            Wrap(
              spacing: LrSpacing.s,
              children: <Widget>[
                for (final Color c in choices)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: c,
                      child: _color == c
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: LrSpacing.m),
            Row(
              children: <Widget>[
                Text(context.t('uiVolumeOrder'), style: text.titleMedium),
                const Spacer(),
                DropdownButton<int>(
                  value: _volume,
                  items: <DropdownMenuItem<int>>[
                    for (int i = 0; i <= 6; i++)
                      DropdownMenuItem<int>(
                          value: i,
                          child: Text(i == 0
                              ? context.t('uiNoVolume')
                              : context.tArgs('uiVolume2', <Object?>[i]))),
                  ],
                  onChanged: (int? v) => setState(() => _volume = v ?? 0),
                ),
              ],
            ),
            const SizedBox(height: LrSpacing.s),
            Text(context.t('uiStaticDemoSaveSampleData'),
                style: text.bodySmall),
            const SizedBox(height: LrSpacing.m),
            Row(
              children: <Widget>[
                Expanded(
                    child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.t('uiCancel')))),
                const SizedBox(width: LrSpacing.s),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(context.t('uiSave')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lrText('uiTitleCannotBeEmpty'))));
      return;
    }
    AppScope.of(context).updateBook(
      widget.book.id,
      title: title,
      author: _author.text.trim(),
      spineColor: _color,
      volumeOrder: _volume,
    );
    Navigator.pop(context);
  }
}
