import 'package:flutter/foundation.dart';

import 'keepsakes.dart';
import 'stats_date.dart';

/// 纪念物「按类型筛选」的纯 Dart 查询层（第十八轮）。
///
/// 第八轮 `KeepsakeCatalog` 只有 `byMonth / forMonth / countByKind` 三个聚合口，
/// 统计页卡片因此只能按月份归档 + 环形切换**一枚**；六条生成规则散在一张卡里，
/// 用户既看不到「连续类共有几枚」，也没法只看摘录纪念物。本层把类型 / 月份 /
/// 关键词三个条件收口到一次 `apply()`，所有页面与小组件共用同一份结果。
///
/// **分面计数（faceted count）是关键**：类型 chip 上的条数必须按「去掉类型
/// 条件后的其它条件」计算，否则选了「连续」之后其它五个类型全显示 0，
/// 用户会以为纪念物凭空消失了。与第十六轮「零摘录书固定成可见选项」同构。
///
/// **静态边界**：不缓存列表、不读数据库、不联网、不落盘；页面每次 build
/// 从 `AppState.keepsakes` 重取再交给本层，与前几轮摘录查询同一套纪律。
@immutable
class KeepsakeQuery {
  const KeepsakeQuery._();

  static const Map<KeepsakeSort, String> sortLabels = <KeepsakeSort, String>{
    KeepsakeSort.newest: '最近获得',
    KeepsakeSort.oldest: '最早获得',
    KeepsakeSort.byKind: '按类型',
  };

  static const Map<KeepsakeGroup, String> groupLabels = <KeepsakeGroup, String>{
    KeepsakeGroup.none: '不分组',
    KeepsakeGroup.kind: '按类型',
    KeepsakeGroup.month: '按月份',
  };

  /// 第二十轮：深链进来后**统一归一化**，页面不再各写一份。
  /// 第二十一轮加入日期范围，口径扩成五条，**顺序不可换**：
  ///
  /// 1. **范围先归一化**：`normalizeDateKeyRange` 把「起 > 止」交换、非法端清掉；
  /// 2. **范围与单日 / 整月互斥**：有范围时清 `dateKey` 与 `monthKey`。
  ///    否则「范围跨 10~11 月、月份却锁在 10 月」会让结果莫名变少——
  ///    和第二十轮修的「换月份与只看某天打架」是同一类状态分裂；
  /// 3. 月份已不在数据里 → 清掉月份（第十八轮既有行为）；
  /// 4. 日期 key 非法 → 清掉日期，但**保留月份**（不把整月视图一起丢掉）；
  /// 5. 日期与月份不同月 → **以日期为准修正月份**，绝不静默丢掉日期深链。
  ///
  /// 纯函数，不读全局状态；`availableMonths` 由页面从当前列表算好传入。
  static KeepsakeFilter normalizeFilter(
    KeepsakeFilter filter, {
    required List<String> availableMonths,
  }) {
    final DateKeyRange r = normalizeDateKeyRange(
      filter.fromDateKey,
      filter.toDateKey,
    );
    KeepsakeFilter f = filter.copyWith(
      fromDateKey: r.from,
      toDateKey: r.to,
      clearFromDate: r.from == null,
      clearToDate: r.to == null,
    );
    if (f.isRangeScoped) {
      // 范围跨月，月份与单日条件都不再成立，一律清掉。
      f = f.copyWith(clearDate: true, clearMonth: true);
    }
    if (f.monthKey != null && !availableMonths.contains(f.monthKey)) {
      f = f.copyWith(clearMonth: true);
    }
    if (f.dateKey != null) {
      final String? monthOfDay = monthKeyOfDateKey(f.dateKey);
      if (monthOfDay == null) {
        f = f.copyWith(clearDate: true);
      } else if (f.monthKey != monthOfDay) {
        f = f.copyWith(monthKey: monthOfDay);
      }
    }
    return f;
  }

