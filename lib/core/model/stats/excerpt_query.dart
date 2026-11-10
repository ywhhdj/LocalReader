import 'package:flutter/foundation.dart';

import '../../../domain/usecases/library_query.dart';
import 'excerpt_capture.dart';
import 'excerpt_title_lookup.dart';
import 'reading_stats.dart';
import 'stats_date.dart';

/// 摘录管理页的纯 Dart 查询层。
///
/// 与书库一样钉死一条规则：**列表、筛选、排序、分组、导出口径只在这里算**，
/// 页面每次 build 从 `AppState.excerpts` 取最新列表再交给 `apply()`，
/// 不缓存、不自己写 `where`，否则阅读器新摘一条后管理页要重启才看得到。
///
/// 第十七轮：所有「按书名」的判断（搜索 / byBook 排序 / book 分组 / perBook
/// 汇总 / 筛选选项）统一走 `ExcerptTitleLookup`（书库当前名优先、快照兜底）。
/// 不传 `titles` 时全部回落快照，既有调用与规格单测行为不变。
/// **导出正文仍只用快照**，见 `ExcerptExporter` 注释——历史导出不随改名漂移。
///
/// 第二十一轮：加入 `dateKey` 单日筛选，供阅读日历「查看当天摘录」深链。
/// 日期 key 一律由 `stats_date.dart` 的 `dateKeyOf()` 生成，不自己拼年月日。
class ExcerptQuery {
  const ExcerptQuery._();

  static const Map<ExcerptSort, String> sortLabels = <ExcerptSort, String>{
    ExcerptSort.newest: '最近摘录',
    ExcerptSort.oldest: '最早摘录',
    ExcerptSort.byBook: '按书名',
    ExcerptSort.byColor: '按划线色',
  };

  static const Map<ExcerptGroup, String> groupLabels = <ExcerptGroup, String>{
    ExcerptGroup.none: '不分组',
    ExcerptGroup.book: '按书名',
    ExcerptGroup.color: '按划线色',
    ExcerptGroup.month: '按月份',
  };

  static const Map<ExcerptScope, String> scopeLabels = <ExcerptScope, String>{
    ExcerptScope.all: '全部',
    ExcerptScope.userOnly: '我摘的',
    ExcerptScope.withNote: '有批注',
  };

  /// 唯一查询出口。返回不可变列表，防止页面顺手改到全局数据。
  static List<Excerpt> apply({
    required List<Excerpt> excerpts,
    ExcerptFilter filter = const ExcerptFilter(),
    ExcerptSort sort = ExcerptSort.newest,
    ExcerptTitleLookup? titles,
  }) {
    final List<Excerpt> filtered = <Excerpt>[
      for (final Excerpt e in excerpts)
        if (matches(e, filter, titles: titles)) e,
    ];
    filtered.sort((Excerpt a, Excerpt b) => _compare(a, b, sort, titles));
    return List<Excerpt>.unmodifiable(filtered);
  }

  static bool matches(
    Excerpt e,
    ExcerptFilter f, {
    ExcerptTitleLookup? titles,
  }) {
    switch (f.scope) {
      case ExcerptScope.all:
        break;
      case ExcerptScope.userOnly:
        if (!e.isUserAdded) return false;
        break;
      case ExcerptScope.withNote:
        if (e.note.trim().isEmpty) return false;
        break;
    }
    if (f.bookId != null && e.bookId != f.bookId) return false;
    if (f.color != null && e.highlight != f.color) return false;
    if (f.dateKey != null && dateKeyOf(e.capturedAt) != f.dateKey) return false;
    if (f.query.trim().isEmpty) return true;

    final String q = f.query.trim().toLowerCase();
    return e.text.toLowerCase().contains(q) ||
        _bookTitleMatches(e, q, titles) ||
        e.chapterTitle.toLowerCase().contains(q) ||
        e.note.toLowerCase().contains(q);
  }

  /// 书名搜索的唯一出口：有 lookup 时走「当前名 ∪ 快照」，否则保持快照语义。
  static bool _bookTitleMatches(Excerpt e, String q, ExcerptTitleLookup? titles) =>
      titles != null
          ? titles.matchesBookTitle(e, q)
          : e.bookTitle.toLowerCase().contains(q);

  static String _displayTitle(Excerpt e, ExcerptTitleLookup? titles) =>
      titles?.titleOf(e) ?? ExcerptTitleLookup.snapshotOf(e);

