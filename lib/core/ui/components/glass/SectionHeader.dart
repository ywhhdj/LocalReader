import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.textStyle,
    this.dividerColor,
    this.endDotColor,
    this.padding = EdgeInsets.zero,
    this.spacing = 8.0, // 对应原 LrSpacing.xs，默认值 8
  });

  /// 左侧的标题文字
  final String title;

  /// 自定义标题文字样式，不传则使用 labelSmall
  final TextStyle? textStyle;

  /// 自定义分割线颜色，不传则使用 outline
  final Color? dividerColor;

  /// 自定义最右侧小方块颜色，不传则使用 onSurface
  final Color? endDotColor;

  /// 组件外层边距
  final EdgeInsetsGeometry padding;

  /// 文字与分割线之间的距离
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: textStyle ?? text.labelSmall,
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Divider(
              color: dividerColor ?? scheme.outline,
              height: 1,
            ),
          ),
          const SizedBox(width: 2),
          Container(
            width: 4,
            height: 4,
            color: endDotColor ?? scheme.onSurface,
          ),
        ],
      ),
    );
  }
}
