import 'dart:ui';

import 'package:Local_reader/core/model/performance_prefs.dart';
import 'package:flutter/material.dart';

import '../../../common/design_tokens.dart';
import '../../theme/glass_theme.dart';
import '../../theme/performance_scope.dart';

@immutable
class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const GlassNavItem(
      {required this.icon, required this.activeIcon, required this.label});
}

/// 乳玻璃容器：模糊 + 半透明渐变 + 1px 高光描边 + 柔和外阴影。
/// 深色模式下由 brightness 反推文字对比度（对应原项目「正文与面板文字色由背景亮度自动反推」）。
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
    final PerformanceBudget budget = PerformanceScope.of(context);
    final List<Color> gradientColors = tint ??
        (isDark
            ? <Color>[
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.04)
              ]
            : season.glassTint);
    final Widget panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: budget.useHighlightBorder
            ? Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.55),
                width: 1,
              )
            : null,
        boxShadow: budget.useShadows
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: budget.useBackdropFilter
          ? BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: budget.blurSigma, sigmaY: budget.blurSigma),
              child: panel,
            )
          : panel,
    );
  }
}

/// 加粗衬线标签 + 底部指示点表达
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
      minimum: const EdgeInsets.fromLTRB(
          LrSpacing.xs, 0, LrSpacing.xs, LrSpacing.xs),
      child: GlassPanel(
        borderRadius: LrRadius.pill,
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.xs, vertical: LrSpacing.xs),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.xs, vertical: LrSpacing.xs),
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
              curve: Curves.easeOutCubic,
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
