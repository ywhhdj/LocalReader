import 'package:flutter/material.dart';

import '../../core/comic/comic_toc.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/glass.dart';
import '../../core/content/lr_localizations.dart';

/// 漫画话集目录：列出识别到的话，点选回传该话首页的 pageIndex。
///
/// 与小说目录页同构：只回一个序号，由调用方决定怎么跳，
/// 不往页面栈里再压一个阅读器。
class ComicTocSheet extends StatelessWidget {
  const ComicTocSheet({
    super.key,
    required this.toc,
    required this.currentPage,
  });

  final ComicToc toc;
  final int currentPage;

  static Future<int?> open(
    BuildContext context, {
    required ComicToc toc,
    required int currentPage,
  }) =>
      showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext ctx) =>
            ComicTocSheet(toc: toc, currentPage: currentPage),
      );

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final int? currentEpisode = toc.episodeIndexForPage(currentPage);

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(
          LrSpacing.l, LrSpacing.l, LrSpacing.l, LrSpacing.xl),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(context.t('uiEpisodeList'), style: text.headlineMedium),
                  const Spacer(),
                  Text(
                      context.tArgs('uiEpisodesPages2',
                          <Object?>[toc.episodeCount, toc.pageCount]),
                      style: text.labelSmall),
                ],
              ),
              const SizedBox(height: LrSpacing.s),
              Text(
                toc.recognitionRate < 1
                    ? context.tArgs('uiRecognitionRate',
                            <Object?>[(toc.recognitionRate * 100).round()]) +
                        context.tArgs('uiUnrecognizedPagesEpisodes',
                            <Object?>[toc.pageCount - toc.recognizedPages])
                    : context.t('uiAllPagesAreGroupedIntoEpisodes'),
                style: text.labelSmall,
              ),
              const SizedBox(height: LrSpacing.m),
              ...toc.episodes.asMap().entries.map<Widget>(
                (MapEntry<int, ComicEpisode> e) {
                  final int i = e.key;
                  final ComicEpisode ep = e.value;
                  final bool current = i == currentEpisode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: LrSpacing.s),
                    child: _EpisodeTile(
                      episode: ep,
                      current: current,
                      onTap: () => Navigator.of(context).pop(ep.pageStart),
                    ),
                  );
                },
              ),
              const SizedBox(height: LrSpacing.s),
              GlassPanel(
                child: Text(context.t('comicTocNote'), style: text.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.current,
    required this.onTap,
  });

  final ComicEpisode episode;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.all(LrSpacing.m),
        child: Row(
          children: <Widget>[
            Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                color: current ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(LrRadius.pill),
              ),
            ),
            const SizedBox(width: LrSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          episode.label,
                          style: text.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (current)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: LrSpacing.s, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(LrRadius.pill),
                          ),
                          child: Text(context.t('uiCurrent2'),
                              style: text.labelSmall),
                        ),
                      if (!episode.recognized)
                        Padding(
                          padding: const EdgeInsets.only(left: LrSpacing.s),
                          child: Text(context.t('uiUnrecognized'),
                              style: text.labelSmall),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tArgs('uiPages2', <Object?>[
                          episode.pageRangeLabel,
                          episode.pageCount
                        ]) +
                        context.tArgs('uiPhrase011', <Object?>[
                          episode.kind == ComicEpisodeKind.special
                              ? lrText('uiSpecialEpisodePrefix')
                              : ''
                        ]),
                    style: text.labelSmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