  /// 唯一查询出口：类型 ∧ 月份 ∧ **单日 / 日期范围** ∧ 关键词，返回不可变列表。
  /// 第二十轮加入 dateKey（日历「查看当天纪念物」深链）；
  /// 第二十一轮加入 `[fromDateKey, toDateKey]` 闭区间（纪念物册日期范围筛选）。
  /// 单日与范围互斥由 `normalizeFilter` 裁决，本函数只负责执行已归一化的条件。
  static List<Keepsake> apply({
    required List<Keepsake> keepsakes,
    KeepsakeFilter filter = const KeepsakeFilter(),
    KeepsakeSort sort = KeepsakeSort.newest,
  }) {
    final List<Keepsake> out = <Keepsake>[
      for (final Keepsake k in keepsakes)
        if (matches(k, filter)) k,
    ];
    out.sort((Keepsake a, Keepsake b) => _compare(a, b, sort));
    return List<Keepsake>.unmodifiable(out);
  }

  static bool matches(Keepsake k, KeepsakeFilter f) {
    if (f.kind != null && k.kind != f.kind) return false;
    if (f.monthKey != null && k.monthKey != f.monthKey) return false;
    if (f.dateKey != null && k.dateKey != f.dateKey) return false;
    if (!dateKeyInRange(k.dateKey, f.fromDateKey, f.toDateKey)) return false;
    final String q = f.query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return k.title.toLowerCase().contains(q) ||
        k.detail.toLowerCase().contains(q) ||
        k.kindLabel.toLowerCase().contains(q) ||
        (k.bookTitle?.toLowerCase().contains(q) ?? false);
  }

  static int _compare(Keepsake a, Keepsake b, KeepsakeSort sort) {
    switch (sort) {
      case KeepsakeSort.newest:
        final int byDate = b.dateKey.compareTo(a.dateKey);
        return byDate != 0 ? byDate : a.kind.index.compareTo(b.kind.index);
      case KeepsakeSort.oldest:
        final int byDate = a.dateKey.compareTo(b.dateKey);
        return byDate != 0 ? byDate : a.kind.index.compareTo(b.kind.index);
      case KeepsakeSort.byKind:
        final int byKind = a.kind.index.compareTo(b.kind.index);
        return byKind != 0 ? byKind : b.dateKey.compareTo(a.dateKey);
    }
  }

  /// 分面计数：算「除类型外的其它条件」过滤后各类型的条数。
  /// chip 显示这个数字，切换月份时随之变化，且不会因已选类型把其它类型打成 0。
  static List<KeepsakeKindOption> kindOptions(
    List<Keepsake> keepsakes, {
    KeepsakeFilter filter = const KeepsakeFilter(),
  }) {
    // 把类型条件摘掉，只保留月份 / 单日 / 日期范围 / 关键词。
    // 第二十轮：按天深链时类型 chip 只统计这一天；
    // 第二十一轮：按范围筛选时同样只统计这段区间，
    // 不能因为选了「连续」就让其它五类显示的是全量数字。
    final KeepsakeFilter facet = filter.copyWith(clearKind: true);
    final Map<KeepsakeKind, int> counts = <KeepsakeKind, int>{
      for (final KeepsakeKind k in KeepsakeKind.values) k: 0,
    };
    for (final Keepsake k in keepsakes) {
      if (matches(k, facet)) counts[k.kind] = (counts[k.kind] ?? 0) + 1;
    }
    return List<KeepsakeKindOption>.unmodifiable(<KeepsakeKindOption>[
      for (final KeepsakeKind kind in KeepsakeKind.values)
        KeepsakeKindOption(
          kind: kind,
          label: KeepsakeKindLabels.labels[kind]!,
          count: counts[kind] ?? 0,
        ),
    ]);
  }

  /// 某个类型在**全部纪念物**里的条数（不受当前筛选影响），供空状态分类。
  /// 与摘录页 `countForBook` 同一口径：分清「这一类从没产生过」和「被别的条件筛掉了」。
  static int countForKind(List<Keepsake> keepsakes, KeepsakeKind kind) {
    int n = 0;
    for (final Keepsake k in keepsakes) {
      if (k.kind == kind) n++;
    }
    return n;
  }

