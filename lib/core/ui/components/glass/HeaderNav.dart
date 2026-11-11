import 'dart:ui';

import 'package:flutter/material.dart';

/// 模糊档位。生产环境由 PerformanceBudget.resolve() 裁决，组件不自己解释。
enum HeaderBlurLevel { full, reduced, minimal }

double blurRadiusOf(HeaderBlurLevel level) {
  switch (level) {
    case HeaderBlurLevel.full:
      return 18;
    case HeaderBlurLevel.reduced:
      return 8;
    case HeaderBlurLevel.minimal:
      return 0;
  }
}

class HeaderNavAction {
  const HeaderNavAction({
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

/// 每个页面自己构造一份 Spec；core 组件不读 AppState、不构造路由。
@immutable
class HeaderNavSpec {
  const HeaderNavSpec({
    required this.title,
    this.subtitle,
    this.leading,
    this.centerTitle = false,
    this.actions = const <HeaderNavAction>[],
    this.categoryIcons = const <Widget>[],
    this.blur = HeaderBlurLevel.full,
    this.scrollWithContent = false,
    this.expandedHeight = 92,
    this.collapsedHeight = 64,
  });

  final String title;
  final String? subtitle;

  /// 左侧返回按钮由调用页自己注入（R13「导入书籍」页要求左返回）；
  /// core 组件不读 Navigator、不构造路由。
  final Widget? leading;

  /// R13「中间导入书籍」：左右都有按钮时把标题居中，避免被 actions 挤偏。
  final bool centerTitle;
  final List<HeaderNavAction> actions;

  /// 收藏页 / 书架页右侧的「小说 / 漫画」分类图标
  final List<Widget> categoryIcons;

  final HeaderBlurLevel blur;

  /// 默认 false = 一直置顶；true 可退回旧的「随内容滚出」行为（R2 歧义兜底）。
  final bool scrollWithContent;
  final double expandedHeight;
  final double collapsedHeight;
}

/// 用法：放进 CustomScrollView.slivers 的第一项：
///   HeaderNavSliver(spec: HeaderNavSpec(...))
/// 若 scrollWithContent=true，则改用 SliverToBoxAdapter(child: HeaderNav(...))。
class HeaderNavSliver extends StatelessWidget {
  const HeaderNavSliver({super.key, required this.spec});

  final HeaderNavSpec spec;

  @override
  Widget build(BuildContext context) {
    if (spec.scrollWithContent) {
      return SliverToBoxAdapter(child: HeaderNav(spec: spec));
    }
    return SliverPersistentHeader(
      pinned: true, // 一直置顶最上方
      delegate: _HeaderNavDelegate(spec: spec),
    );
  }
}

class HeaderNav extends StatelessWidget {
  const HeaderNav({super.key, required this.spec});

  final HeaderNavSpec spec;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double sigma = blurRadiusOf(spec.blur);
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          if (spec.leading != null) spec.leading!,
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: spec.centerTitle
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: <Widget>[
                Text(spec.title, style: theme.textTheme.titleLarge),
                if (spec.subtitle != null)
                  Text(spec.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          ...spec.categoryIcons,
          for (final HeaderNavAction a in spec.actions)
            IconButton(
              icon: Icon(a.icon,
                  color: a.active ? theme.colorScheme.primary : null),
              tooltip: a.tooltip,
              onPressed: a.onTap,
            ),
        ],
      ),
    );

    // 背景透明；只有导航栏这一层做「部分模糊」，且 minimal 档直接不建滤镜。
    if (sigma <= 0) {
      return DecoratedBox(
        decoration: BoxDecoration(color: Colors.transparent),
        child: SafeArea(bottom: false, child: content),
      );
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.18),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 0.6,
              ),
            ),
          ),
          child: SafeArea(bottom: false, child: content),
        ),
      ),
    );
  }
}

class _HeaderNavDelegate extends SliverPersistentHeaderDelegate {
  const _HeaderNavDelegate({required this.spec});

  final HeaderNavSpec spec;

  @override
  double get minExtent => spec.collapsedHeight;

  @override
  double get maxExtent => spec.expandedHeight;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      HeaderNav(spec: spec);

  @override
  bool shouldRebuild(covariant _HeaderNavDelegate old) =>
      old.spec.title != spec.title ||
      old.spec.blur != spec.blur ||
      old.spec.actions.length != spec.actions.length;
}
