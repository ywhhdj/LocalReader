import 'dart:math' as math;

/// 榜单分段：日 / 周 / 月 / 总 / 分类 / 出版文库。
enum RankKind { daily, weekly, monthly, all, category, imprint }

/// 每段自带「更多 →」，横向懒加载 ListView.builder + 固定 cacheExtent。
class RankingSection {
  const RankingSection({
    required this.kind,
    required this.labelKey,
    this.bookIds = const <String>[],
    this.hasMore = false,
    this.page = 1,
    this.cacheExtent = 480,
  });

  final RankKind kind;
  final String labelKey;
  final List<String> bookIds;
  final bool hasMore;
  final int page;
  final double cacheExtent;

  bool get isEmpty => bookIds.isEmpty;
}

const List<RankKind> kRankingOrder = <RankKind>[
  RankKind.daily,
  RankKind.weekly,
  RankKind.monthly,
  RankKind.all,
  RankKind.category,
  RankKind.imprint,
];

/// 候选书的最小投影：只含打分所需字段，不承载正文 / 插图。
class BookCandidate {
  const BookCandidate({
    required this.id,
    required this.title,
    this.categories = const <String>[],
    this.author = '',
    this.tags = const <String>[],
    this.popularity = 0,
  });

  final String id;
  final String title;
  final List<String> categories;
  final String author;
  final List<String> tags;
  final double popularity;
}

/// 本地阅读口味信号（来自 ReadingStats，不额外发请求）。
class TasteSignal {
  const TasteSignal({
    this.categories = const <String, double>{},
    this.authors = const <String, double>{},
    this.tags = const <String, double>{},
    this.readIds = const <String>{},
    this.lastReadAt,
  });

  final Map<String, double> categories;
  final Map<String, double> authors;
  final Map<String, double> tags;
  final Set<String> readIds;
  final DateTime? lastReadAt;
}

/// score = 0.45·类别匹配 + 0.25·作者匹配 + 0.20·标签匹配
///         + 0.10·近期热度 − 已读惩罚
class RecommendationWeights {
  const RecommendationWeights({
    this.category = 0.45,
    this.author = 0.25,
    this.tag = 0.20,
    this.popularity = 0.10,
    this.readPenalty = 1.0,
    this.decayDays = 30,
  });

  final double category;
  final double author;
  final double tag;
  final double popularity;
  final double readPenalty;
  final int decayDays;

  double get sum =>
      category + author + tag + popularity; // 归一化后应为 1.0
}

/// 推荐只来自「本地统计 + 已缓存的公开榜单」：不因推荐发新请求、
class RecommendationEngine {
  const RecommendationEngine({
    this.weights = const RecommendationWeights(),
    this.cachedOnly = true,
  });

  final RecommendationWeights weights;
  final bool cachedOnly;

  double _match(List<String> values, Map<String, double> taste) {
    if (values.isEmpty || taste.isEmpty) return 0;
    double best = 0;
    for (final String v in values) {
      final double w = taste[v] ?? 0;
      if (w > best) best = w;
    }
    return best.clamp(0.0, 1.0).toDouble();
  }

  double score(BookCandidate book, TasteSignal taste, DateTime now) {
    final double cat = weights.category * _match(book.categories, taste.categories);
    final double au = weights.author *
        (taste.authors[book.author] ?? 0).clamp(0.0, 1.0).toDouble();
    final double tg = weights.tag * _match(book.tags, taste.tags);
    final double pop = weights.popularity *
        book.popularity.clamp(0.0, 1.0).toDouble();

    // 近 30 天指数衰减：很久没读的口味权重整体收敛，避免推荐僵化。
    double decay = 1.0;
    final DateTime? last = taste.lastReadAt;
    if (last != null) {
      final int days = now.difference(last).inDays.abs();
      decay = math.exp(-days / weights.decayDays);
    }
    final double readPenalty =
        taste.readIds.contains(book.id) ? weights.readPenalty : 0;
    return (cat + au + tg + pop) * decay - readPenalty;
  }

  /// 已读优先过滤，再按分数倒序；空口味信号时返回空列表（不伪造推荐）。
  List<BookCandidate> rank(
    List<BookCandidate> candidates,
    TasteSignal taste, {
    DateTime? now,
    int limit = 20,
  }) {
    if (!cachedOnly || _tasteIsEmpty(taste)) return <BookCandidate>[];
    final DateTime t = now ?? DateTime.fromMillisecondsSinceEpoch(0);
    final List<BookCandidate> pool = candidates
        .where((BookCandidate b) => !taste.readIds.contains(b.id))
        .toList();
    pool.sort((BookCandidate a, BookCandidate b) =>
        score(b, taste, t).compareTo(score(a, taste, t)));
    return pool.length <= limit ? pool : pool.sublist(0, limit);
  }

  bool _tasteIsEmpty(TasteSignal t) =>
      t.categories.isEmpty && t.authors.isEmpty && t.tags.isEmpty;
}

/// 文库页状态
class WenkuLibraryState {
  const WenkuLibraryState({
    this.sections = const <RankingSection>[],
    this.recommended = const <BookCandidate>[],
    this.loading = false,
    this.rateLimited = false,
    this.upstreamChanged = false,
    this.offline = false,
    this.empty = false,
    this.noticeSeen = false,
  });

  final List<RankingSection> sections;
  final List<BookCandidate> recommended;
  final bool loading;
  final bool rateLimited;
  final bool upstreamChanged;
  final bool offline;
  final bool empty;
  final bool noticeSeen;

  /// 状态互斥：loading 不画空态；提示页不产生 offline。
  WenkuLibraryState normalized() => WenkuLibraryState(
        sections: sections,
        recommended: recommended,
        loading: loading,
        rateLimited: !loading && rateLimited,
        upstreamChanged: !loading && upstreamChanged,
        offline: !loading && offline && !noticeSeen,
        empty: !loading && empty,
        noticeSeen: noticeSeen,
      );
}