  static int _compare(
    Excerpt a,
    Excerpt b,
    ExcerptSort sort, [
    ExcerptTitleLookup? titles,
  ]) {
    switch (sort) {
      case ExcerptSort.newest:
        final int byDate = b.capturedAt.compareTo(a.capturedAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      case ExcerptSort.oldest:
        final int byDate = a.capturedAt.compareTo(b.capturedAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      case ExcerptSort.byBook:
        // 复用书库的自然排序：「第 2 卷」不会排到「第 10 卷」后面。
        final int byTitle = LibraryQuery.naturalCompare(
          _displayTitle(a, titles),
          _displayTitle(b, titles),
        );
        if (byTitle != 0) return byTitle;
        final int byDate = b.capturedAt.compareTo(a.capturedAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      case ExcerptSort.byColor:
        final int byColor = a.highlight.index.compareTo(b.highlight.index);
        if (byColor != 0) return byColor;
        final int byDate = b.capturedAt.compareTo(a.capturedAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
    }
  }

  /// 按分组切成有序区块。Dart 的字面量 Map 是插入顺序稳定的 LinkedHashMap，
  /// 所以 section 顺序由 `apply()` 排好序后的第一条出现顺序决定。
  static Map<String, List<Excerpt>> group(
    List<Excerpt> excerpts, {
    ExcerptGroup by = ExcerptGroup.none,
    ExcerptTitleLookup? titles,
  }) {
    final Map<String, List<Excerpt>> out = <String, List<Excerpt>>{};
    for (final Excerpt e in excerpts) {
      out.putIfAbsent(groupKey(e, by, titles: titles), () => <Excerpt>[]).add(e);
    }
    return Map<String, List<Excerpt>>.unmodifiable(out);
  }

  static String groupKey(
    Excerpt e,
    ExcerptGroup by, {
    ExcerptTitleLookup? titles,
  }) {
    switch (by) {
      case ExcerptGroup.none:
        return '全部摘录';
      case ExcerptGroup.book:
        return _displayTitle(e, titles);
      case ExcerptGroup.color:
        return HighlightPalette.labels[e.highlight]!;
      case ExcerptGroup.month:
        return formatMonth(e.capturedAt);
    }
  }

  static ExcerptSummary summarize(
    List<Excerpt> excerpts, {
    ExcerptTitleLookup? titles,
  }) {
    final Map<String, int> perBook = <String, int>{};
    final Map<HighlightColor, int> perColor = <HighlightColor, int>{};
    int userCount = 0;
    int withNoteCount = 0;
    for (final Excerpt e in excerpts) {
      if (e.isUserAdded) userCount++;
      if (e.note.trim().isNotEmpty) withNoteCount++;
      final String title = _displayTitle(e, titles);
      perBook[title] = (perBook[title] ?? 0) + 1;
      perColor[e.highlight] = (perColor[e.highlight] ?? 0) + 1;
    }
    return ExcerptSummary(
      total: excerpts.length,
      userCount: userCount,
      withNoteCount: withNoteCount,
      perBook: Map<String, int>.unmodifiable(perBook),
      perColor: Map<HighlightColor, int>.unmodifiable(perColor),
    );
  }

  /// 某本书在**全部摘录**里的条数（不受当前筛选影响）。
  /// 详情页卡片与摘录页空状态共用这一个口径，避免两处各数一遍。
  static int countForBook(List<Excerpt> excerpts, String bookId) {
    int n = 0;
    for (final Excerpt e in excerpts) {
      if (e.bookId == bookId) n++;
    }
    return n;
  }

  /// 筛选器里「按书」的可选项：返回 id / 书名 / 条数，按书名自然排序。
  /// 用 bookId 作为筛选值，书名叫什么变体都不会让筛选失效。
  ///
  /// `pinnedBookId / pinnedTitle` 用于**详情深链**：一本书暂时零摘录时，
  /// `bookOptions(all)` 里根本没有它，筛选器就会变成看不见的幽灵条件——
  /// 用户看到「只显示某本书」却不知道是哪本，也无法点选回来。
  /// 因此把深链的书固定成一个 count=0 的选项，和真实选项同排序、同清除语义。
  ///
  /// `titleResolver` 是**展示层书名的唯一出口**：`Excerpt.bookTitle` 是捕获时的
  /// 快照（导出要稳定），而详情页可以编辑书名覆盖层。筛选 chip 与深链上下文
  /// 若用快照，就会出现「详情页叫《新书名》、筛选器还叫《旧书名》」的状态分裂。
  /// 传 `titleResolver: (id) => state.resolveBook(id)?.title` 后，两者同一次 build
  /// 都拿到书库当前书名；解析不到才回落快照。筛选值仍始终是 `bookId`。
  static List<ExcerptBookOption> bookOptions(
    List<Excerpt> excerpts, {
    String? pinnedBookId,
    String? pinnedTitle,
    String? Function(String bookId)? titleResolver,
    ExcerptTitleLookup? titles,
  }) {
    // 单一裁决点：页面传 lookup 时，titleResolver 只是它的等价旧入口。
    final String? Function(String bookId)? resolver = titles?.resolve ?? titleResolver;
    String displayTitle(String bookId, String snapshot) {
      final String? resolved = resolver?.call(bookId);
      if (resolved != null && resolved.trim().isNotEmpty) return resolved.trim();
      return snapshot.isEmpty ? '未标注书名' : snapshot;
    }

    final Map<String, _BookAgg> agg = <String, _BookAgg>{};
    for (final Excerpt e in excerpts) {
      final _BookAgg a = agg.putIfAbsent(
        e.bookId,
        () => _BookAgg(displayTitle(e.bookId, e.bookTitle)),
      );
      a.count++;
    }

    if (pinnedBookId != null) {
      final _BookAgg? existing = agg[pinnedBookId];
      if (existing == null) {
        // 零摘录深链书：固定成 count=0 的可见选项。
        agg[pinnedBookId] = _BookAgg(
          displayTitle(
            pinnedBookId,
            (pinnedTitle == null || pinnedTitle.trim().isEmpty)
                ? '未标注书名'
                : pinnedTitle.trim(),
          ),
        );
      } else if (pinnedTitle != null && pinnedTitle.trim().isNotEmpty) {
        // 已有摘录时也要覆盖：书库里改过书名，快照还是旧名。
        // 仍走同一个 displayTitle，保证 resolver 是唯一裁决点。
        existing.title = displayTitle(pinnedBookId, pinnedTitle.trim());
      }
    }

    final List<ExcerptBookOption> out = <ExcerptBookOption>[
      for (final MapEntry<String, _BookAgg> entry in agg.entries)
        ExcerptBookOption(bookId: entry.key, title: entry.value.title, count: entry.value.count),
    ];
    out.sort((ExcerptBookOption a, ExcerptBookOption b) =>
        LibraryQuery.naturalCompare(a.title, b.title));
    return List<ExcerptBookOption>.unmodifiable(out);
  }

  static String formatMonth(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static String formatDate(DateTime d) =>
      '${formatMonth(d)}-${d.day.toString().padLeft(2, '0')}';

  /// 某一天在**全量**摘录里的条数（不受当前筛选影响）。
  /// 与 `countForBook` 同一用途：分清「这一天从没摘过」和
  /// 「这一天有，但被范围 / 颜色 / 关键词筛掉了」。
  static int countForDay(List<Excerpt> excerpts, String dateKey) {
    int n = 0;
    for (final Excerpt e in excerpts) {
      if (dateKeyOf(e.capturedAt) == dateKey) n++;
    }
    return n;
  }

  /// 空状态分类：与书库搜索页保持一致，不写「暂无数据」。
  ///
  /// `scopedBookCount` 是**该书在全部摘录里的条数**（用 countForBook 算，
  /// 不受当前筛选影响）。深链进来的书一本摘录都没有时，报专属的
  /// `bookHasNone`，引导去阅读器划线，而不是泛泛的「筛选无结果」。
  /// 第二十一轮加 `dayHasNone`：日历深链到没有摘录的一天时，引导回日历
  /// 换一天，而不是笼统说「筛选无结果」。
  static ExcerptEmptyKind emptyKind({
    required int total,
    required int matched,
    required ExcerptFilter filter,
    int scopedBookCount = 0,
    int scopedDayCount = 0,
  }) {
    if (matched > 0) return ExcerptEmptyKind.none;
    if (total == 0) return ExcerptEmptyKind.noExcerpts;
    if (filter.bookId != null && scopedBookCount == 0) {
      return ExcerptEmptyKind.bookHasNone;
    }
    if (filter.dateKey != null && scopedDayCount == 0) {
      return ExcerptEmptyKind.dayHasNone;
    }
    return filter.isEmpty ? ExcerptEmptyKind.noExcerpts : ExcerptEmptyKind.noResult;
  }
}

enum ExcerptSort { newest, oldest, byBook, byColor }

enum ExcerptGroup { none, book, color, month }

enum ExcerptScope { all, userOnly, withNote }

enum ExcerptEmptyKind { none, noExcerpts, noResult, bookHasNone, dayHasNone }

/// 筛选条件。`copyWith` 用显式 `clear*` 开关而不是 `null` 表示清空，
/// 否则「把按书筛选取消」和「不传这个参数」会变成同一件事（第七轮卷序那类坑）。
@immutable
class ExcerptFilter {
  const ExcerptFilter({
    this.query = '',
    this.bookId,
    this.color,
    this.dateKey,
    this.scope = ExcerptScope.all,
  });

  final String query;
  final String? bookId;
  final HighlightColor? color;

  /// 第二十一轮：阅读日历「查看当天摘录」深链。严格 YYYY-MM-DD，
  /// 由 `ExcerptLibraryArgs.fromDay` 构造，页面不散写字段。
  /// 与 `bookId` / `color` / `scope` 是独立维度，可叠加。
  final String? dateKey;

  final ExcerptScope scope;

  bool get isEmpty => query.trim().isEmpty &&
      bookId == null &&
      color == null &&
      dateKey == null &&
      scope == ExcerptScope.all;

  bool get isDayScoped => dateKey != null;

  ExcerptFilter copyWith({
    String? query,
    String? bookId,
    HighlightColor? color,
    String? dateKey,
    ExcerptScope? scope,
    bool clearBook = false,
    bool clearColor = false,
    bool clearDate = false,
  }) =>
      ExcerptFilter(
        query: query ?? this.query,
        bookId: clearBook ? null : (bookId ?? this.bookId),
        color: clearColor ? null : (color ?? this.color),
        // `copyWith(dateKey: null)` 不能表示清空，沿用第十轮显式开关纪律。
        dateKey: clearDate ? null : (dateKey ?? this.dateKey),
        scope: scope ?? this.scope,
      );

  @override
  bool operator ==(Object other) =>
      other is ExcerptFilter &&
      other.query == query &&
      other.bookId == bookId &&
      other.color == color &&
      other.dateKey == dateKey &&
      other.scope == scope;

  @override
  int get hashCode => Object.hash(query, bookId, color, dateKey, scope);
}

@immutable
class ExcerptBookOption {
  const ExcerptBookOption({
    required this.bookId,
    required this.title,
    required this.count,
  });

  final String bookId;
  final String title;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is ExcerptBookOption &&
      other.bookId == bookId &&
      other.title == title &&
      other.count == count;

  @override
  int get hashCode => Object.hash(bookId, title, count);
}

class _BookAgg {
  _BookAgg(this.title);
  String title;
  int count = 0;
}

@immutable
class ExcerptSummary {
  const ExcerptSummary({
    required this.total,
    required this.userCount,
    required this.withNoteCount,
    required this.perBook,
    required this.perColor,
  });

  final int total;
  final int userCount;
  final int withNoteCount;
  final Map<String, int> perBook;
  final Map<HighlightColor, int> perColor;
}

/// 纯文本导出。
///
/// **静态边界**：只生成字符串给应用内预览，不写文件、不调用系统分享、
/// 不引入 `dart:io` 或任何平台插件。真正落盘 / 分享是 ❄️ 冻结项。
/// 格式固定，便于规格单测逐行断言，也便于未来三端共用同一份输出。
///
/// **书名刻意只用 `e.bookTitle` 快照**：导出是一次历史记录，后续在详情页
/// 改书名不应让已经导出的文本漂移。展示 / 搜索 / 排序 / 分组走
/// `ExcerptTitleLookup`，导出行走快照——两条口径在模型文件里列成表，
/// 不是「忘了改」，文档与规格单测都有回归断言。
class ExcerptExporter {
  const ExcerptExporter._();

  static const String separator = '———';
  static const String emptyMessage = '（没有可导出的摘录）';

  static String toPlainText(
    List<Excerpt> excerpts, {
    String title = '我的摘录',
    bool includeMetadata = true,
  }) {
    if (excerpts.isEmpty) return emptyMessage;

    final StringBuffer buf = StringBuffer();
    buf.writeln(title);
    buf.writeln('共 ${excerpts.length} 条');
    buf.writeln();

    for (final Excerpt e in excerpts) {
      buf.writeln('《${e.bookTitle}》 · ${e.chapterTitle}');
      buf.writeln(e.text);
      if (e.note.trim().isNotEmpty) buf.writeln('—— ${e.note.trim()}');
      if (includeMetadata) {
        buf.writeln(
          '${ExcerptQuery.formatDate(e.capturedAt)} · '
          '${HighlightPalette.labels[e.highlight]}'
          '${e.isUserAdded ? ' · 我摘的' : ' · 演示'}',
        );
      }
      buf.writeln(separator);
    }
    return buf.toString().trimRight();
  }
}
