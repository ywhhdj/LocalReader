import 'package:flutter/foundation.dart';

import '../../../domain/usecases/library_query.dart';

/// 漫画分话目录识别 + 竖向阅读布局度量（纯 Dart，零平台依赖）。
///
/// 对应原项目 README：「漫画目录分话识别、竖向阅读交互、收藏路由与书架筛选」。
/// 静态口径：**只从归档内的路径 / 文件名识别话集**，不解压、不解码图片、
/// 不读文件内容；页像素由 BookRenderBridge 提供（❄️ 冻结），这里只做
/// 「页顺序 → 话集 → 滚动偏移」的编排，所以宽高比用占位值，页面不会假装能显示漫画。

/// 漫画阅读模式：竖向连续滚动 / 单页横向翻页。
enum ComicReadMode { vertical, paged }

class ComicModeLabels {
  const ComicModeLabels._();

  static const Map<ComicReadMode, String> labels = <ComicReadMode, String>{
    ComicReadMode.vertical: '竖向连续',
    ComicReadMode.paged: '横向翻页',
  };

  static const Map<ComicReadMode, String> hints = <ComicReadMode, String>{
    ComicReadMode.vertical: '按页宽高比占位，连续上下滚动；话首自动插入分隔标题',
    ComicReadMode.paged: '横向跨页翻页（可双页 / 右 → 左），复用小说阅读器的翻页动效设置',
  };
}

enum ComicEpisodeKind { main, special }

@immutable
class ComicEpisode {
  const ComicEpisode({
    required this.id,
    required this.label,
    required this.pageStart,
    required this.pageCount,
    this.number,
    this.kind = ComicEpisodeKind.main,
    this.recognized = true,
  });

  final String id;
  final String label;

  /// 该话第一页在**重排后页序**中的下标。
  final int pageStart;
  final int pageCount;
  final int? number;
  final ComicEpisodeKind kind;

  /// false = 文件名没能识别出话集，归入「未分话」。
  final bool recognized;

  int get pageEndExclusive => pageStart + pageCount;
  bool containsPage(int page) => page >= pageStart && page < pageEndExclusive;

  String get pageRangeLabel => pageCount <= 0
      ? '0 页'
      : 'P${pageStart + 1}–P$pageEndExclusive';

  @override
  bool operator ==(Object other) =>
      other is ComicEpisode &&
      other.id == id &&
      other.label == label &&
      other.pageStart == pageStart &&
      other.pageCount == pageCount &&
      other.number == number &&
      other.kind == kind &&
      other.recognized == recognized;

  @override
  int get hashCode => Object.hash(id, label, pageStart, pageCount, number, kind, recognized);
}

@immutable
class ComicToc {
  const ComicToc({
    required this.episodes,
    required this.pagePaths,
  });

  final List<ComicEpisode> episodes;

  /// 按话集排序后的最终页序。未来接真实桥接时，它就是 render(index) 的索引表。
  final List<String> pagePaths;

  static ComicToc get empty => const ComicToc(
        episodes: <ComicEpisode>[],
        pagePaths: <String>[],
      );

  int get pageCount => pagePaths.length;
  int get episodeCount => episodes.length;
  bool get isEmpty => pageCount == 0;
  bool get isSplit => episodes.length > 1;

  int get recognizedPages => episodes.fold<int>(
        0,
        (int s, ComicEpisode e) => s + (e.recognized ? e.pageCount : 0),
      );

  /// 识别率供页面提示：识别不全时明确告诉用户「部分页归入未分话」，不静默吞页。
  double get recognitionRate =>
      pageCount == 0 ? 0 : recognizedPages / pageCount;

  ComicEpisode? episodeForPage(int page) {
    if (page < 0 || page >= pageCount) return null;
    for (final ComicEpisode e in episodes) {
      if (e.containsPage(page)) return e;
    }
    return null;
  }

  int? episodeIndexForPage(int page) {
    if (page < 0 || page >= pageCount) return null;
    for (int i = 0; i < episodes.length; i++) {
      if (episodes[i].containsPage(page)) return i;
    }
    return null;
  }

  int pageForEpisode(int episodeIndex) {
    if (episodes.isEmpty) return 0;
    return episodes[episodeIndex.clamp(0, episodes.length - 1)].pageStart;
  }

  /// 话首标记：只有该话第一页带 headerLabel，避免每页都重复标题。
  String? headerForPage(int page) {
    final ComicEpisode? e = episodeForPage(page);
    if (e == null || e.pageStart != page) return null;
    return e.label;
  }
}

@immutable
class _EpisodeKey {
  const _EpisodeKey(this.label, this.number, this.kind);
  final String label;
  final int? number;
  final ComicEpisodeKind kind;
}

class _Group {
  _Group(this.key, this.recognized);
  final _EpisodeKey key;
  final bool recognized;
  final List<String> paths = <String>[];
}

