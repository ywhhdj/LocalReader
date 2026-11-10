import 'package:flutter/foundation.dart';

import 'book_repository.dart';

/// 书库排序口径。卷序优先：已分卷的书排在「未分卷」之前，同卷内按书名自然排序。
enum LibrarySort { volume, title, progress }

/// 空状态分类：让「书库为空」与「没有匹配的书」给出不同引导，
/// 而不是一律显示「暂无数据」。对齐原项目「无权限时导入对话框明确提示当前状态」。
enum LibraryEmptyKind { none, noLibrary, noResult, noFavorites }

/// 纯 Dart 查询层：不依赖 Flutter widget、不依赖仓储实现，可直接写成规格单测。
/// 对齐原 Kotlin 工程 `core/common` 里的「自然排序」工具：
/// 「第 2 卷」必须排在「第 10 卷」前面，字典序会把 10 排到 2 前面。
class LibraryQuery {
  const LibraryQuery._();

  static const Map<LibrarySort, String> sortLabels = <LibrarySort, String>{
    LibrarySort.volume: '按卷序',
    LibrarySort.title: '按书名',
    LibrarySort.progress: '按进度',
  };

  /// 阿拉伯数字与常见中文数字混合的自然比较。
  /// 非数字段按 code unit 比较；数字段按数值比较，数值相等时短串在前（"第2卷" < "第02卷"）。
  static int naturalCompare(String a, String b) {
    int i = 0;
    int j = 0;
    while (i < a.length && j < b.length) {
      final int ca = a.codeUnitAt(i);
      final int cb = b.codeUnitAt(j);
      final bool na = _isDigit(ca);
      final bool nb = _isDigit(cb);

      if (na && nb) {
        final _NumberRun ra = _readNumber(a, i);
        final _NumberRun rb = _readNumber(b, j);
        if (ra.value != rb.value) return ra.value < rb.value ? -1 : 1;
        if (ra.length != rb.length) return ra.length < rb.length ? -1 : 1;
        i = ra.end;
        j = rb.end;
        continue;
      }
      if (ca != cb) return ca < cb ? -1 : 1;
      i++;
      j++;
    }
    if (i == a.length && j == b.length) return 0;
    return i == a.length ? -1 : 1;
  }

  static bool _isDigit(int c) =>
      (c >= 0x30 && c <= 0x39) || _cnDigit(c) != null || c == 0x5341 || c == 0x767E; // 十 / 百

  static int? _cnDigit(int c) {
    switch (c) {
      case 0x96F6: // 零
      case 0x3007: // 〇
        return 0;
      case 0x4E00: return 1; // 一
      case 0x4E8C: return 2; // 二
      case 0x4E24: return 2; // 两
      case 0x4E09: return 3; // 三
      case 0x56DB: return 4; // 四
      case 0x4E94: return 5; // 五
      case 0x516D: return 6; // 六
      case 0x4E03: return 7; // 七
      case 0x516B: return 8; // 八
      case 0x4E5D: return 9; // 九
      default: return null;
    }
  }

  /// 读取一段数字：支持 "10"、"第十章" 的 "十"、"十二"、"一百二" 这类常见中文数字。
  /// 只处理到百位，覆盖卷序 / 章节名排序的常见写法即可。
  static _NumberRun _readNumber(String s, int start) {
    final bool ascii = s.codeUnitAt(start) >= 0x30 && s.codeUnitAt(start) <= 0x39;
    if (ascii) {
      int end = start;
      while (end < s.length && s.codeUnitAt(end) >= 0x30 && s.codeUnitAt(end) <= 0x39) {
        end++;
      }
      return _NumberRun(int.parse(s.substring(start, end)), end - start, end);
    }

    int end = start;
    int total = 0;
    int section = 0;
    int digit = 0;
    while (end < s.length) {
      final int c = s.codeUnitAt(end);
      final int? d = _cnDigit(c);
      if (d != null) {
        digit = d;
        end++;
      } else if (c == 0x5341 || c == 0x767E) { // 十 / 百
        final int unit = c == 0x5341 ? 10 : 100;
        section += (digit == 0 ? 1 : digit) * unit;
        digit = 0;
        end++;
      } else {
        break;
      }
    }
    total = section + digit;
    if (end == start) return _NumberRun(0, 1, start + 1);
    return _NumberRun(total, end - start, end);
  }

