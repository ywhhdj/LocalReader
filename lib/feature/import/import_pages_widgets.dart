import 'package:Local_reader/core/ui/components/glass/HeaderNav.dart';
import 'package:flutter/material.dart';

import 'package:Local_reader/feature/import/import_pages.dart';
import 'package:Local_reader/core/model/import_prefs.dart';
import 'package:Local_reader/domain/usecases/scan_result.dart';
import 'package:Local_reader/domain/usecases/volume_grouping.dart';

/// 书架 → 导入书籍：导航栏左侧返回 / 中间「导入书籍」/ 右侧设置。
class ImportBooksPage extends StatelessWidget {
  const ImportBooksPage({
    super.key,
    required this.state,
    required this.onBack,
    required this.onOpenSettings,
    required this.onScanFolder,
  });

  final ImportBooksPageState state;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final VoidCallback onScanFolder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: <Widget>[
          HeaderNavSliver(
            spec: HeaderNavSpec(
              title: '导入书籍',
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回',
                onPressed: onBack,
              ),
              actions: <HeaderNavAction>[
                HeaderNavAction(
                  icon: Icons.settings_outlined,
                  tooltip: '设置',
                  onTap: onOpenSettings,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('扫描本地文件夹'),
              subtitle: const Text('选择格式与范围，按原目录结构返回文件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onScanFolder,
            ),
          ),
        ],
      ),
    );
  }
}

/// 右侧设置：TXT 编码 / 目录识别 / 自定义规则（两条正则可改）/ 无标题策略。
class ImportSettingsPage extends StatelessWidget {
  const ImportSettingsPage({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onBack,
  });

