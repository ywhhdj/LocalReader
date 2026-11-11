import 'package:Local_reader/core/ui/components/CircleIconButton.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

import 'package:Local_reader/core/model/performance_prefs.dart';

import '../../../common/design_tokens.dart';
import 'HeroHeader.dart';
import '../../theme/performance_scope.dart';

/// 吸顶毛玻璃容器（sliver）。
/// 初始位于顶部时不显示背景与模糊；向下滚动时平滑过渡出毛玻璃效果。
class StickyGlassHeader extends StatelessWidget {
  const StickyGlassHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
        LrSpacing.xs, LrSpacing.xs, LrSpacing.xs, LrSpacing.xs),
    this.blur = true,
    this.showBottomBorder = true,
    this.backgroundOpacity,
    this.scrollThreshold = 60.0, // 滚动多少像素后完全显现效果
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool blur;
  final bool showBottomBorder;
  final double? backgroundOpacity;
  final double scrollThreshold;

  @override
  Widget build(BuildContext context) {
    // 获取外层的滚动位置
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;

    if (position == null) {
      // 兜底：如果不在 ScrollView 内，直接按全模糊显示
      return PinnedHeaderSliver(
        child: _GlassSurface(
          factor: 1.0,
          blur: blur,
          showBottomBorder: showBottomBorder,
          backgroundOpacity: backgroundOpacity,
          child: Padding(padding: padding, child: child),
        ),
      );
    }

    return PinnedHeaderSliver(
      child: ListenableBuilder(
        listenable: position,
        builder: (context, _) {
          // 将滚动偏移量限制在 0 到 scrollThreshold 之间
          // 注意：在 iOS 顶部下拉回弹时 offset 会是负数，clamp 能保证 factor 为 0
          final double offset = position.pixels.clamp(0.0, scrollThreshold);
          final double factor = offset / scrollThreshold;

          return _GlassSurface(
            factor: factor,
            blur: blur,
            showBottomBorder: showBottomBorder,
            backgroundOpacity: backgroundOpacity,
            child: Padding(padding: padding, child: child),
          );
        },
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.factor,
    required this.child,
    required this.blur,
    required this.showBottomBorder,
    required this.backgroundOpacity,
  });

  final double factor; // 0.0 到 1.0 之间的渐变因子
  final Widget child;
  final bool blur;
  final bool showBottomBorder;
  final double? backgroundOpacity;

  @override
  Widget build(BuildContext context) {
    // 如果完全在顶部（未滚动），直接返回无背景、无模糊的纯净组件
    if (factor <= 0.0) {
      return child;
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final PerformanceBudget budget = PerformanceScope.of(context);

    final double maxAlpha = backgroundOpacity ?? (isDark ? 0.62 : 0.72);
    // 随着滚动，背景透明度渐显
    final double alpha = maxAlpha * factor;

    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: alpha),
        border: showBottomBorder
            ? Border(
                bottom: BorderSide(
                  // 底部细线也渐显
                  color: scheme.outlineVariant.withValues(alpha: 0.30 * factor),
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
          // 模糊程度随滚动渐显
          sigmaX: budget.blurSigma * factor,
          sigmaY: budget.blurSigma * factor,
        ),
        child: surface,
      ),
    );
  }
}

class HeaderAction {
  const HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
}

/// 顶部主标题 / 副标题 + 右侧图标区。
class PageScrollHeader extends StatelessWidget {
  const PageScrollHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.actions = const <HeaderAction>[],
    this.isDark = false,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final List<HeaderAction> actions;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return HeroHeader(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: actions.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final HeaderAction a in actions)
                  CircleIconButton(
                    tooltip: a.tooltip,
                    icon: a.icon,
                    iconSize: 21,
                    onPressed: a.onTap,
                    backgroundColor:
                        isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    foregroundColor:
                        isDark ? Colors.white : const Color(0xFF1C1C1E),
                  )
              ],
            ),
    );
  }
}

/// 页面骨架：顶部 header 吸顶 + 毛玻璃；header 内所有组件一起吸顶。
///
/// [header] **必填**，承载页面所有「顶部」内容（主副标题、工具栏、Tab、搜索栏…），
/// 可以是一个 Widget，也可以是自己组合的 `Column`。它们在滚动到顶部后固定不动。
///
/// 其余内容（[slivers] / [itemBuilder] / [rawSlivers]）属于 body，正常滚动。
///
/// 三种构造：
///   * [Page]      少量已知组件，仍走 builder 懒构造，不一次性分配子树；
///   * [Page.builder] 长列表，按 index 懒构建（推荐）；
///   * [Page.slivers] 需要 SliverFillRemaining / 自定义 sliver 的页面。
///
/// `addAutomaticKeepAlives: false`：不需要每个格子都保活，滚出视口就该释放；
/// `addRepaintBoundaries: true` 保留逐格重绘隔离。
class LrPage extends StatelessWidget {
  const LrPage({
    super.key,
    required this.header,
    required this.slivers,
    this.horizontalPadding = LrSpacing.l,
    this.bottomInset = 120,
  })  : itemCount = slivers?.length ?? 0,
        itemBuilder = null,
        rawSlivers = null;

  const LrPage.builder({
    super.key,
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    this.horizontalPadding = LrSpacing.xs,
    this.bottomInset = LrSpacing.xs,
  })  : slivers = null,
        rawSlivers = null;

  const LrPage.slivers({
    super.key,
    required this.header,
    required this.rawSlivers,
    this.horizontalPadding = LrSpacing.xs,
    this.bottomInset = 10,
  })  : slivers = null,
        itemCount = 0,
        itemBuilder = null;

  /// 顶部内容（必填，且一定吸顶）。可自行组合 PageScrollHeader、ShelfToolbar、Tab 等。
  final Widget header;
  final List<Widget>? slivers;
  final List<Widget>? rawSlivers;
  final int itemCount;
  final NullableIndexedWidgetBuilder? itemBuilder;
  final double horizontalPadding;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final List<Widget> body = <Widget>[
      // ── 顶部：固定吸顶 + 毛玻璃 ──
      StickyGlassHeader(child: header),
    ];

    // ── body：其余内容，正常滚动 ──
    if (rawSlivers != null) {
      body.addAll(rawSlivers!);
    } else {
      body.add(SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) => itemBuilder != null
                ? itemBuilder!(context, index)
                : slivers![index],
            childCount: itemBuilder != null ? itemCount : slivers!.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
          ),
        ),
      ));
    }

    body.add(SliverToBoxAdapter(child: SizedBox(height: bottomInset)));
    return SafeArea(bottom: false, child: CustomScrollView(slivers: body));
  }
}
