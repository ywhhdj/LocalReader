import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/model/book_document.dart';
import '../../domain/repositories/render_bridge.dart';
import 'comic/comic_prefetch.dart';
import 'native_page_view.dart';

/// PDF / 图片型 EPUB 的固定版式阅读视图。
///
/// 此前 `reader_page` 里的 `NativePageView` 句柄写死 0，永远拿不到真实页。
/// 这里先 `open()` 取句柄与页数，再按页渲染 Texture / 编码位图，
/// 并把预取窗口挂到真实句柄；原生通道未就绪时给出明确提示而不是空白页。
class FixedLayoutView extends StatefulWidget {
  const FixedLayoutView({
    super.key,
    required this.bridge,
    required this.document,
    required this.pageSize,
    this.prefetch,
    this.onVisiblePage,
  });

  final BookRenderBridge bridge;
  final BookDocument document;
  final Size pageSize;
  final ComicPrefetchWindow? prefetch;
  final ValueChanged<int>? onVisiblePage;

  @override
  State<FixedLayoutView> createState() => _FixedLayoutViewState();
}

class _FixedLayoutViewState extends State<FixedLayoutView> {
  int? _handle;
  int _pageCount = 0;
  int _currentPage = 0;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final int handle = await widget.bridge.open(
        widget.document.id,
        widget.document.sourcePath,
      );
      final int count = await widget.bridge.pageCount(handle);
      if (!mounted) return;
      setState(() {
        _handle = handle;
        _pageCount = count;
      });
      widget.prefetch?.attach(handle, count);
      _syncWindow(0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unavailable = true);
    }
  }

  void _syncWindow(int index) {
    if (_handle == null || _pageCount <= 0) return;
    widget.prefetch?.moveToPages(<int>[
      for (int i = index - 1; i <= index + 2; i++)
        if (i >= 0 && i < _pageCount) i,
    ]);
  }

  @override
  void dispose() {
    final int? handle = _handle;
    if (handle != null) unawaited(widget.bridge.close(handle));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '原生渲染通道未就绪：请确认已安装三端 RenderPlugin，'
            '或把该文档转换为 CBZ / ZIP 后重新导入。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    final int? handle = _handle;
    if (handle == null || _pageCount == 0) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: PageView.builder(
            itemCount: _pageCount,
            onPageChanged: (int i) {
              _currentPage = i;
              widget.onVisiblePage?.call(i);
              _syncWindow(i);
              setState(() {});
            },
            itemBuilder: (BuildContext context, int i) => NativePageView(
              bridge: widget.bridge,
              handle: handle,
              pageIndex: i,
              targetSize: widget.pageSize,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '第 ${_currentPage + 1} / $_pageCount 页',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}
