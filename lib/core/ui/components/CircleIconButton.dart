import 'package:flutter/material.dart';

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 52.0,
    this.iconSize = 22.0,
    this.backgroundColor,
    this.foregroundColor,
    this.padding = EdgeInsets.zero, // 如果需要保留 left: 8，外部可传入
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // 完全采用 ShelfRoundAction 的颜色方案作为默认值
    final Color bgColor =
        backgroundColor ?? scheme.onSurface.withValues(alpha: 0.10);
    final Color fgColor = foregroundColor ?? scheme.onSurface;

    return Padding(
      padding: padding,
      child: Material(
        color: bgColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: tooltip != null
                ? Tooltip(
                    message: tooltip!,
                    child: Icon(icon, color: fgColor, size: iconSize),
                  )
                : Icon(icon, color: fgColor, size: iconSize),
          ),
        ),
      ),
    );
  }
}