/// 分话识别器。输入是归档内的相对路径（或图片文件夹里的相对路径），
/// 输出是**页序已按话集重排**的 ComicToc。
class ComicTocParser {
  const ComicTocParser._();

  static const Set<String> imageExtensions = <String>{
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp',
  };

  static final RegExp _cnEpisode = RegExp(
    r'第\s*([0-9]+|[零〇一二两三四五六七八九十百]+)\s*(话|回|章|卷|集|部)',
  );
  static final RegExp _enEpisode = RegExp(
    r'(chapter|ch|ep|episode|vol|volume)\s*[.\-#]?\s*([0-9]+)',
    caseSensitive: false,
  );
  static final RegExp _hashEpisode = RegExp(r'#\s*([0-9]+)');
  // sp 用单词边界，避免把 spread / spring 这类目录误判成番外。
  static final RegExp _special = RegExp(
    r'(番外|特别篇|附录|后日谈|extra|omake|special|\bsp\b)',
    caseSensitive: false,
  );

  static ComicToc fromPaths(Iterable<String> rawPaths) {
    // 1. 只保留图片；2. 先按路径自然排序，保证 001 / 002 / 010 不被字典序打乱。
    final List<String> paths = <String>[
      for (final String p in rawPaths)
        if (isImagePath(p)) p,
    ]..sort(LibraryQuery.naturalCompare);
    if (paths.isEmpty) return ComicToc.empty;

    // 3. 分组：优先用最后一级目录名，失败再用文件名主干。
    final Map<String, _Group> groups = <String, _Group>{};
    for (final String path in paths) {
      final _EpisodeKey? key = _keyForPath(path);
      final _EpisodeKey effective = key ?? const _EpisodeKey('未分话', null, ComicEpisodeKind.main);
      final _Group group = groups.putIfAbsent(
        effective.label,
        () => _Group(effective, key != null),
      );
      group.paths.add(path);
    }

    // 4. 话集排序：正篇在前、番外在后；正篇按话号升序，无号按标签自然排序。
    final List<_Group> sorted = groups.values.toList();
    sorted.sort((_Group a, _Group b) {
      final int byKind = a.key.kind.index.compareTo(b.key.kind.index);
      if (byKind != 0) return byKind;
      final int? na = a.key.number;
      final int? nb = b.key.number;
      if (na != null && nb != null && na != nb) return na.compareTo(nb);
      if (na != null && nb == null) return -1;
      if (na == null && nb != null) return 1;
      return LibraryQuery.naturalCompare(a.key.label, b.key.label);
    });

    // 5. 重排页序并重算 pageStart（话集排序后页码必须跟着变，否则跳转会错位）。
    final List<String> orderedPaths = <String>[];
    final List<ComicEpisode> episodes = <ComicEpisode>[];
    int cursor = 0;
    for (int i = 0; i < sorted.length; i++) {
      final _Group g = sorted[i];
      episodes.add(ComicEpisode(
        id: 'ep-$i',
        label: g.key.label,
        pageStart: cursor,
        pageCount: g.paths.length,
        number: g.key.number,
        kind: g.key.kind,
        recognized: g.recognized,
      ));
      orderedPaths.addAll(g.paths);
      cursor += g.paths.length;
    }

    return ComicToc(
      episodes: List<ComicEpisode>.unmodifiable(episodes),
      pagePaths: List<String>.unmodifiable(orderedPaths),
    );
  }

  static bool isImagePath(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    return imageExtensions.contains(path.substring(dot + 1).toLowerCase());
  }

  static _EpisodeKey? _keyForPath(String path) {
    final List<String> parts = path.split(RegExp(r'[/\\]'));
    final String fileName = parts.isEmpty ? path : parts.last;
    final int dot = fileName.lastIndexOf('.');
    final String stem = dot < 0 ? fileName : fileName.substring(0, dot);

    // 目录优先：/Vol.02/001.jpg 这类结构比文件名可靠。
    if (parts.length >= 2) {
      final String dir = parts[parts.length - 2].trim();
      final _EpisodeKey? fromDir = _parse(dir);
      if (fromDir != null) return fromDir;
    }
    return _parse(stem);
  }

  static _EpisodeKey? _parse(String raw) {
    final String s = raw.trim();
    if (s.isEmpty) return null;

    // 番外 / 特别篇：无话号，排在全部正篇之后。
    if (_special.hasMatch(s)) {
      return _EpisodeKey(_cleanLabel(s), null, ComicEpisodeKind.special);
    }

    final RegExpMatch? cn = _cnEpisode.firstMatch(s);
    if (cn != null) {
      final int? n = _toNumber(cn.group(1)!);
      if (n != null) {
        return _EpisodeKey('第 $n ${cn.group(2)}', n, ComicEpisodeKind.main);
      }
    }

    final RegExpMatch? en = _enEpisode.firstMatch(s);
    if (en != null) {
      final int n = int.parse(en.group(2)!);
      final String prefix = en.group(1)!.toLowerCase();
      final bool volume = prefix == 'vol' || prefix == 'volume';
      return _EpisodeKey(volume ? 'Vol. $n' : 'Chapter $n', n, ComicEpisodeKind.main);
    }

    final RegExpMatch? hash = _hashEpisode.firstMatch(s);
    if (hash != null) {
      final int n = int.parse(hash.group(1)!);
      return _EpisodeKey('#$n', n, ComicEpisodeKind.main);
    }
    return null;
  }

