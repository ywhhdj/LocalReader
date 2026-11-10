import 'package:flutter/foundation.dart';

import 'keepsake_kind.dart';
import 'keepsake_query.dart';
import 'keepsakes.dart';
import 'stats_date.dart';

/// 「本月纪念物」小组件的预览数据模型（第十九轮）。
///
/// 第十八轮给小组件加了「内容 = 纪念物 + 每个独立类型」，但预览块只显示
/// 内容名 / 尺寸 / 季节 / 明暗四个**配置项**，看不到卡片上到底会出现什么。
/// 本轮把预览接成真实聚合结果：本月共几枚、最近一枚是什么、类型分布如何。
///
/// **「本月」不读 `DateTime.now()`**：由调用方从 `StatsSnapshot.days.last.date`
/// 传入固定基准日。静态演示数据用固定基准日，真机时间一变就会让预览与
/// 热力图 / 纪念物册对不上——这正是第十三轮把日期口径收口到 `stats_date.dart`
/// 的原因。本模型只认传入的 `DateTime`，不引入任何平台 / 时间依赖。
///
/// **静态边界**：只读 `AppState.keepsakes` 与 `KeepsakeQuery`，不缓存、不落盘、
/// 不联网；桌面小组件本体仍 ❄️ 冻结，这里只是应用内预览数据。
@immutable
class KeepsakeMonthPreview {
  const KeepsakeMonthPreview._({
    required this.monthKey,
    required this.monthLabel,
    required this.totalInMonth,
    required this.matched,
    required this.kind,
    required this.perKind,
    required this.latest,
    required this.latestInScope,
    required this.items,
  });

  final String monthKey;
  final String monthLabel;
  final int totalInMonth;
  final int matched;
  final KeepsakeKind? kind;

  /// 本月各类型条数（不受当前类型筛选影响），用于 chip 分布。
  final Map<KeepsakeKind, int> perKind;

  /// 本月最近一枚（不受当前类型筛选影响），供「本月一枚都没有」时区分口径。
  final Keepsake? latest;

  /// 当前筛选下最近一枚，预览卡片主标题用它。
  final Keepsake? latestInScope;
  final List<Keepsake> items;

  bool get isEmpty => items.isEmpty;
  bool get hasAnyInMonth => totalInMonth > 0;

  /// 空状态三分支：本月零纪念物 / 本月有但该类型零枚 / 其它条件筛掉。
  /// 与 `KeepsakeQuery.emptyKind` 同构，但这里限定在「本月」这个小范围。
  KeepsakeMonthEmptyKind get emptyKind {
    if (!isEmpty) return KeepsakeMonthEmptyKind.none;
    if (!hasAnyInMonth) return KeepsakeMonthEmptyKind.noMonth;
    if (kind != null && (perKind[kind] ?? 0) == 0) {
      return KeepsakeMonthEmptyKind.kindHasNone;
    }
    return KeepsakeMonthEmptyKind.noResult;
  }

  /// 唯一构造口。`monthDate` 必须是调用方给的确定性基准日。
  static KeepsakeMonthPreview build({
    required List<Keepsake> keepsakes,
    required DateTime monthDate,
    KeepsakeKind? kind,
  }) {
    final MonthAnchor anchor = MonthAnchor.fromDate(monthDate);
    final String key = anchor.key;

    // 本月全量：不受类型筛选影响，用于「本月有纪念物吗」和类型分布。
    final List<Keepsake> inMonth = KeepsakeQuery.apply(
      keepsakes: keepsakes,
      filter: KeepsakeFilter(monthKey: key),
    );
    final Map<KeepsakeKind, int> perKind = <KeepsakeKind, int>{
      for (final KeepsakeKind k in KeepsakeKind.values) k: 0,
    };
    for (final Keepsake k in inMonth) {
      perKind[k.kind] = (perKind[k.kind] ?? 0) + 1;
    }

    // 小组件实际会显示的内容：本月 ∧ 类型。
    final List<Keepsake> scoped = KeepsakeQuery.apply(
      keepsakes: keepsakes,
      filter: KeepsakeFilter(kind: kind, monthKey: key),
    );

    return KeepsakeMonthPreview._(
      monthKey: key,
      monthLabel: anchor.label,
      totalInMonth: inMonth.length,
      matched: scoped.length,
      kind: kind,
      perKind: Map<KeepsakeKind, int>.unmodifiable(perKind),
      latest: inMonth.isEmpty ? null : inMonth.first,
      latestInScope: scoped.isEmpty ? null : scoped.first,
      items: scoped,
    );
  }

  /// 供 chip 展示：只列本月实际出现过的类型，按枚举序，带条数。
  List<KeepsakeKindOption> get kindOptions =>
      List<KeepsakeKindOption>.unmodifiable(<KeepsakeKindOption>[
        for (final KeepsakeKind k in KeepsakeKind.values)
          if ((perKind[k] ?? 0) > 0)
            KeepsakeKindOption(
              kind: k,
              label: KeepsakeKindLabels.labels[k]!,
              count: perKind[k]!,
            ),
      ]);

  /// 预览卡的一句话摘要，交给面板渲染，页面不自己拼数字。
  String get headline {
    if (isEmpty) return '$monthLabel · 暂无纪念物';
    final String kindSuffix = kind == null
        ? ''
        : ' · ${KeepsakeKindLabels.labels[kind]!}';
    return '$monthLabel · $matched 枚$kindSuffix';
  }

  String get subline {
    final Keepsake? k = latestInScope;
    return k == null ? '' : '${k.kindLabel} · ${k.title}';
  }
}

enum KeepsakeMonthEmptyKind { none, noMonth, kindHasNone, noResult }