  /// 某一天在**全量**纪念物里的条数（不受当前筛选影响）。
  /// 与 `countForKind` 同一用途：分清「这一天从没产生过纪念物」和
  /// 「这一天有，但被类型 / 关键词筛掉了」。空状态第 4 分支用它。
  static int countForDay(List<Keepsake> keepsakes, String dateKey) {
    int n = 0;
    for (final Keepsake k in keepsakes) {
      if (k.dateKey == dateKey) n++;
    }
    return n;
  }

  /// 某段闭区间在**全量**纪念物里的条数（不受当前筛选影响）。
  /// 区间两端可为 null 表示不设边界；非法端由 `dateKeyInRange` 兜住。
  /// 空状态 `rangeHasNone` 用它分清「这段日期从没产生过」和「被别的条件筛掉」。
  static int countForRange(
    List<Keepsake> keepsakes, {
    String? from,
    String? to,
  }) {
    int n = 0;
    for (final Keepsake k in keepsakes) {
      if (dateKeyInRange(k.dateKey, from, to)) n++;
    }
    return n;
  }

  /// 有纪念物的月份，降序。复用 `KeepsakeCatalog`，不另写一份口径。
  static List<String> monthKeys(List<Keepsake> keepsakes) =>
      KeepsakeCatalog.monthKeys(keepsakes);

  static Map<String, List<Keepsake>> group(
    List<Keepsake> keepsakes, {
    KeepsakeGroup by = KeepsakeGroup.none,
  }) {
    final Map<String, List<Keepsake>> out = <String, List<Keepsake>>{};
    for (final Keepsake k in keepsakes) {
      out.putIfAbsent(groupKey(k, by), () => <Keepsake>[]).add(k);
    }
    return Map<String, List<Keepsake>>.unmodifiable(out);
  }

  static String groupKey(Keepsake k, KeepsakeGroup by) {
    switch (by) {
      case KeepsakeGroup.none:
        return '全部纪念物';
      case KeepsakeGroup.kind:
        return k.kindLabel;
      case KeepsakeGroup.month:
        return k.monthKey;
    }
  }

  static KeepsakeSummary summarize(List<Keepsake> keepsakes) => KeepsakeSummary(
        total: keepsakes.length,
        perKind: KeepsakeCatalog.countByKind(keepsakes),
        monthCount: KeepsakeCatalog.byMonth(keepsakes).length,
        userExcerptCount: keepsakes
            .where((Keepsake k) => k.fromUserExcerpt)
            .length,
      );

  /// 空状态分支，优先级与摘录页 `emptyKind` 对齐：
  /// 有命中 → 全书库零纪念物 → 该类型从未产生 → **该日期从未产生**
  /// → **该区间从未产生** → 其它条件筛掉。
  ///
  /// `kindTotalCount` / `dayTotalCount` / `rangeTotalCount` 都由页面算**全量**
  /// （不受当前筛选影响），否则「这一类有 3 枚、但被当前月份筛掉」会误报
  /// 「这类还没产生过」。第二十轮加 `dayHasNone`，第二十一轮加 `rangeHasNone`：
  /// 深链 / 范围筛选到没有纪念物的日期时，引导回日历换一天或清除范围，
  /// 而不是笼统说「没有匹配结果」。
  /// 不设全局可变状态，也不在这里偷偷读一次列表，保持纯函数可单测。
  static KeepsakeEmptyKind emptyKind({
    required int total,
    required int matched,
    required KeepsakeFilter filter,
    int kindTotalCount = 0,
    int dayTotalCount = 0,
    int rangeTotalCount = 0,
  }) {
    if (matched > 0) return KeepsakeEmptyKind.none;
    if (total == 0) return KeepsakeEmptyKind.noKeepsakes;
    if (filter.kind != null && kindTotalCount == 0) {
      return KeepsakeEmptyKind.kindHasNone;
    }
    if (filter.dateKey != null && dayTotalCount == 0) {
      return KeepsakeEmptyKind.dayHasNone;
    }
    if (filter.isRangeScoped && rangeTotalCount == 0) {
      return KeepsakeEmptyKind.rangeHasNone;
    }
    return filter.isEmpty ? KeepsakeEmptyKind.noKeepsakes : KeepsakeEmptyKind.noResult;
  }
}