  final ImportSettingsPageState state;
  final ValueChanged<ImportSettings> onChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ImportSettings s = state.settings;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: <Widget>[
          HeaderNavSliver(
            spec: HeaderNavSpec(
              title: '导入设置',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // TXT 编码：自动 / UTF-8 / GBK / Big5 ...
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButton<TxtEncoding>(
                    value: s.encoding,
                    isExpanded: true,
                    items: <DropdownMenuItem<TxtEncoding>>[
                      for (final TxtEncoding e in TxtEncoding.values)
                        DropdownMenuItem<TxtEncoding>(
                          value: e,
                          child: Text(kTxtEncodingLabels[e]!),
                        ),
                    ],
                    onChanged: (TxtEncoding? v) => onChanged(
                      s.copyWith(encoding: v ?? TxtEncoding.auto),
                    ),
                  ),
                ),
                // TXT 目录识别：自动识别 / 自定义规则
                SwitchListTile(
                  title: const Text('自定义目录规则'),
                  subtitle: const Text('关闭时自动识别章节与分卷'),
                  value: s.usesCustomRules,
                  onChanged: (bool v) => onChanged(s.copyWith(
                    tocMode: v ? TxtTocMode.custom : TxtTocMode.auto,
                  )),
                ),
                if (state.showCustomRuleFields) ...<Widget>[
                  // 展示「匹配的章节正则」与「分卷正则」，用户可直接修改。
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      enabled: state.chapterRegexEditable,
                      decoration: const InputDecoration(
                        labelText: '章节正则',
                        helperText: '展示当前匹配的章节正则，可修改',
                      ),
                      controller: TextEditingController(text: s.rules.chapterRegex),
                      onChanged: (String v) => onChanged(
                        s.copyWith(rules: s.rules.copyWith(chapterRegex: v)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      enabled: state.volumeRegexEditable,
                      decoration: const InputDecoration(
                        labelText: '分卷正则',
                        helperText: '展示当前匹配的分卷正则，可修改',
                      ),
                      controller: TextEditingController(text: s.rules.volumeRegex),
                      onChanged: (String v) => onChanged(
                        s.copyWith(rules: s.rules.copyWith(volumeRegex: v)),
                      ),
                    ),
                  ),
                  // 原书未提供标题：补齐章节名 / 标为正文片段
                  RadioListTile<UntitledPolicy>(
                    value: UntitledPolicy.fillChapterName,
                    groupValue: s.untitledPolicy,
                    title: const Text('补齐章节名'),
                    onChanged: (UntitledPolicy? v) => onChanged(
                      s.copyWith(
                          untitledPolicy: v ?? UntitledPolicy.fillChapterName),
                    ),
                  ),
                  RadioListTile<UntitledPolicy>(
                    value: UntitledPolicy.markAsBodyFragment,
                    groupValue: s.untitledPolicy,
                    title: const Text('标为正文片段'),
                    onChanged: (UntitledPolicy? v) => onChanged(
                      s.copyWith(
                          untitledPolicy: v ?? UntitledPolicy.fillChapterName),
                    ),
                  ),
                ],
                // 规则命中预览（匹配到哪些行）
                if (state.preview != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '章节命中：${state.preview!.chapterSamples.join(' / ')}\n'
                      '分卷命中：${state.preview!.volumeSamples.join(' / ')}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 扫描本地文件夹：从上往下 = 扫描格式选择 → 选择扫描范围。
class ScanFolderPage extends StatelessWidget {
  const ScanFolderPage({
    super.key,
    required this.state,
    required this.onSpecChanged,
    required this.onScan,
    required this.onBack,
  });

  final ScanFolderPageState state;
  final ValueChanged<ScanFolderSpec> onSpecChanged;
  final VoidCallback onScan;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: <Widget>[
          HeaderNavSliver(
            spec: HeaderNavSpec(
              title: '扫描本地文件夹',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('扫描格式'),
                ),
                // 全部 / epub / txt / pdf / zip / html ...
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    for (final ScanFormat f in ScanFormat.values)
                      FilterChip(
                        label: Text(f == ScanFormat.all ? '全部' : f.name),
                        selected: state.spec.formats.contains(f),
                        onSelected: (bool _) => onSpecChanged(
                          state.spec.normalized().copyWith(
                                formats: <ScanFormat>{f},
                              ),
                        ),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('选择扫描范围'),
                ),
                for (final ScanScope scope in ScanScope.values)
                  RadioListTile<ScanScope>(
                    value: scope,
                    groupValue: state.spec.scope,
                    title: Text(scope.name),
                    onChanged: (ScanScope? v) => onSpecChanged(
                      state.spec.copyWith(scope: v ?? ScanScope.safDirectory),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: state.scanning ? null : onScan,
                    child: Text(state.scanning ? '扫描中…' : '开始扫描'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 合并页：搜索栏 → 格式分面（全部格式 / 格式 <number>）→ 懒加载列表。
/// 列表项展示**合并后的书籍**（卷组），组内文件列名字 / 格式 / 路径供勾选导入。
class MergeBooksPage extends StatelessWidget {
  const MergeBooksPage({
    super.key,
    required this.state,
    required this.onQuery,
    required this.onFormat,
    required this.onToggle,
    required this.onLoadMore,
    required this.onImportSelected,
    required this.onBack,
  });

  final MergePageState state;
  final ValueChanged<String> onQuery;
  final ValueChanged<ScanFormat> onFormat;
  final ValueChanged<String> onToggle;
  final VoidCallback onLoadMore;
  final VoidCallback onImportSelected;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final List<VolumeGroup> page = state.page();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: <Widget>[
          HeaderNavSliver(
            spec: HeaderNavSpec(
              title: '合并书籍',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
            ),
          ),
          // 1. 搜索栏
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索书名 / 文件名 / 路径',
                ),
                onChanged: onQuery,
              ),
            ),
          ),
          // 2. 格式：全部格式 / 格式 <number>
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  for (final FormatFacet facet in state.facets)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(facet.display),
                        selected: state.activeFormat == facet.format,
                        onSelected: (bool _) => onFormat(facet.format),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 3. 懒加载文件列表（展示合并后的书籍）
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                if (index >= page.length) {
                  // 触底续载，不在滚动回调里查库
                  return TextButton(
                    onPressed: onLoadMore,
                    child: const Text('加载更多'),
                  );
                }
                final VolumeGroup g = page[index];
                return ExpansionTile(
                  title: Text(g.displayTitle),
                  subtitle: Text('合并后 ${g.volumeCount} 卷 · ${g.files.length} 个文件'),
                  children: <Widget>[
                    for (final ScanFile f in g.files)
                      CheckboxListTile(
                        value: state.selectedFileIds.contains(f.id),
                        onChanged: (bool? _) => onToggle(f.id),
                        title: Text(f.name),
                        subtitle: Text('${f.format} · ${f.path}'),
                      ),
                  ],
                );
              },
              childCount: page.length + (state.hasMore ? 1 : 0),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: state.selectedFileIds.isEmpty
                    ? null
                    : onImportSelected,
                child: Text('导入所选（${state.selectedFileIds.length}）'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- 说明 -----------------------------------------------------------------
// ScanFolderSpec.copyWith 与 ScanFolderPage 的格式 chip 在合并进工程时
// 需与 lib/core/model/shelf_prefs.dart 的筛选归一化口径对齐；
// 本轮未编译、未运行、未接入 AppRoutes.onGenerateRoute（需真实页面接线）。
