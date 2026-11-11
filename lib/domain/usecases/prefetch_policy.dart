// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖
// 合并状态 E13：已落入工程路径 lib/domain/usecases/prefetch_policy.dart；同名类型已隔离；未编译 / 未运行 / 未下载依赖。
// 设计源：scaffold/prefetch_policy.dart（交付包内保留，作为规格基线）
// 建议落点：lib/domain/usecases/comic_prefetch_policy.dart
//           + chapter_prefetch_policy.dart
//           + lib/data/parser/parse_dispatcher.dart
// 对应需求：R6 R7；纯 Dart，无 Flutter 依赖，便于模型级测试。
//
// 已知限制（来自 dev pagination_isolate.dart 自注）：TextPainter 依赖 Flutter binding，
// 后台 isolate 是否可用需真机压测；本骨架只定义调度边界，不声称已验证。

/// 漫画窗口内预加载 4 页（R7）。
/// 口径：窗口共 4 页 = 当前 1 + 向前 1 + 向后 2；windowPages 可配置。
/// 与 dev 现有 ComicPrefetchWindow(back=1, ahead=3)（覆盖 5 页）不同，
/// 合并时统一改由本策略计算窗口。
// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class ComicPrefetchPolicy {
  const ComicPrefetchPolicy({this.windowPages = 4, this.back = 1});

  final int windowPages;
  final int back;

  int get ahead => windowPages - 1 - back;

  Set<int> computeWindow(int current, int total) {
    if (total <= 0) return <int>{};
    final int anchor = current.clamp(0, total - 1).toInt();
    final int start = (anchor - back).clamp(0, total - 1).toInt();
    final int end = (anchor + ahead).clamp(0, total - 1).toInt();
    return <int>{for (int i = start; i <= end; i++) i};
  }

  /// 只在当前页变化时批量 prefetch / evict 差集，不在滚动回调逐帧跨 channel。
  ({Set<int> toLoad, Set<int> toEvict}) diff(
      Set<int> oldWindow, Set<int> newWindow) =>
      (toLoad: newWindow.difference(oldWindow), toEvict: oldWindow.difference(newWindow));
}

/// 小说预加载 ±1 章（R7）：首尾章自动裁剪，失败保留当前章、可重试。
// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class ChapterPrefetchPolicy {
  const ChapterPrefetchPolicy({this.radius = 1});

  final int radius;

  Set<int> computeWindow(int current, int total) {
    if (total <= 0) return <int>{};
    final int anchor = current.clamp(0, total - 1).toInt();
    final int start = (anchor - radius).clamp(0, total - 1).toInt();
    final int end = (anchor + radius).clamp(0, total - 1).toInt();
    return <int>{for (int i = start; i <= end; i++) i};
  }
}

/// 解析任务：IO 读取 / 编码探测 / 文本或 HTML 解析 / 分页计算 / 原生栅格化
/// 全部交给 ParseDispatcher，主线程只做渲染。
// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class ParseTask {
  const ParseTask({
    required this.id,
    required this.kind,
    required this.payload,
  });

  final String id;
  final ParseTaskKind kind;
  final Object payload;
}

enum ParseTaskKind { ioRead, decode, parseText, parseWenku8Html, paginate, raster }

// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class ParseResult {
  const ParseResult({
    required this.taskId,
    required this.value,
    this.measuredExactly = true,
    this.issue = '',
  });

  final String taskId;
  final Object? value;
  final bool measuredExactly;
  final String issue;

  bool get isOk => value != null && issue.isEmpty;
}

/// 调度边界：submit 返回 Future，cancel 后迟到的结果必须丢弃。
/// 生产实现用 compute / Isolate 池 + IO 执行器；本骨架只给内存占位。
abstract interface class ParseDispatcher {
  Future<ParseResult> submit(ParseTask task);
  void cancel(String taskId);
  void dispose();
}

class InMemoryParseDispatcher implements ParseDispatcher {
  final Set<String> _cancelled = <String>{};
  bool _closed = false;

  @override
  Future<ParseResult> submit(ParseTask task) async {
    if (_closed) return ParseResult(taskId: task.id, value: null, issue: 'closed');
    // 生产里这里换成 compute(...) / Isolate.run(...) / 原生 channel 调用。
    await Future<void>.delayed(Duration.zero);
    if (_cancelled.contains(task.id) || _closed) {
      return ParseResult(taskId: task.id, value: null, issue: 'cancelled');
    }
    return ParseResult(taskId: task.id, value: task.payload);
  }

  @override
  void cancel(String taskId) => _cancelled.add(taskId);

  @override
  void dispose() => _closed = true;
}