  static String _cleanLabel(String s) {
    final String collapsed = s.replaceAll(RegExp(r'[\s_\-]+'), ' ').trim();
    return collapsed.length > 24 ? collapsed.substring(0, 24) : collapsed;
  }

  /// 阿拉伯数字或常见中文数字（十/百），复用不到 LibraryQuery 的私有实现，
  /// 这里单列一份以便规格单测逐项断言。
  static int? _toNumber(String raw) {
    if (RegExp(r'^[0-9]+$').hasMatch(raw)) return int.tryParse(raw);
    int section = 0;
    int digit = 0;
    for (final int c in raw.runes) {
      final int? d = _cnDigit(c);
      if (d != null) {
        digit = d;
      } else if (c == 0x5341) { // 十
        section += (digit == 0 ? 1 : digit) * 10;
        digit = 0;
      } else if (c == 0x767E) { // 百
        section += (digit == 0 ? 1 : digit) * 100;
        digit = 0;
      } else {
        return null;
      }
    }
    return section + digit;
  }

  static int? _cnDigit(int c) {
    switch (c) {
      case 0x96F6: // 零
      case 0x3007: // 〇
        return 0;
      case 0x4E00: return 1; // 一
      case 0x4E8C: return 2; // 二
      case 0x4E24: return 2; // 两
      case 0x4E09: return 3;
      case 0x56DB: return 4;
      case 0x4E94: return 5;
      case 0x516D: return 6;
      case 0x4E03: return 7;
      case 0x516B: return 8;
      case 0x4E5D: return 9;
      default: return null;
    }
  }
}

// ---------------------------------------------------------------- 竖向布局

/// 竖向滚动里每一页的占位描述。宽高比来自 PageInfo.aspectRatio（真实桥接），
/// 静态阶段用确定性占位值，保证滚动偏移可计算、可单测。
@immutable
class ComicPageItem {
  const ComicPageItem({
    required this.pageIndex,
    required this.aspectRatio,
    this.headerLabel,
  });

  final int pageIndex;
  final double aspectRatio;
  final String? headerLabel;
}

@immutable
class ComicLayoutMetrics {
  const ComicLayoutMetrics({
    required this.pageWidth,
    this.pageGap = 12,
    this.headerHeight = 44,
    this.minAspectRatio = 0.35,
    this.maxAspectRatio = 3.0,
  });

  final double pageWidth;
  final double pageGap;
  final double headerHeight;
  final double minAspectRatio;
  final double maxAspectRatio;

  double clampedRatio(double r) => r.clamp(minAspectRatio, maxAspectRatio).toDouble();

  double pageHeight(ComicPageItem item) => pageWidth / clampedRatio(item.aspectRatio);

  double itemHeight(ComicPageItem item) =>
      pageHeight(item) + (item.headerLabel == null ? 0 : headerHeight) + pageGap;

  /// prefix[i] = 第 i 项的起始偏移；末尾多一项表示总高度，便于二分与 clamp。
  List<double> prefixOffsets(List<ComicPageItem> items) {
    final List<double> out = <double>[0];
    double acc = 0;
    for (final ComicPageItem item in items) {
      acc += itemHeight(item);
      out.add(acc);
    }
    return List<double>.unmodifiable(out);
  }

  /// 由滚动偏移反查当前页：二分找最后一个 prefix[i] <= offset。
  int pageAtOffset(List<double> prefix, double offset) {
    if (prefix.length <= 1) return 0;
    final double clamped = offset.clamp(0, prefix.last).toDouble();
    int lo = 0;
    int hi = prefix.length - 2;
    while (lo < hi) {
      final int mid = (lo + hi + 1) >> 1;
      if (prefix[mid] <= clamped) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  static List<ComicPageItem> buildItems(
    ComicToc toc, {
    double defaultAspectRatio = 0.7,
    List<double>? aspectRatios,
  }) =>
      List<ComicPageItem>.unmodifiable(
        List<ComicPageItem>.generate(
          toc.pageCount,
          (int i) => ComicPageItem(
            pageIndex: i,
            aspectRatio: (aspectRatios != null && i < aspectRatios.length)
                ? aspectRatios[i]
                : defaultAspectRatio,
            headerLabel: toc.headerForPage(i),
          ),
        ),
      );
}
