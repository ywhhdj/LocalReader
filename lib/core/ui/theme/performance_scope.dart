import 'package:flutter/widgets.dart';

import '../../model/performance_prefs.dart';

/// 把「实际生效的性能档」沿 widget 树传下去。
///
/// 组件（玻璃面板、朗读悬浮球、贴边动画）只读这里，不各自去
/// `AppScope.of(context).settings` 拼一份，避免口径分裂与重复重建。
/// 没有挂载时回落到默认档，保证单独测试组件也不会崩。
class PerformanceScope extends InheritedWidget {
  const PerformanceScope({
    super.key,
    required this.budget,
    required super.child,
  });

  final PerformanceBudget budget;

  static final PerformanceBudget _fallback =
      PerformanceBudget.resolve(const PerformancePrefs(), true);

  static PerformanceBudget of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PerformanceScope>()?.budget ??
      _fallback;

  @override
  bool updateShouldNotify(PerformanceScope oldWidget) =>
      oldWidget.budget != budget;
}
