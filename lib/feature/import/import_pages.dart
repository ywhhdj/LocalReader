// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖
// 合并状态 E13：已落入工程路径 lib/feature/import/import_pages.dart；同名类型已隔离；未编译 / 未运行 / 未下载依赖。
// 设计源：scaffold/import_pages.dart（交付包内保留，作为规格基线）
// 建议落点：lib/feature/import/import_pages.dart
// 对应需求：R13 导入书籍页 / 扫描本地文件夹 / 合并页（搜索栏 + 格式分面 + 懒加载列表）
// 对齐：docs/08 §8.2 / §8.5 / §8.6；纯 Dart。

import 'package:Local_reader/core/model/import_prefs.dart';
import 'package:Local_reader/domain/usecases/scan_result.dart';
import 'package:Local_reader/domain/usecases/txt_toc_rules.dart';
import 'package:Local_reader/domain/usecases/volume_grouping.dart';

/// 导入书籍页导航栏：左侧返回、中间「导入书籍」、右侧设置。
/// core 组件不读 Navigator：leading 由页面注入，右侧 action 只回调。
class ImportBooksHeaderNavSpec {
  const ImportBooksHeaderNavSpec({
    this.titleKey = 'uiImportBooks',
    this.hasBack = true,
    this.hasSettings = true,
    this.centerTitle = true,
  });

  final String titleKey;
  final bool hasBack;
  final bool hasSettings;
  final bool centerTitle;
}

/// 导入书籍页从上往下：HeaderNav → 「扫描本地文件夹」入口。
class ImportBooksPageState {
  const ImportBooksPageState({
    this.header = const ImportBooksHeaderNavSpec(),
    this.entries = const <String>['uiScanLocalFolder'],
    this.settings = const ImportSettings(),
    this.lastBatch,
  });

  final ImportBooksHeaderNavSpec header;
  final List<String> entries;
  final ImportSettings settings;
  final ScanBatch? lastBatch;

  bool get scanIsFirstEntry =>
      entries.isNotEmpty && entries.first == 'uiScanLocalFolder';
}

/// 右侧设置页：TXT 编码 / 目录识别 / 自定义规则（章节正则 + 分卷正则可改）/ 无标题策略。
class ImportSettingsPageState {
  const ImportSettingsPageState({
    this.settings = const ImportSettings(),
    this.previewText = '第一章 起航\n第一卷 丰收\n第二章 归途',
    this.preview,
    this.dirty = false,
  });

  final ImportSettings settings;
  final String previewText;
  final TocRulePreview? preview;
  final bool dirty;

  bool get showCustomRuleFields => settings.usesCustomRules;
  bool get chapterRegexEditable => settings.rules.editable;
  bool get volumeRegexEditable => settings.rules.editable;
}

/// 扫描页从上往下：扫描格式选择 → 选择扫描范围 →（返回按原项目结构的文件）。
class ScanFolderPageState {
  const ScanFolderPageState({
    this.spec = const ScanFolderSpec(),
    this.scanning = false,
    this.batch,
    this.error = '',
  });

  final ScanFolderSpec spec;
  final bool scanning;
  final ScanBatch? batch;
  final String error;

  bool get showFormatSelector => true;
  bool get showScopeSelector => true;

  /// 返回的文件保留目录层级，不摊平。
  Map<String, List<ScanFile>> get tree =>
      batch?.treeByDirectory() ?? const <String, List<ScanFile>>{};
}

/// 合并页：扫描到多个文件时先按卷组合并，**展示的书籍是合并后的 VolumeGroup**。
/// 从上往下：搜索栏 → 格式分面（全部格式 / 格式 <number>）→ 懒加载列表
/// （每项：名字 / 格式 / 路径，组内文件可勾选导入）。
class MergePageState {
  const MergePageState({
    this.query = '',
    this.facets = const <FormatFacet>[],
    this.activeFormat = ScanFormat.all,
    this.groups = const <VolumeGroup>[],
    this.selectedFileIds = const <String>{},
    this.loadedCount = 20,
    this.pageSize = 20,
  });

  final String query;
  final List<FormatFacet> facets;
  final ScanFormat activeFormat;
  final List<VolumeGroup> groups;
  final Set<String> selectedFileIds;
  final int loadedCount;
  final int pageSize;

  /// 搜索命中：卷组标题 / 文件名 / 路径；格式分面只对组内文件生效。
  List<VolumeGroup> visibleGroups() {
    final String q = query.trim().toLowerCase();
    final List<VolumeGroup> out = <VolumeGroup>[];
    for (final VolumeGroup g in groups) {
      final List<ScanFile> files = g.files.where((ScanFile f) {
        final bool fmtOk = activeFormat == ScanFormat.all ||
            f.format == activeFormat.name;
        if (!fmtOk) return false;
        if (q.isEmpty) return true;
        return g.displayTitle.toLowerCase().contains(q) ||
            f.name.toLowerCase().contains(q) ||
            f.path.toLowerCase().contains(q);
      }).toList();
      if (files.isEmpty) continue;
      out.add(VolumeGroup(
        id: g.id,
        normalizedTitle: g.normalizedTitle,
        displayTitle: g.displayTitle,
        files: files,
        volumeCount: files.length,
        mergedBookId: g.mergedBookId,
      ));
    }
    return List<VolumeGroup>.unmodifiable(out);
  }

  /// 懒加载：只把已加载数量内的组交给 SliverChildBuilderDelegate。
  List<VolumeGroup> page() {
    final List<VolumeGroup> all = visibleGroups();
    return all.length <= loadedCount
        ? all
        : all.sublist(0, loadedCount);
  }

  bool get hasMore => visibleGroups().length > loadedCount;

  MergePageState loadMore() => MergePageState(
        query: query,
        facets: facets,
        activeFormat: activeFormat,
        groups: groups,
        selectedFileIds: selectedFileIds,
        loadedCount: loadedCount + pageSize,
        pageSize: pageSize,
      );

  MergePageState toggle(String fileId) {
    final Set<String> next = Set<String>.from(selectedFileIds);
    if (!next.add(fileId)) next.remove(fileId);
    return MergePageState(
      query: query,
      facets: facets,
      activeFormat: activeFormat,
      groups: groups,
      selectedFileIds: Set<String>.unmodifiable(next),
      loadedCount: loadedCount,
      pageSize: pageSize,
    );
  }

  /// 从扫描批次构造合并页：先分组再算分面，列表展示合并后的书籍。
  factory MergePageState.fromBatch(ScanBatch batch, [VolumeGroupingEngine? engine]) {
    final VolumeGroupingEngine grouping =
        engine ?? const VolumeGroupingEngine();
    return MergePageState(
      groups: grouping.group(batch.files),
      facets: FormatFacet.of(batch.files),
    );
  }

  bool get showsMergedBooksOnly => true;
}
