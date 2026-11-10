import 'dart:async';

import '../../core/model/book_document.dart';

abstract interface class ProgressStore {
  Future<void> write(ReadingProgress progress);
  Future<ReadingProgress?> read(String bookId);
}

/// 对应原项目「滚动/翻页期间按固定间隔采样落库（含页内位置），退出前兜底再写一次」。
/// 用时间戳节流而不是每帧写库；页面 dispose / 应用退到后台时必须显式 flush。
class ProgressSampler {
  ProgressSampler({required this.store, this.interval = const Duration(seconds: 2)});

  final ProgressStore store;
  final Duration interval;

  ReadingProgress? _latest;
  DateTime? _lastFlush;
  bool _dirty = false;

  void record(ReadingProgress progress) {
    _latest = progress;
    _dirty = true;
    final DateTime now = DateTime.now();
    if (_lastFlush == null || now.difference(_lastFlush!) >= interval) {
      unawaited(flush());
    }
  }

  /// 页内偏移单独更新，不重置节流计时。
  void updatePageOffset(double offset) {
    if (_latest == null) return;
    _latest = _latest!.copyWith(pageOffset: offset, updatedAt: DateTime.now());
    _dirty = true;
  }

  Future<void> flush() async {
    if (!_dirty || _latest == null) return;
    final ReadingProgress snapshot = _latest!;
    _dirty = false;
    _lastFlush = DateTime.now();
    await store.write(snapshot);
  }

  /// 窗口尺寸变化会重排页码，进度必须靠 PageAnchor 而不是 pageIndex 还原。
  Future<ReadingProgress?> restore(String bookId) => store.read(bookId);
}

/// 内存实现仅用于 P0/P1 演示；P2 换成 Drift/Isar，并从第一天登记迁移版本。
class InMemoryProgressStore implements ProgressStore {
  final Map<String, ReadingProgress> _data = <String, ReadingProgress>{};

  @override
  Future<void> write(ReadingProgress progress) async {
    _data[progress.bookId] = progress;
  }

  @override
  Future<ReadingProgress?> read(String bookId) async => _data[bookId];
}
