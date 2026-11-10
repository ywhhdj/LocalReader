import 'package:flutter/foundation.dart';

import 'book_repository.dart';

/// 书架视图偏好（第二十四轮）。
///
/// 参考仓库 README：「Three-dimensional shelves or lists: A looping carousel
/// with inertial snapping and haptics, or a straightforward list. Filter by
/// category, reading status, and source. Keep the local library separate or
/// merge it with your bookshelf.」
enum ShelfViewMode { carousel3d, list }

enum ReadingStatusFilter { all, unread, reading, finished }

enum BookSourceFilter { all, local, cloud }

@immutable
class ShelfPrefs {
  const ShelfPrefs({
    this.mode = ShelfViewMode.carousel3d,
    this.inertialSnapping = true,
    this.haptics = true,
    this.loop = true,
    this.status = ReadingStatusFilter.all,
    this.source = BookSourceFilter.all,
    this.category = '',
    this.mergeLocalIntoShelf = false,
  });

  final ShelfViewMode mode;
  final bool inertialSnapping;
  final bool haptics;
  final bool loop;
  final ReadingStatusFilter status;
  final BookSourceFilter source;
  final String category;
  final bool mergeLocalIntoShelf;

  static const Map<ShelfViewMode, String> modeLabels = <ShelfViewMode, String>{
    ShelfViewMode.carousel3d: '3D 书架',
    ShelfViewMode.list: '列表',
  };

  static const Map<ReadingStatusFilter, String> statusLabels =
      <ReadingStatusFilter, String>{
    ReadingStatusFilter.all: '全部',
    ReadingStatusFilter.unread: '未读',
    ReadingStatusFilter.reading: '在读',
    ReadingStatusFilter.finished: '已读完',
  };

  static const Map<BookSourceFilter, String> sourceLabels =
      <BookSourceFilter, String>{
    BookSourceFilter.all: '全部来源',
    BookSourceFilter.local: '本地导入',
    BookSourceFilter.cloud: '云端目录',
  };

  ShelfPrefs copyWith({
    ShelfViewMode? mode,
    bool? inertialSnapping,
    bool? haptics,
    bool? loop,
    ReadingStatusFilter? status,
    BookSourceFilter? source,
    String? category,
    bool? mergeLocalIntoShelf,
    bool clearCategory = false,
  }) =>
      ShelfPrefs(
        mode: mode ?? this.mode,
        inertialSnapping: inertialSnapping ?? this.inertialSnapping,
        haptics: haptics ?? this.haptics,
        loop: loop ?? this.loop,
        status: status ?? this.status,
        source: source ?? this.source,
        category: clearCategory ? '' : (category ?? this.category),
        mergeLocalIntoShelf: mergeLocalIntoShelf ?? this.mergeLocalIntoShelf,
      );

  /// 归一化：**列表模式下轮播参数无意义**，锁回默认，避免「设了没反应」。
  ShelfPrefs normalized() => mode == ShelfViewMode.carousel3d
      ? this
      : copyWith(inertialSnapping: false, haptics: false, loop: false);

  /// 筛选唯一出口：页面不自己写「进度 >= 1 算读完」这类规则。
  List<BookSummary> apply(List<BookSummary> books) {
    final List<BookSummary> out = <BookSummary>[];
    for (final BookSummary b in books) {
      if (!_statusMatches(b.progress)) continue;
      if (!_sourceMatches(b)) continue;
      if (category.isNotEmpty && b.shelf != category) continue;
      out.add(b);
    }
    return List<BookSummary>.unmodifiable(out);
  }

  bool _statusMatches(double progress) {
    switch (status) {
      case ReadingStatusFilter.all:
        return true;
      case ReadingStatusFilter.unread:
        return progress <= 0;
      case ReadingStatusFilter.finished:
        return progress >= 1;
      case ReadingStatusFilter.reading:
        return progress > 0 && progress < 1;
    }
  }

  bool _sourceMatches(BookSummary b) {
    switch (source) {
      case BookSourceFilter.all:
        return true;
      case BookSourceFilter.cloud:
        return b.id.startsWith('cloud-');
      case BookSourceFilter.local:
        return !b.id.startsWith('cloud-');
    }
  }

  bool get hasFilters =>
      status != ReadingStatusFilter.all ||
      source != BookSourceFilter.all ||
      category.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is ShelfPrefs &&
      other.mode == mode &&
      other.inertialSnapping == inertialSnapping &&
      other.haptics == haptics &&
      other.loop == loop &&
      other.status == status &&
      other.source == source &&
      other.category == category &&
      other.mergeLocalIntoShelf == mergeLocalIntoShelf;

  @override
  int get hashCode => Object.hash(mode, inertialSnapping, haptics, loop,
      status, source, category, mergeLocalIntoShelf);
}
