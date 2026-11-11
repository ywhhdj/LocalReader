import 'package:Local_reader/core/model/stats/reading_stats.dart';
import 'package:Local_reader/core/ui/components/glass/Page.dart';
import 'package:flutter/material.dart';

import '../../../assembly/app_navigation.dart';
import '../../../assembly/app_scope.dart';
import '../../../core/model/stats/excerpt_query.dart';
import '../../../core/model/stats/excerpt_title_lookup.dart';
import '../../../l10n/lr_localizations.dart';
import '../../../core/ui/components/section_card.dart';
import '../../../core/common/design_tokens.dart';

/// 书签页：我的页点「书签」才打开。
/// 列表走 `LrPage.builder` 懒加载，不一次性构造全部卡片。
class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ExcerptTitleLookup titles = ExcerptTitleLookup(
      (String id) => state.resolveBook(id)?.title,
    );
    final List<Excerpt> entries = ExcerptQuery.apply(
      excerpts: state.excerpts,
      filter: const ExcerptFilter(),
      titles: titles,
    );
    final AppNavigation nav = AppNavigationScope.of(context);
    return LrPage.builder(
      header: PageScrollHeader(
        title: context.t('bookmarksHeroTitle'),
        subtitle: context.t('bookmarksHeroSubtitle'),
        actions: <HeaderAction>[
          HeaderAction(
            icon: Icons.arrow_outward,
            tooltip: context.t('uiViewAll'),
            onTap: () => nav.onOpenExcerptLibrary('', null),
          ),
        ],
      ),
      itemCount: entries.isEmpty ? 2 : entries.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return SectionCard(
            title: context.t('bookExcerptTitle'),
            child: Text(context.tArgs('uiItems2', <Object?>[entries.length]),
                style: Theme.of(context).textTheme.bodySmall),
          );
        }
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: LrSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.t('bookmarksEmptyTitle'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: LrSpacing.xs),
                Text(context.t('bookmarksEmptyBody'),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }
        final Excerpt e = entries[index - 1];
        return _BookmarkTile(
          title: titles.titleOf(e),
          chapterTitle: e.chapterTitle,
          text: e.text,
          onTap: () => nav.onOpenExcerptLibrary('', e.bookId),
        );
      },
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({
    required this.title,
    required this.chapterTitle,
    required this.text,
    required this.onTap,
  });

  final String title;
  final String chapterTitle;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LrSpacing.m),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.bookmark_outline, size: 20),
        title: Text('$title · $chapterTitle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium),
        subtitle: Text(text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }
}
