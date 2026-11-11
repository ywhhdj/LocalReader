import 'package:flutter/material.dart';

import '../../../common/design_tokens.dart';

/// 页面 / 区块的 Hero 头：`[icon?]  Title / Subtitle  [trailing?]`。
///
/// - [subtitle] 自动使用灰色（`onSurfaceVariant`），保证在浅色/深色主题下都有
///   二级文字应有的弱对比。
/// - [trailing] 为 null 时标题区独占整行；有 trailing 时通过 `Expanded`
///   自动让出右侧空间，永远不会因为标题过长把 trailing 挤掉。
/// - [icon] 为 null 时不留左侧空位，标题从最左开始。
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.iconSize = 32,
    this.trailing,
    this.titleStyle,
    this.subtitleStyle,
    this.spacing = LrSpacing.xs,
    this.iconGap = LrSpacing.xs,
    this.bottomSpacing = LrSpacing.m,
  });

  final String title;
  final String? subtitle;

  /// 左侧主图标；为 null 时不渲染左侧占位。
  final IconData? icon;

  /// 图标颜色；默认跟随 `colorScheme.primary`。
  final Color? iconColor;

  /// 图标尺寸；默认 32，配合 `displayMedium` 标题。
  final double iconSize;

  /// 右侧插槽：IconButton、Badge、自定义 chip 等都可以放。
  /// 为 null 时标题区独占整行。
  final Widget? trailing;

  /// 覆盖标题样式；不传则用 `textTheme.displayMedium`。
  final TextStyle? titleStyle;

  /// 覆盖副标题样式；不传则用 `bodyMedium` + 灰色。
  final TextStyle? subtitleStyle;

  /// 标题与副标题之间的间隙。
  final double spacing;

  /// 图标与标题之间的间隙。
  final double iconGap;

  /// 整个 Header 的底部留白，用来和下一个区块隔开。
  /// 设为 0 可以让 Header 紧贴下一段内容（例如顶部是 Hero、下面紧跟分区列表）。
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme text = theme.textTheme;

    final Widget titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: titleStyle ?? text.displayMedium),
        if (subtitle != null) ...<Widget>[
          SizedBox(height: spacing),
          Text(
            subtitle!,
            style: (subtitleStyle ?? text.bodyMedium)?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? theme.colorScheme.primary,
            ),
            SizedBox(width: iconGap),
          ],
          // 永远 Expanded：title 再长也只会换行，不会挤掉 trailing。
          // 没有 trailing 时，Expanded 自然独占整行 Row。
          Expanded(child: titleBlock),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
