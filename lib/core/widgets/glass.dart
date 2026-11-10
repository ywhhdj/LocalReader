import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/glass_theme.dart';

@immutable
class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label
});
}

/// 乳玻璃容器：模糊 + 半透明渐变 + 1px 高光描边 + 柔和外阴影。
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LrSpacing.m),
    this.borderRadius = LrRadius.panel,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final List<Color>? tint;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final SeasonPalette season =
        Theme.of(context).extension<LrSeasonTheme>()?.palette ??
            SeasonPalette.all[isDark ? SeasonStyle.winter : SeasonStyle.paper]!;
    final List<Color> gradientColors = tint ??
        (isDark
            ? <Color>[
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.04)
              ]
            : season.glassTint);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: LrBlur.sigmaX, sigmaY: LrBlur.sigmaY),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.55),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 玻璃胶囊底栏：选中态用衬线小标签 + 圆点，不使用 Material 默认 NavigationBar。
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum:
          const EdgeInsets.fromLTRB(LrSpacing.m, 0, LrSpacing.m, LrSpacing.m),
      child: GlassPanel(
        borderRadius: LrRadius.pill,
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.s, vertical: LrSpacing.s),
        child: Row(
          children: List<Widget>.generate(items.length, (int i) {
            return Expanded(
              child: _NavItem(
                item: items[i],
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.item, required this.selected, required this.onTap});

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color fg = selected
        ? scheme.primary
        : Theme.of(context).textTheme.bodySmall?.color ??
            scheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: LrSpacing.s),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(LrRadius.pill),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(selected ? item.activeIcon : item.icon, size: 21, color: fg),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontFamilyFallback: const <String>[
                  'Songti SC',
                  'SimSun',
                  'serif'
                ],
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: selected ? 12 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(LrRadius.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


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
    this.iconGap = LrSpacing.s,
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