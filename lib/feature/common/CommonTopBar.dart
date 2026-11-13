import 'package:flutter/material.dart';

class CommonTopBar extends StatelessWidget implements PreferredSizeWidget {
  const CommonTopBar({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
    this.leading,
    this.showBackButton = true,
    this.backgroundColor = Colors.transparent,
    this.elevation = 0,
    this.titleStyle,
    this.onBack,
  });

  final String title;

  /// 右侧的任意组件列表，推荐传入 CircleIconButton 保持视觉统一
  final List<Widget> actions;

  /// 自定义左侧组件，优先级高于 showBackButton
  final Widget? leading;

  /// 是否显示默认的返回按钮
  final bool showBackButton;
  final Color backgroundColor;
  final double elevation;
  final TextStyle? titleStyle;

  /// 自定义返回点击事件，默认执行 Navigator.pop
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();
    // 如果没有返回栈且没有自定义 leading，则不显示左侧
    final Widget? finalLeading = leading ??
        (showBackButton && canPop ? BackButton(onPressed: onBack) : null);

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: elevation,
      scrolledUnderElevation: elevation,
      centerTitle: true,
      leading: finalLeading,
      title: Text(
        title,
        style: titleStyle ?? Theme.of(context).textTheme.titleLarge,
      ),
      actions: actions.isEmpty
          ? null
          : <Widget>[
              // 用 Row 包装并设置小边距，避免 CircleIconButton 贴边
              Row(
                mainAxisSize: MainAxisSize.min,
                children: actions,
              ),
              const SizedBox(width: 8),
            ],
    );
  }
}
