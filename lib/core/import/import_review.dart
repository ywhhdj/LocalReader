import 'package:flutter/foundation.dart';

import 'import_session.dart';

/// 导入前审阅与同系列卷合并（第二十四轮）。
///
/// 参考仓库 README：「Choose before importing: Select multiple files, scan
/// shared storage, or scan a chosen folder. Review the results before
/// importing, and confirm how volumes in the same series should be merged.」
///
/// 已有的 `ImportSession` 负责五步状态机与冲突策略，本层补的是**审阅阶段**：
/// 三种来源、勾选、以及「同系列卷怎么合并」的确认，不另写一份冲突策略。
enum ImportSourceKind { multipleFiles, sharedStorage, chosenFolder }

enum VolumeMergePolicy { askEach, keepSeparate, mergeBySeries }

@immutable
class ImportReviewItem {
  const ImportReviewItem({
    required this.candidate,
    required this.selected,
    this.seriesKey = '',
  });

  final ImportCandidate candidate;
  final bool selected;
  final String seriesKey;

  ImportReviewItem copyWith({bool? selected, String? seriesKey}) =>
      ImportReviewItem(
        candidate: candidate,
        selected: selected ?? this.selected,
        seriesKey: seriesKey ?? this.seriesKey,
      );
}

@immutable
class ImportReview {
  const ImportReview({
    this.source = ImportSourceKind.multipleFiles,
    this.policy = VolumeMergePolicy.askEach,
    this.items = const <ImportReviewItem>[],
  });

  final ImportSourceKind source;
  final VolumeMergePolicy policy;
  final List<ImportReviewItem> items;

  static const Map<ImportSourceKind, String> sourceLabels =
      <ImportSourceKind, String>{
    ImportSourceKind.multipleFiles: '选择多个文件',
    ImportSourceKind.sharedStorage: '扫描共享存储',
    ImportSourceKind.chosenFolder: '扫描选择的目录',
  };

  static const Map<VolumeMergePolicy, String> policyLabels =
      <VolumeMergePolicy, String>{
    VolumeMergePolicy.askEach: '每次询问',
    VolumeMergePolicy.keepSeparate: '各自独立',
    VolumeMergePolicy.mergeBySeries: '按系列合并',
  };

  /// 从扫描结果构造：默认只勾选可导入项，被拒与未登记格式不占审阅名额
  ///（沿用第十二轮 `ScanReport` 的分类口径，不重新解释格式）。
  factory ImportReview.fromScan(ScanReport report) => ImportReview(
        items: List<ImportReviewItem>.unmodifiable(
          report.accepted.map(
            (ImportCandidate c) => ImportReviewItem(
              candidate: c,
              selected: true,
              seriesKey: _guessSeries(c.title),
            ),
          ),
        ),
      );

  static String _guessSeries(String title) {
    // 只按「第 N 卷」之前的标题片段归组，不做模糊匹配、不改书名。
    final int i = title.indexOf('第');
    return i > 0 ? title.substring(0, i).trim() : title.trim();
  }

  ImportReview toggle(String draftId) => copyWithItems(<ImportReviewItem>[
        for (final ImportReviewItem it in items)
          it.candidate.draftId == draftId
              ? it.copyWith(selected: !it.selected)
              : it,
      ]);

  ImportReview copyWithItems(List<ImportReviewItem> next) => ImportReview(
        source: source,
        policy: policy,
        items: List<ImportReviewItem>.unmodifiable(next),
      );

  ImportReview withSource(ImportSourceKind next) =>
      ImportReview(source: next, policy: policy, items: items);

  ImportReview withPolicy(VolumeMergePolicy next) =>
      ImportReview(source: source, policy: next, items: items);

  List<ImportReviewItem> get selected =>
      List<ImportReviewItem>.unmodifiable(items.where((ImportReviewItem i) => i.selected));

  /// 按系列分组；`mergeBySeries` 时同组只保留第一条（卷序交给详情页覆盖层）。
  Map<String, List<ImportReviewItem>> get bySeries {
    final Map<String, List<ImportReviewItem>> out = <String, List<ImportReviewItem>>{};
    for (final ImportReviewItem i in selected) {
      out.putIfAbsent(i.seriesKey, () => <ImportReviewItem>[]).add(i);
    }
    return Map<String, List<ImportReviewItem>>.unmodifiable(out);
  }

  /// 落到既有 `ConflictResolution`，不新造第四第五种策略。
  ConflictResolution get resolution {
    switch (policy) {
      case VolumeMergePolicy.keepSeparate:
        return ConflictResolution.keepBoth;
      case VolumeMergePolicy.mergeBySeries:
        return ConflictResolution.mergeRecords;
      case VolumeMergePolicy.askEach:
        return ConflictResolution.skip;
    }
  }

  bool get isEmpty => items.isEmpty;
  int get selectedCount => selected.length;
}