  /// 搜索：书名、作者、格式、分组名都参与；大小写不敏感（中文不受影响）。
  static bool matches(BookSummary book, String query) {
    if (query.trim().isEmpty) return true;
    final String q = query.trim().toLowerCase();
    return book.title.toLowerCase().contains(q) ||
        book.author.toLowerCase().contains(q) ||
        book.format.toLowerCase().contains(q) ||
        book.shelf.toLowerCase().contains(q);
  }

  /// 统一查询出口。调用方传入的 books 应已套用元数据覆盖层（AppState.library 负责）。
  static List<BookSummary> apply({
    required List<BookSummary> books,
    String query = '',
    String? shelf,
    LibrarySort sort = LibrarySort.volume,
    bool favoritesOnly = false,
    Set<String> favoriteIds = const <String>{},
  }) {
    final List<BookSummary> filtered = <BookSummary>[
      for (final BookSummary b in books)
        if ((shelf == null || b.shelf == shelf) &&
            (!favoritesOnly || favoriteIds.contains(b.id)) &&
            matches(b, query)) b,
    ];
    filtered.sort((BookSummary a, BookSummary b) => _compare(a, b, sort));
    return List<BookSummary>.unmodifiable(filtered);
  }

  static int _compare(BookSummary a, BookSummary b, LibrarySort sort) {
    switch (sort) {
      case LibrarySort.volume:
        // 0 = 未分卷，排最后；同卷按书名自然排序，最后用 id 保证稳定。
        final int av = a.volumeOrder == 0 ? 1 << 30 : a.volumeOrder;
        final int bv = b.volumeOrder == 0 ? 1 << 30 : b.volumeOrder;
        if (av != bv) return av.compareTo(bv);
        final int byTitle = naturalCompare(a.title, b.title);
        return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
      case LibrarySort.title:
        final int byTitle = naturalCompare(a.title, b.title);
        return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
      case LibrarySort.progress:
        final int byProgress = b.progress.compareTo(a.progress);
        return byProgress != 0 ? byProgress : naturalCompare(a.title, b.title);
    }
  }

  /// 按分组计数（不受 query 影响），用于书架标题旁的「共 N 册」。
  static Map<String, int> shelfCounts(Iterable<BookSummary> books) {
    final Map<String, int> counts = <String, int>{};
    for (final BookSummary b in books) {
      counts[b.shelf] = (counts[b.shelf] ?? 0) + 1;
    }
    return Map<String, int>.unmodifiable(counts);
  }

  /// 把结果按分组切成有序区块，搜索结果页用它渲染 section。
  static Map<String, List<BookSummary>> groupByShelf(
    Iterable<BookSummary> books, {
    required List<String> shelfOrder,
  }) {
    final Map<String, List<BookSummary>> out = <String, List<BookSummary>>{
      for (final String s in shelfOrder) s: <BookSummary>[],
    };
    for (final BookSummary b in books) {
      out.putIfAbsent(b.shelf, () => <BookSummary>[]).add(b);
    }
    return Map<String, List<BookSummary>>.unmodifiable(out);
  }

  static LibraryEmptyKind emptyKind({
    required int total,
    required int matched,
    required String query,
    bool favoritesOnly = false,
    int favoriteCount = 0,
  }) {
    if (matched > 0) return LibraryEmptyKind.none;
    // 「只看收藏」且一条收藏都没有 → 单独引导去加收藏，
    // 不能误报成「书库为空」或「换关键词」。
    if (favoritesOnly && favoriteCount == 0) return LibraryEmptyKind.noFavorites;
    if (total == 0) return LibraryEmptyKind.noLibrary;
    return query.trim().isEmpty ? LibraryEmptyKind.noLibrary : LibraryEmptyKind.noResult;
  }
}

@immutable
class _NumberRun {
  const _NumberRun(this.value, this.length, this.end);
  final int value;
  final int length;
  final int end;
}
