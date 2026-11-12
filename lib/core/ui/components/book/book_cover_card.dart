import 'dart:io' show File;

import 'package:Local_reader/core/common/design_tokens.dart';
import 'package:Local_reader/core/ui/components/CircleIconButton.dart';
import 'package:flutter/material.dart';

import '../../../model/book_identity.dart';

enum CoverBookType { novel, comic }

/// 卡片来源：决定右上角「本地 / 云端」角标与展示编号前缀。
enum CoverBookOrigin { local, cloud }

/// 书架两种形态：书本格（大封面 + 下方信息）与列表（小封面 + 右侧信息）。
enum CoverDisplay { grid, list }

/// 卡片的最小投影。
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
    this.origin = CoverBookOrigin.local,
    this.progressText = '',
  });

  final String id;
  final String title;
  final String author;
  final String subtitle;
  final String coverPath;
  final String coverUrl;

  /// 即使传入了 coverColor，占位图也将固定使用透明黑色。
  final Color coverColor;
  final double progress;
  final CoverBookType type;
  final bool badgeAdded;
  final CoverBookOrigin origin;

  /// 形如 `3/440` 的章节进度；为空时回退百分比。
  final String progressText;

  bool get isCloud => origin == CoverBookOrigin.cloud;

  String get displayId => BookIdentity.displayId(
        isCloud ? BookIdentity.cloudId(id) : id,
      );

  String get originLabel => BookIdentity.originLabel(
        isCloud ? BookOrigin.cloud : BookOrigin.local,
      );

  String get sourceLabel => BookIdentity.sourceSubtitle(
        isCloud ? BookOrigin.cloud : BookOrigin.local,
      );

  String get resolvedProgressText => progressText.isNotEmpty
      ? progressText
      : (progress > 0 ? '${(progress * 100).round()}%' : '');

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

/// 统一封面卡片：本地 / 云端、小说 / 漫画、书本格 / 列表共用。
class BookCoverCard extends StatelessWidget {
  const BookCoverCard({
    super.key,
    required this.book,
    required this.onClick,
    this.onLongPress,
    this.onMore,
    this.selected = false,
    this.aspectRatio = 0.7,
    this.display = CoverDisplay.grid,
  });

  final CoverBook book;
  final VoidCallback onClick;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;
  final bool selected;
  final double aspectRatio;
  final CoverDisplay display;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final VoidCallback more = onMore ?? onClick;
    return display == CoverDisplay.list
        ? _listLayout(context, theme, more)
        : _gridLayout(context, theme, more);
  }

  /// 书本格形态（带底部作者、进度）
  Widget _gridLayout(
          BuildContext context, ThemeData theme, VoidCallback more) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: aspectRatio,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClick,
              onLongPress: onLongPress,
              child: _cover(context, book, selected, compact: false),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2, right: 2),
            child: Text(
              book.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: LrFontSize.noraml,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  book.author.isNotEmpty ? book.author : '未知作者',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _MoreButton(onTap: more, compact: true),
            ],
          ),
          if (book.resolvedProgressText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
              child: Text(
                book.resolvedProgressText,
                style: theme.textTheme.labelSmall,
              ),
            ),
        ],
      );

  /// 列表形态（参考截图：透明背景、左侧深色封面、右侧紧凑文字、圆形更多按钮）
  Widget _listLayout(BuildContext context, ThemeData theme, VoidCallback more) {
    final ColorScheme scheme = theme.colorScheme;

    // 用 DecoratedBox 包一层，加上底部的浅灰色分割线
    return DecoratedBox(
      //每个都有些间距
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClick,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 左侧封面
              SizedBox(
                width: 82,
                height: 114,
                child: _cover(context, book, selected, compact: true),
              ),
              const SizedBox(width: 16),
              // 右侧文字信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      book.displayId,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      book.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      book.sourceLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 右侧：更多按钮 + 章节进度
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _MoreButton(onTap: more, compact: false),
                  if (book.resolvedProgressText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      book.resolvedProgressText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w100,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _cover(BuildContext context, CoverBook book, bool selected,
    {required bool compact}) {
  final ThemeData theme = Theme.of(context);
  final double radius = compact ? 6 : 12;
  final ImageProvider? image = book.coverImage();

  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: selected
          ? Border.all(color: theme.colorScheme.primary, width: 2)
          : null,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (image != null)
            Image(
              image: image,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _PlaceholderCover(
                title: book.title,
                sourceLabel: book.sourceLabel,
                compact: compact,
              ),
            )
          else
            _PlaceholderCover(
              title: book.title,
              sourceLabel: book.sourceLabel,
              compact: compact,
            ),
          // 如果是列表形态，移除了右上角角标；保留了底部的细进度条
          if (book.progress > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: book.progress.clamp(0.0, 1.0).toDouble(),
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.28),
                color: Colors.white,
              ),
            ),
        ],
      ),
    ),
  );
}

/// 纯黑色的封面占位
class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover({
    required this.title,
    required this.sourceLabel,
    required this.compact,
  });

  final String title;
  final String sourceLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // 默认透明黑色的背景（在浅色模式下呈深灰黑，深色模式下全黑）
    final Color bgColor = Colors.black.withValues(alpha: 0.85);
    const Color fgColor = Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(color: bgColor),
      child: Stack(
        children: <Widget>[
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: (compact
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.headlineSmall)
                    ?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w300,
                  height: 1.3,
                  fontSize: compact ? 12 : 14,
                ),
              ),
            ),
          ),
          Positioned(
            left: compact ? 8 : 12,
            bottom: compact ? 8 : 12,
            child: Text(
              sourceLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fgColor.withValues(alpha: 0.5),
                fontSize: compact ? 9 : 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 右侧的更多按钮（带浅灰色圆形背景）
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap, required this.compact});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 32 : 40;

    return CircleIconButton(
        icon: Icons.more_horiz, size: size, onPressed: onTap);
  }
}
