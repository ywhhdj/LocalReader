import 'dart:io' show File;

import 'package:flutter/material.dart';

enum CoverBookType { novel, comic }

/// 卡片的最小投影：本地 BookSummary / 云端 Wenku8Book / 收藏 RailItem 都映射成它，
/// 卡片组件因此不反向依赖任何 feature 或 data 模型。
class CoverBook {
  const CoverBook({
    required this.id,
    required this.title,
    this.author = '',
    this.subtitle = '',
    this.coverPath = '',
    this.coverUrl = '',
    this.coverColor = const Color(0xFF39404B),
    this.progress = 0,
    this.type = CoverBookType.novel,
    this.badgeAdded = false,
  });

  final String id;
  final String title;
  final String author;
  final String subtitle;
  final String coverPath;
  final String coverUrl;

  /// 无封面时用书名首字母 + 渐变占位（对齐 Kotlin PlaceholderCover）。
  final Color coverColor;
  final double progress;
  final CoverBookType type;
  final bool badgeAdded;

  /// 固定采样尺寸 150×220，控制列表快滑时的解码内存。
  /// 对应 Kotlin `.size(150, 220)` + `crossfade(false)`。
  ImageProvider? coverImage() {
    if (coverPath.isNotEmpty) {
      return FileImage(File(coverPath), scale: 1);
    }
    if (coverUrl.isNotEmpty) {
      return NetworkImage(coverUrl);
    }
    return null;
  }
}

/// 统一封面卡片：小说 / 漫画共用。
/// - 固定采样尺寸（cacheWidth/cacheHeight = 150/220），控制内存
/// - 底部进度条（progress > 0 显示）
/// - 右上角类型角标（小说 / 漫画）
/// - 无封面时用书名首字母生成渐变占位
/// - 单击 / 长按（对应 combinedClickable）、选中描边
class BookCoverCard extends StatelessWidget {
  const BookCoverCard({
    super.key,
    required this.book,
    required this.onClick,
    this.onLongPress,
    this.selected = false,
    this.aspectRatio = 0.7,
  });

  final CoverBook book;
  final VoidCallback onClick;
  final VoidCallback? onLongPress;
  final bool selected;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius shape = BorderRadius.circular(10);
    final ImageProvider? image = book.coverImage();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AspectRatio(
          aspectRatio: aspectRatio,
          child: GestureDetector(
            onTap: onClick,
            onLongPress: onLongPress,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                border: selected
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
                color: theme.colorScheme.surfaceVariant,
              ),
              child: ClipRRect(
                borderRadius: shape,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (image != null)
                      Image(
                        image: image,
                        fit: BoxFit.cover,
                        // 列表不做淡入，避免滚动期持续重绘（对齐 crossfade(false)）。
                        width: 150,
                        height: 220,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => _PlaceholderCover(
                            title: book.title, color: book.coverColor),
                      )
                    else
                      _PlaceholderCover(
                          title: book.title, color: book.coverColor),
                    Positioned(
                      right: 6,
                      top: 6,
                      child:
                          _TypeBadge(type: book.type, added: book.badgeAdded),
                    ),
                    if (book.progress > 0)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: LinearProgressIndicator(
                            value: book.progress.clamp(0.0, 1.0).toDouble(),
                            minHeight: 3,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
          child: Text(
            book.title,
            style: theme.textTheme.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
          child: Text(
            book.author.isNotEmpty ? book.author : book.subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String initial =
        title.trim().isEmpty ? '书' : title.trim().substring(0, 1);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[color, Color.lerp(color, Colors.black, 0.35)!],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, this.added = false});

  final CoverBookType type;
  final bool added;

  @override
  Widget build(BuildContext context) {
    final IconData icon = added
        ? Icons.check_circle_outline
        : (type == CoverBookType.novel
            ? Icons.auto_stories_outlined
            : Icons.collections_outlined);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }
}
