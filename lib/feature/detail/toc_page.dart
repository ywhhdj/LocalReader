import 'package:flutter/material.dart';

import '../../domain/repositories/book_repository.dart';
import '../../core/model/fixtures/demo_document.dart';
import '../../core/model/book_document.dart';
import '../../assembly/app_scope.dart';
import '../../core/common/design_tokens.dart';
import '../../core/ui/theme/glass_theme.dart';
import '../../core/ui/components/glass/Nav.dart';
import '../../l10n/lr_localizations.dart';

/// 章节目录：只负责「选中哪一章」，把序号 pop 出去。
/// 详情页接到后新建阅读器；阅读器接到后切换章节。
/// 这样页面栈里永远不会堆两个阅读器，也不需要在目录页里 import 路由表。
class TocPage extends StatefulWidget {
  const TocPage({
    super.key,
    required this.book,
    this.currentChapter = 0,
  });

  final BookSummary book;
  final int currentChapter;

  @override
  State<TocPage> createState() => _TocPageState();
}

class _TocPageState extends State<TocPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final BookSummary book = state.effective(widget.book);
    final BookDocument document = DemoDocumentFactory.from(book);
    final TextTheme text = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final SeasonPalette palette =
        Theme.of(context).extension<LrSeasonTheme>()?.palette ??
            SeasonPalette.all[isDark ? SeasonStyle.winter : SeasonStyle.paper]!;

    final List<MapEntry<int, Chapter>> visible = _filtered(document.chapters);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF15171C) : palette.seed,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(context.tArgs('uiContents2', <Object?>[book.title])),
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
              LrSpacing.l, LrSpacing.xs, LrSpacing.l, LrSpacing.xxl),
          children: <Widget>[
            GlassPanel(
              borderRadius: LrRadius.pill,
              padding: const EdgeInsets.symmetric(
                  horizontal: LrSpacing.m, vertical: LrSpacing.xs),
              child: Row(
                children: <Widget>[
                  Icon(Icons.search, size: 19, color: text.bodySmall?.color),
                  const SizedBox(width: LrSpacing.xs),
                  Expanded(
                    child: TextField(
                      onChanged: (String v) =>
                          setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: context.t('uiSearchChapterTitles'),
                        hintStyle: text.bodyMedium,
                      ),
                      style: text.bodyMedium,
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _query = ''),
                      child: const Icon(Icons.close, size: 17),
                    ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.m),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LrSpacing.xs),
              child: Row(
                children: <Widget>[
                  Text(
                    context.tArgs('uiTotalChapters2',
                            <Object?>[document.chapters.length]) +
                        context.tArgs('uiPhrase012', <Object?>[
                          book.volumeOrder == 0
                              ? ''
                              : lrTextArgs('uiVolumePrefixN',
                                  <Object?>[book.volumeOrder])
                        ]),
                    style: text.labelSmall,
                  ),
                  const Spacer(),
                  Text(context.t('uiTapAChapterToJump'),
                      style: text.labelSmall),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.xs),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: LrSpacing.xl),
                child: Center(
                    child: Text(context.t('uiNoMatchingChapters'),
                        style: text.bodyMedium)),
              )
            else
              ...visible.map<Widget>((MapEntry<int, Chapter> e) => Padding(
                    padding: const EdgeInsets.only(bottom: LrSpacing.xs),
                    child: _TocTile(
                      chapter: e.value,
                      index: e.key,
                      isCurrent: e.key == widget.currentChapter,
                      onTap: () => Navigator.of(context).pop<int>(e.key),
                    ),
                  )),
            const SizedBox(height: LrSpacing.l),
            GlassPanel(
              child: Text(
                context.t('uiContentsBodyTextBookdocumentChapters') +
                    context.t('uiCurrentSampleDataTocentryChapters'),
                style: text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<int, Chapter>> _filtered(List<Chapter> chapters) {
    final List<MapEntry<int, Chapter>> indexed = <MapEntry<int, Chapter>>[
      for (int i = 0; i < chapters.length; i++)
        MapEntry<int, Chapter>(i, chapters[i]),
    ];
    if (_query.isEmpty) return indexed;
    return indexed
        .where((MapEntry<int, Chapter> e) => e.value.title.contains(_query))
        .toList();
  }
}

class _TocTile extends StatelessWidget {
  const _TocTile({
    required this.chapter,
    required this.index,
    required this.isCurrent,
    required this.onTap,
  });

  final Chapter chapter;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        borderRadius: LrRadius.card,
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.m, vertical: LrSpacing.m),
        child: Row(
          children: <Widget>[
            Text(
              '${index + 1}'.padLeft(2, '0'),
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontFamilyFallback: const <String>[
                  'Songti SC',
                  'SimSun',
                  'serif'
                ],
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isCurrent
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(width: LrSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    chapter.title,
                    style: text.titleMedium?.copyWith(
                      color: isCurrent ? scheme.primary : null,
                      fontWeight: isCurrent ? FontWeight.w700 : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                      context.tArgs('uiItemscontentBodyText',
                          <Object?>[chapter.blocks.length]),
                      style: text.labelSmall),
                ],
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: LrSpacing.xs, vertical: LrSpacing.xs),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(LrRadius.pill),
                ),
                child: Text(context.t('uiCurrentlyReading'),
                    style: text.labelSmall?.copyWith(color: scheme.primary)),
              ),
            const SizedBox(width: LrSpacing.xs),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
