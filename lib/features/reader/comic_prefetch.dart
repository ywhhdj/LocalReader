import 'dart:async';

import '../../core/platform/render_bridge.dart';

/// 预加载窗口：对应原项目「预加载窗口、按页宽高比占位」。
/// 只在窗口差集变化时批量 prefetch / evict，不在滚动回调里逐帧跨 channel。
class ComicPrefetchWindow {
  ComicPrefetchWindow({required this.bridge, this.back = 1, this.ahead = 3});

  final BookRenderBridge bridge;
  final int back;
  final int ahead;

  int? _handle;
  int _pageCount = 0;
  int _current = -1;
  Set<int> _window = <int>{};

  void attach(int handle, int pageCount) {
    _handle = handle;
    _pageCount = pageCount;
    _current = -1;
    _window = <int>{};
  }

  Set<int> get activeWindow => Set<int>.unmodifiable(_window);

  /// 跨页布局变化后强制重算窗口（保留旧窗口用于差集 evict，不清空记录）。
  void invalidate() => _current = -1;

  void moveTo(int page) => moveToPages(<int>[page]);

  /// 双页跨页：当前跨可能同时显示两页，窗口必须把两页都覆盖到。
  /// 以最小页为锚点扩展 [anchor-back, anchor+ahead]，再并上当前跨的全部页；
  /// 仍然只在**窗口差集变化**时批量 prefetch / evict，不逐帧跨 channel。
  void moveToPages(Iterable<int> pages) {
    final int? handle = _handle;
    final List<int> valid = <int>[
      for (final int p in pages) if (p >= 0 && p < _pageCount) p,
    ]..sort();
    if (handle == null || valid.isEmpty) return;
    final int anchor = valid.first;
    if (anchor == _current && _window.containsAll(valid)) return;
    _current = anchor;

    final Set<int> next = <int>{...valid};
    for (int i = anchor - back; i <= anchor + ahead; i++) {
      if (i >= 0 && i < _pageCount) next.add(i);
    }

    final List<int> add = next.difference(_window).toList()..sort();
    final List<int> remove = _window.difference(next).toList()..sort();
    _window = next;

    if (add.isNotEmpty) unawaited(bridge.prefetch(handle, add));
    if (remove.isNotEmpty) unawaited(bridge.evict(handle, remove));
  }

  /// 退出阅读器时释放全部纹理，避免大图常驻。
  Future<void> release() async {
    final int? handle = _handle;
    if (handle == null || _window.isEmpty) return;
    await bridge.evict(handle, _window.toList()..sort());
    _window = <int>{};
    _current = -1;
  }
}
