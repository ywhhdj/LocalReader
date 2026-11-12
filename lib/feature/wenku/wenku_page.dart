import 'package:Local_reader/core/common/design_tokens.dart';
import 'package:Local_reader/core/ui/components/glass/Page.dart';
import 'package:flutter/material.dart';

import 'package:Local_reader/core/ui/components/book/book_cover_card.dart';
import 'package:Local_reader/feature/wenku/wenku_3d_shelf.dart';
import 'package:Local_reader/feature/wenku/wenku_library_spec.dart';

/// 轻小说文库页
class WenkuLibraryPage extends StatelessWidget {
  const WenkuLibraryPage({
    super.key,
    required this.state,
    required this.shelfBooks,
    required this.rankBooks,
    required this.recommended,
    required this.onSearch,
    required this.onOpenBook,
    required this.onGoCollect,
    required this.onRefresh,
    required this.onExtract,
    this.topActions = const <Widget>[],
    this.onOpenDetail,
  });

  final WenkuLibraryState state;
  final List<ShelfSpineBook> shelfBooks;
  final Map<RankKind, List<CoverBook>> rankBooks;
  final List<CoverBook> recommended;
  final VoidCallback onSearch;
  final ValueChanged<CoverBook> onOpenBook;
  final VoidCallback onGoCollect;
  final VoidCallback onRefresh;
  final ValueChanged<ShelfSpineBook> onExtract;
  final List<Widget> topActions;
  final ValueChanged<ShelfSpineBook>? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LrPage.slivers(
        // ── 顶部：吸顶 + 毛玻璃 ──
        header: PageScrollHeader(
          title: '轻小说文库',
          subtitle: '01/Wenku8',
          actions: <HeaderAction>[
            HeaderAction(
              icon: Icons.search,
              tooltip: '搜索轻小说文库',
              onTap: onSearch,
            ),
          ],
        ),
        // ── 其余内容：保持原有 slivers，原封不动 ──
        rawSlivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Wenku3dShelf(
                books: shelfBooks,
                topActions: topActions,
                onExtract: onExtract,
                onSelectionChanged: onOpenDetail,
              ),
            ),
          ),

          if (state.loading)
            const SliverToBoxAdapter(child: _LoadingStrip())
          else ...<Widget>[
            if (state.rateLimited)
              const SliverToBoxAdapter(
                child: _NoticeCard(text: '请求太频繁，正在按 Retry-After 退避'),
              ),
            if (state.upstreamChanged)
              const SliverToBoxAdapter(
                child: _NoticeCard(text: '来源结构已变化，请前往官网查看'),
              ),
            // 提示页（含「本站正式关闭」类公告）只当作非书目，不推断停服。
            if (state.noticeSeen)
              const SliverToBoxAdapter(
                child: _NoticeCard(text: '当前页面不是书目内容，已跳过'),
              ),
            for (final RankKind kind in kRankingOrder)
              SliverToBoxAdapter(
                child: _RankingRow(
                  kind: kind,
                  books: rankBooks[kind] ?? const <CoverBook>[],
                  onOpen: onOpenBook,
                  onMore: onRefresh,
                ),
              ),
            SliverToBoxAdapter(
              child: _RankingRow(
                kind: null,
                books: recommended,
                onOpen: onOpenBook,
                onMore: onRefresh,
                titleOverride: '推荐喜欢',
              ),
            )
          ],

          // footer：底部间距改由 LrPage 的 bottomInset 统一处理，
          // 这里只留文字下方的少量呼吸。
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                '在线列表来自 Wenku8；不提供下架内容的访问，不打包整本。',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.kind,
    required this.books,
    required this.onOpen,
    required this.onMore,
    this.titleOverride,
  });

  final RankKind? kind;
  final List<CoverBook> books;
  final ValueChanged<CoverBook> onOpen;
  final VoidCallback onMore;
  final String? titleOverride;

  String get _title => titleOverride ?? _labelOf(kind!);

  static String _labelOf(RankKind k) {
    switch (k) {
      case RankKind.daily:
        return '日榜';
      case RankKind.weekly:
        return '周榜';
      case RankKind.monthly:
        return '月榜';
      case RankKind.all:
        return '总榜';
      case RankKind.category:
        return '分类榜';
      case RankKind.imprint:
        return '出版文库';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: LrSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LrSpacing.xs),
            child: Row(
              children: <Widget>[
                Text(_title, style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton(onPressed: onMore, child: const Text('更多 →')),
              ],
            ),
          ),
          // 横向懒加载：固定高度 + cacheExtent，避免嵌进纵向视口时无界约束。
          SizedBox(
            height: 232,
            child: books.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: LrSpacing.xs),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('暂无数据',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5))),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    cacheExtent: 480,
                    padding: const EdgeInsets.symmetric(horizontal: LrSpacing.xs),
                    itemCount: books.length,
                    itemBuilder: (BuildContext context, int i) => SizedBox(
                      width: 132,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: BookCoverCard(
                          book: books[i],
                          onClick: () => onOpen(books[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(minHeight: 2),
      );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Material(
          color: Theme.of(context)
              .colorScheme
              .surfaceVariant
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      );
}