import 'package:flutter/material.dart';

/// 通用圆形背景图标按钮。
/// 基于 Flutter 原生 [IconButton] 的 [IconButton.styleFrom] 构建。
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44.0,
    this.iconSize = 22.0,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// 整个圆形的直径大小
  final double size;

  /// 图标本身的大小
  final double iconSize;

  // 以下颜色不传时会自动适配明暗主题（还原设计图效果）
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        // 如果外部没传，就使用默认的明暗配色
        backgroundColor: backgroundColor ??
            (isDark ? const Color(0xFF2C2C2E) : Colors.white),
        foregroundColor: foregroundColor ??
            (isDark ? Colors.white : const Color(0xFF1C1C1E)),
        // 浅色模式加极淡的灰色边框，深色模式无边框
        side: BorderSide(
          color: borderColor ??
              (isDark ? Colors.transparent : const Color(0xFFE5E5EA)),
          width: 1.0,
        ),
        shape: const CircleBorder(),
        // 撑开最小尺寸以固定圆的大小，且清空默认内边距
        minimumSize: Size(size, size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
