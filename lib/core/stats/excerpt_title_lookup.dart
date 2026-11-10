import 'package:flutter/foundation.dart';

import 'reading_stats.dart';

/// 摘录的「书名口径」唯一裁决点（纯 Dart，零平台依赖）。
///
/// 第十六轮把**展示层**书名统一到了 `state.resolveBook(id)?.title`（含详情页
/// 编辑覆盖层），但搜索 / 按书名排序 / 按书名分组仍读 `Excerpt.bookTitle`——
/// 那是**捕获时的快照**。于是把书改名后：详情页显示新名、筛选 chip 显示新名，
/// 搜新名却搜不到、搜旧名反而命中，分组标题还是旧名。这是同一类状态分裂
/// 从展示层转移到了查询层。本轮把查询层也收口到同一个裁决点。
///
/// **三条口径，不混用**：
/// | 用途 | 取谁 | 理由 |
/// | --- | --- | --- |
/// | 展示 / 搜索主口径 / 排序 / 分组 / 筛选选项 | 书库**当前**书名 | 用户此刻看到的名字 |
/// | 搜索兼容口径 | 当前名 **∪** 快照名 | 改名后新旧名都能找到；脏 id 仍能按书名搜 |
/// | 导出正文 | **仅快照** | 历史导出必须稳定可复核，不随后续改名漂移 |
///
/// `resolve` 由页面注入（通常是 `state.resolveBook(id)?.title`），core 层不
/// 依赖 `AppState`；`titles == null` 时全部回落快照，保持既有调用向后兼容。
@immutable
class ExcerptTitleLookup {
  const ExcerptTitleLookup(this.resolve);

  /// 返回书库当前书名；返回 null / 空白表示「解析不到，回落快照」。
  final String? Function(String bookId) resolve;

  static const String unknownTitle = '未标注书名';

  String? currentTitle(String bookId) {
    final String? v = resolve(bookId);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  /// 展示用书名：当前名优先，回落快照，最后「未标注书名」。
  /// 展示、排序、分组、perBook 汇总、筛选选项全部只用这一个结果。
  String titleOf(Excerpt e) {
    final String? current = currentTitle(e.bookId);
    if (current != null) return current;
    return snapshotOf(e);
  }

  static String snapshotOf(Excerpt e) =>
      e.bookTitle.trim().isEmpty ? unknownTitle : e.bookTitle.trim();

  /// 搜索口径：当前名 ∪ 快照名，大小写不敏感。
  ///
  /// **为什么是并集而不是「只认当前名」**：书库里找不到这本书（脏 id / 上次
  /// 导入数据）时当前名解析不到，只认当前名会让这些摘录按书名彻底搜不到；
  /// 而导出正文里印的是旧名，用户拿旧名回搜也应该命中。并集与第十六轮
  /// 「解析不到才回落快照」同构，不丢任何既有能力。
  bool matchesBookTitle(Excerpt e, String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (titleOf(e).toLowerCase().contains(q)) return true;
    return e.bookTitle.toLowerCase().contains(q);
  }

  @override
  bool operator ==(Object other) =>
      other is ExcerptTitleLookup && identical(other.resolve, resolve);

  @override
  int get hashCode => resolve.hashCode;
}
