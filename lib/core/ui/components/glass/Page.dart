import 'package:Local_reader/core/ui/components/CircleIconButton.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

import 'package:Local_reader/core/model/performance_prefs.dart';

import '../../../common/design_tokens.dart';
import 'HeroHeader.dart';
import '../../theme/performance_scope.dart';

/// 吸顶
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

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final PerformanceBudget budget = PerformanceScope.of(context);

    // 2. 如果设备性能差，不支持 BackdropFilter，给出一个半透明底色兜底
    // （否则文字叠加在繁杂的背景上会看不清）


    // 3. 纯磨砂背透：只有模糊，没有底色遮挡
    return child;
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
                      padding: const EdgeInsets.only(left: 8))
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
    this.pagePadding = const EdgeInsets.only(
        left: LrSpacing.xs, right: LrSpacing.xs, top: LrSpacing.xs),
    this.horizontalPadding = 0, // 外层已留白，内部默认不再额外留白
    this.bottomInset = 120,
  })  : itemCount = slivers?.length ?? 0,
        itemBuilder = null,
        rawSlivers = null;

  const LrPage.builder({
    super.key,
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    this.pagePadding = const EdgeInsets.only(
        left: LrSpacing.xs, right: LrSpacing.xs, top: LrSpacing.s),
    this.horizontalPadding = 0,
    this.bottomInset = LrSpacing.xs,
  })  : slivers = null,
        rawSlivers = null;

  const LrPage.slivers({
    super.key,
    required this.header,
    required this.rawSlivers,
    this.pagePadding = const EdgeInsets.only(
        left: LrSpacing.m, right: LrSpacing.m, top: LrSpacing.s),
    this.horizontalPadding = 0,
    this.bottomInset = 10,
  })  : slivers = null,
        itemCount = 0,
        itemBuilder = null;

  final Widget header;
  final List<Widget>? slivers;
  final List<Widget>? rawSlivers;
  final int itemCount;
  final NullableIndexedWidgetBuilder? itemBuilder;

  /// 页面四周的外边距，顶部默认较小（LrSpacing.s），左右较大（LrSpacing.m）
  final EdgeInsetsGeometry pagePadding;

  /// body 内部列表的水平边距（因为外层 pagePadding 已经留了左右边距，所以这里默认设为 0）
  final double horizontalPadding;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final List<Widget> body = <Widget>[
      // 顶部吸顶
      StickyGlassHeader(
        padding: const EdgeInsets.all(LrSpacing.xs),
        child: header,
      ),
    ];

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

    // 使用 Padding 将整个滚动区域向内收缩
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: pagePadding,
        child: ClipRRect(
          // 配合留白，给整个页面加上圆角，像一张悬浮的纸张
          borderRadius: BorderRadius.circular(16.0),
          child: CustomScrollView(
            slivers: body,
            // 如果吸顶时需要阴影，可以在这里加上
          ),
        ),
      ),
    );
  }
}