enum KeepsakeSort { newest, oldest, byKind }

enum KeepsakeGroup { none, kind, month }

enum KeepsakeEmptyKind {
  none,
  noKeepsakes,
  noResult,
  kindHasNone,
  dayHasNone,
  rangeHasNone,
}

/// 筛选条件。`copyWith` 用显式 `clear*` 开关而不是 `null` 表示清空，
/// 与 `ExcerptFilter` 同一纪律，否则「取消类型筛选」与「没传这个参数」会混为一谈。
@immutable
class KeepsakeFilter {
  const KeepsakeFilter({
    this.kind,
    this.monthKey,
    this.dateKey,
    this.fromDateKey,
    this.toDateKey,
    this.query = '',
  });

  final KeepsakeKind? kind;
  final String? monthKey;

  /// 第二十轮：日历「查看当天纪念物」深链。与 monthKey 同时给定时必须同月，
  /// 由 `KeepsakeCalendarLink.toLibraryFromDay` 构造并校验，页面不散写字段。
  final String? dateKey;

  /// 第二十一轮：闭区间 `[fromDateKey, toDateKey]`。两端可只填一端；
  /// 与「单日 / 整月」互斥，由 `normalizeFilter` 裁决。
  final String? fromDateKey;
  final String? toDateKey;

  final String query;

  bool get isEmpty => kind == null &&
      monthKey == null &&
      dateKey == null &&
      fromDateKey == null &&
      toDateKey == null &&
      query.trim().isEmpty;

  bool get isDayScoped => dateKey != null;
  bool get isRangeScoped => fromDateKey != null || toDateKey != null;

  KeepsakeFilter copyWith({
    KeepsakeKind? kind,
    String? monthKey,
    String? dateKey,
    String? fromDateKey,
    String? toDateKey,
    String? query,
    bool clearKind = false,
    bool clearMonth = false,
    bool clearDate = false,
    bool clearFromDate = false,
    bool clearToDate = false,
    bool clearRange = false,
  }) =>
      KeepsakeFilter(
        kind: clearKind ? null : (kind ?? this.kind),
        monthKey: clearMonth ? null : (monthKey ?? this.monthKey),
        // 清空日期时**同时清掉月份**吗？不清：月份是独立维度，用户可能想
        // 「只看 11 月但不局限某一天」。clearDate 只动 dateKey。
        dateKey: clearDate ? null : (dateKey ?? this.dateKey),
        fromDateKey: (clearRange || clearFromDate)
            ? null
            : (fromDateKey ?? this.fromDateKey),
        toDateKey: (clearRange || clearToDate)
            ? null
            : (toDateKey ?? this.toDateKey),
        query: query ?? this.query,
      );

  @override
  bool operator ==(Object other) =>
      other is KeepsakeFilter &&
      other.kind == kind &&
      other.monthKey == monthKey &&
      other.dateKey == dateKey &&
      other.fromDateKey == fromDateKey &&
      other.toDateKey == toDateKey &&
      other.query == query;

  @override
  int get hashCode => Object.hash(
        kind,
        monthKey,
        dateKey,
        fromDateKey,
        toDateKey,
        query,
      );
}

@immutable
class KeepsakeKindOption {
  const KeepsakeKindOption({
    required this.kind,
    required this.label,
    required this.count,
  });

  final KeepsakeKind kind;
  final String label;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is KeepsakeKindOption &&
      other.kind == kind &&
      other.label == label &&
      other.count == count;

  @override
  int get hashCode => Object.hash(kind, label, count);
}

@immutable
class KeepsakeSummary {
  const KeepsakeSummary({
    required this.total,
    required this.perKind,
    required this.monthCount,
    required this.userExcerptCount,
  });

  final int total;
  final Map<KeepsakeKind, int> perKind;
  final int monthCount;
  final int userExcerptCount;
}
