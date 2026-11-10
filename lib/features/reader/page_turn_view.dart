import 'package:flutter/material.dart';

import '../../core/state/reader_style.dart';

/// 翻页视图：平移 / 仿真（伪 3D 绕书脊）/ 无动画，对应原项目三档设置。
///
/// 静态交付说明：slide 与 none 的行为差异是真实可审查的（滚动物理 + 点击翻页）；
/// simulation 是结构完整的近似实现，绕 Y 轴透视与书脊阴影的系数需要真机调参，
/// 故标 TODO(静态冻结)，不声称视觉已还原。
class PageTurnView extends StatelessWidget {
  const PageTurnView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.onPageChanged,
    required this.itemBuilder,
    required this.turn,
    this.rtl = false,
  });

  final PageController controller;
  final int itemCount;
  final ValueChanged<int> onPageChanged;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ReaderPageTurn turn;

  /// 日漫从右往左：只反转「点按半屏」的前进/后退映射与前进步进方向。
  /// 视觉索引反转由 ComicSpreadLayout 在 itemBuilder 层完成，这里不重复解释。
  final bool rtl;

  int get _current =>
      controller.hasClients ? (controller.page?.round() ?? 0) : 0;

  @override
  Widget build(BuildContext context) {
    switch (turn) {
      case ReaderPageTurn.none:
        return _noAnimation(context);
      case ReaderPageTurn.slide:
        return _pageView(context);
      case ReaderPageTurn.simulation:
        return _simulation(context);
    }
  }

  Widget _pageView(BuildContext context,
      {ScrollPhysics? physics, bool simulation = false}) {
    return PageView.builder(
      controller: controller,
      itemCount: itemCount,
      physics: physics,
      onPageChanged: onPageChanged,
      itemBuilder: (BuildContext ctx, int i) {
        final Widget child = itemBuilder(ctx, i);
        if (!simulation) return child;
        // controller.page 在首帧可能尚未可用，用 index 兜底避免 NaN 透视。
        final double page = controller.hasClients
            ? (controller.page ?? i.toDouble())
            : i.toDouble();
        return _SimulationPage(offset: page - i, child: child);
      },
    );
  }

  /// 无动画：禁止手势滚动，点击屏幕左右半区翻页，避免任何过渡动画。
  Widget _noAnimation(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (TapUpDetails d) {
        final double width = context.size?.width ?? 400;
        final int current = _current;
        // LTR：点右半屏前进（viewIndex +1）；RTL：点左半屏前进（viewIndex -1）。
        final int forward = rtl ? -1 : 1;
        final bool advance = rtl
            ? d.localPosition.dx <= width / 2
            : d.localPosition.dx > width / 2;
        final int target = (current + (advance ? forward : -forward))
            .clamp(0, itemCount - 1)
            .toInt();
        if (target != current) controller.jumpToPage(target);
      },
      child: _pageView(context, physics: const NeverScrollableScrollPhysics()),
    );
  }

  /// 仿真：让 PageView 随 controller 的滚动偏移，对每页做绕 Y 轴透视 + 书脊阴影。
  Widget _simulation(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext ctx, Widget? _) =>
          _pageView(ctx, simulation: true),
    );
  }
}

class _SimulationPage extends StatelessWidget {
  const _SimulationPage({required this.offset, required this.child});

  /// controller.page - index：正值表示本页已被翻过去，负值表示下一页正在翻入。
  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double t = offset.clamp(-1.0, 1.0).toDouble();
    final double angle = -t * 0.34;
    if (angle.abs() < 0.001) return child;

    final Matrix4 transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..rotateY(angle);

    return Transform(
      transform: transform,
      alignment: t < 0 ? Alignment.centerLeft : Alignment.centerRight,
      child: Stack(
        children: <Widget>[
          child,
          // 书脊侧的渐暗层：转得越多越暗，近似纸张背光。
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: t < 0 ? Alignment.centerLeft : Alignment.centerRight,
                    end: t < 0 ? Alignment.centerRight : Alignment.centerLeft,
                    colors: <Color>[
                      Colors.black.withValues(
                          alpha:
                              (angle.abs() * 0.42).clamp(0.0, 0.45).toDouble()),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
