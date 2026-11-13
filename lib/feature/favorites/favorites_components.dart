import 'package:flutter/material.dart';

import 'package:Local_reader/core/ui/components/book/book_cover_card.dart';
import 'package:Local_reader/core/model/navigation_spec.dart';

/// 一条 rail 里的最小书目投影；映射成 CoverBook 后交给统一封面卡。
/// 新增 origin / progressText：收藏页的书也能显示「本地 / 云端」角标与 LR-/WK- 编号。
class RailItem {
  const RailItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.author = '',
    this.coverPath = '',
    this.coverColor = const Color(0xFF39404B),
    this.progress = 0,
    this.updatedAt = 0,
    this.origin = CoverBookOrigin.local,
    this.progressText = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final BookKind kind;
  final String author;
  final String coverPath;
  final Color coverColor;
  final double progress;
  final int updatedAt;
  final CoverBookOrigin origin;
  final String progressText;

  CoverBook toCoverBook() => CoverBook(
        id: id,
        title: title,
        author: author,
        subtitle: subtitle,
        coverPath: coverPath,
        coverColor: coverColor,
        progress: progress,
        type:
            kind == BookKind.comic ? CoverBookType.comic : CoverBookType.novel,
        origin: origin,
        progressText: progressText,
      );
}

/// 固定高度 + 横向 ListView.builder（懒加载），避免嵌进纵向视口时无界约束。
/// 卡片统一使用 BookCoverCard：封面图 / 渐变占位 + 来源角标 + 进度条 + 书名 + 描述。
class RailSection extends StatelessWidget {
  const RailSection({
    required this.title,
    required this.items,
    required this.onOpen,
    required this.emptyHint,
    this.trailing,
    this.onEmptyAction,
    this.emptyActionLabel = '',
  });

  final String title;
  final List<RailItem> items;
  final ValueChanged<RailItem> onOpen;
  final String emptyHint;
  final Widget? trailing;
  final VoidCallback? onEmptyAction;
  final String emptyActionLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            // 130 宽封面按 0.7 比例约 186 高，再加标题 / 作者 / 进度约 76，
            // 250 会溢出 12~15px；卡片内部另有 FittedBox 兜底。
            height: 268,
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: <Widget>[
                        Text(emptyHint, style: theme.textTheme.bodySmall),
                        const Spacer(),
                        if (onEmptyAction != null)
                          TextButton(
                            onPressed: onEmptyAction,
                            child: Text(emptyActionLabel),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    cacheExtent: 480,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int i) {
                      final RailItem item = items[i];
                      return SizedBox(
                        width: 140,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: BookCoverCard(
                            book: item.toCoverBook(),
                            onClick: () => onOpen(item),
                            onMore: () => onOpen(item),
                            onLongPress: () => onOpen(item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
