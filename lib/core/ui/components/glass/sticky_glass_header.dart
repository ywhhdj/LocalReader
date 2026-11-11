import 'dart:ui' show ImageFilter;

import 'package:Local_reader/core/model/performance_prefs.dart';
import 'package:flutter/material.dart';

import '../../../common/design_tokens.dart';
import '../../theme/performance_scope.dart';

/// 吸顶毛玻璃容器（sliver）。
class StickyGlassHeader extends StatelessWidget {
  const StickyGlassHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
        LrSpacing.l, LrSpacing.xl, LrSpacing.l, LrSpacing.m),
    this.blur = true,
    this.showBottomBorder = true,
    this.backgroundOpacity,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool blur;
  final bool showBottomBorder;
  final double? backgroundOpacity;

  @override
  Widget build(BuildContext context) {
    return PinnedHeaderSliver(
      child: _GlassSurface(
        blur: blur,
        showBottomBorder: showBottomBorder,
        backgroundOpacity: backgroundOpacity,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    required this.blur,
    required this.showBottomBorder,
    required this.backgroundOpacity,
  });

  final Widget child;
  final bool blur;
  final bool showBottomBorder;
  final double? backgroundOpacity;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final PerformanceBudget budget = PerformanceScope.of(context);

    final double alpha = backgroundOpacity ?? (isDark ? 0.62 : 0.72);
    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: alpha),
        border: showBottomBorder
            ? Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.30),
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: child,
    );

    if (!blur || !budget.useBackdropFilter) return surface;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: budget.blurSigma,
          sigmaY: budget.blurSigma,
        ),
        child: surface,
      ),
    );
  }
}
