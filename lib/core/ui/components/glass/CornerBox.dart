import 'package:flutter/material.dart';

/// 四角框容器：中间可以放任意组件，四个角带直角标记。
///
/// 支持自定义极淡的全边框、背景色、四个角的线宽、颜色和长度。
class CornerBox extends StatelessWidget {
  const CornerBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.backgroundColor,
    this.borderColor,
    this.cornerColor,
    this.borderWidth = 1.0,
    this.cornerWidth = 1.2,
    this.cornerLength = 12.0,
    this.borderRadius = 0.0,
    this.boxShadow,
  });

  /// 内部的任意组件
  final Widget child;

  /// 内部内容的边距
  final EdgeInsetsGeometry padding;

  /// 背景色（通常可以用 `Theme.of(context).cardColor` 或白色）
  final Color? backgroundColor;

  /// 极淡的一圈外边框颜色（不需要外边框可以不传）
  final Color? borderColor;

  /// 四个角标记的颜色（通常比外边框深，如 `Colors.black87`）
  final Color? cornerColor;

  /// 外边框的线宽
  final double borderWidth;

  /// 四个角标记的线宽
  final double cornerWidth;

  /// 四个角标记的边长
  final double cornerLength;

  /// 圆角（如果不需要圆角保持默认 0 即可）
  final double borderRadius;

  /// 阴影（如果需要卡片悬浮效果）
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 默认角标颜色为深色；如果未提供外边框，默认不绘制外边框
    final actualCornerColor = cornerColor ?? theme.colorScheme.onSurface;

    return CustomPaint(
      // 用前景绘制器画角标，避免被背景色遮挡
      foregroundPainter: _CornerFramePainter(
        color: actualCornerColor,
        cornerWidth: cornerWidth,
        cornerLength: cornerLength,
        borderRadius: borderRadius,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: borderWidth)
              : null,
          boxShadow: boxShadow,
        ),
        child: child,
      ),
    );
  }
}

class _CornerFramePainter extends CustomPainter {
  _CornerFramePainter({
    required this.color,
    required this.cornerWidth,
    required this.cornerLength,
    required this.borderRadius,
  });

  final Color color;
  final double cornerWidth;
  final double cornerLength;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke
      // 直角拐角处使用圆形或平角均可，这里用平角显得更干净
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.square;

    // 留出半个线宽的偏移，防止线条被边缘裁切
    final offset = cornerWidth / 2;
    final left = offset;
    final top = offset;
    final right = size.width - offset;
    final bottom = size.height - offset;

    final l = cornerLength;
    final r = borderRadius;

    // 左上角
    final pathLT = Path()
      ..moveTo(left, top + l)
      ..lineTo(left, top + r)
      ..quadraticBezierTo(left, top, left + r, top)
      ..lineTo(left + l, top);
    canvas.drawPath(pathLT, paint);

    // 右上角
    final pathRT = Path()
      ..moveTo(right - l, top)
      ..lineTo(right - r, top)
      ..quadraticBezierTo(right, top, right, top + r)
      ..lineTo(right, top + l);
    canvas.drawPath(pathRT, paint);

    // 左下角
    final pathLB = Path()
      ..moveTo(left, bottom - l)
      ..lineTo(left, bottom - r)
      ..quadraticBezierTo(left, bottom, left + r, bottom)
      ..lineTo(left + l, bottom);
    canvas.drawPath(pathLB, paint);

    // 右下角
    final pathRB = Path()
      ..moveTo(right - l, bottom)
      ..lineTo(right - r, bottom)
      ..quadraticBezierTo(right, bottom, right, bottom - r)
      ..lineTo(right, bottom - l);
    canvas.drawPath(pathRB, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerFramePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.cornerWidth != cornerWidth ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.borderRadius != borderRadius;
  }
}
