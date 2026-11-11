import 'package:flutter/material.dart';

import 'package:Local_reader/core/ui/components/book/book_cover_card.dart';
import 'package:Local_reader/core/model/navigation_spec.dart';

/// 一条 rail 里的最小书目投影；映射成 CoverBook 后交给统一封面卡。
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
      );
}


/// 固定高度 + 横向 ListView.builder（懒加载），避免嵌进纵向视口时无界约束。
/// 卡片统一使用 BookCoverCard：封面图 / 渐变占位 + 类型角标 + 进度条 + 书名 + 描述。
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
            height: 236,
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
                        width: 132,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: BookCoverCard(
                            book: item.toCoverBook(),
                            onClick: () => onOpen(item),
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
