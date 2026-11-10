import 'package:flutter/material.dart';

import 'hero_header.dart';

/// 页头右侧的一个图标动作。文案由调用页面通过统一文案出口提供，
/// 组件本身不读 locale，保持「通用组件无业务依赖」。
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
///
/// 这是「随页面滚动的导航栏」：调用方把它放进 `CustomScrollView` 的
/// `SliverToBoxAdapter`（不是 `SliverAppBar(pinned: true)`），所以滚动时
/// 与内容一起移出视口。若以后要改成吸顶，只需在 `LrPage` 里换 sliver 类型，
/// 组件本身一个字都不用动。
class PageScrollHeader extends StatelessWidget {
  const PageScrollHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.actions = const <HeaderAction>[],
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final List<HeaderAction> actions;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
                  IconButton(
                    tooltip: a.tooltip,
                    icon: Icon(a.icon, size: 21),
                    color: a.active ? scheme.primary : scheme.onSurfaceVariant,
                    onPressed: a.onTap,
                  ),
              ],
            ),
    );
  }
}
