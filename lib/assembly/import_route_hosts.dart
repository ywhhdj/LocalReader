import 'package:flutter/material.dart';

import '../core/model/import_prefs.dart';
import '../domain/usecases/scan_result.dart';
import '../feature/import/import_pages.dart';
import '../feature/import/import_pages_widgets.dart';

/// R13 导入流程的**状态宿主**。
///
/// 之前 `AppRoutes` 把 onChanged / onQuery / onToggle / onLoadMore 等回调
/// 全写成 `(_) {}`，页面控件点完没有任何变化。这里把各页自己的纯 Dart
/// 状态机（ImportSettings / ScanFolderSpec / MergePageState）接回 setState，
/// 路由表只负责转发 onBack / onScan 这类跨页动作。
///
/// 分层：assembly 持有局部 UI 状态，feature 页面仍然是无状态展示组件，
/// 不读 AppState、不构造路由。

class ImportSettingsHost extends StatefulWidget {
  const ImportSettingsHost({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ImportSettingsHost> createState() => _ImportSettingsHostState();
}

class _ImportSettingsHostState extends State<ImportSettingsHost> {
  ImportSettingsPageState _state = const ImportSettingsPageState();

  @override
  Widget build(BuildContext context) => ImportSettingsPage(
        state: _state,
        onChanged: (ImportSettings settings) {
          setState(() => _state = ImportSettingsPageState(
                settings: settings,
                dirty: true,
              ));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导入设置已更新')),
          );
        },
        onBack: widget.onBack,
      );
}

class ScanFolderHost extends StatefulWidget {
  const ScanFolderHost({
    super.key,
    required this.onScan,
    required this.onBack,
  });

  final VoidCallback onScan;
  final VoidCallback onBack;

  @override
  State<ScanFolderHost> createState() => _ScanFolderHostState();
}

class _ScanFolderHostState extends State<ScanFolderHost> {
  ScanFolderPageState _state = const ScanFolderPageState();

  @override
  Widget build(BuildContext context) => ScanFolderPage(
        state: _state,
        onSpecChanged: (ScanFolderSpec spec) => setState(
          () => _state = ScanFolderPageState(spec: spec.normalized()),
        ),
        onScan: () {
          setState(() => _state = ScanFolderPageState(
                spec: _state.spec,
                scanning: true,
              ));
          widget.onScan();
        },
        onBack: widget.onBack,
      );
}

class MergeBooksHost extends StatefulWidget {
  const MergeBooksHost({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<MergeBooksHost> createState() => _MergeBooksHostState();
}

class _MergeBooksHostState extends State<MergeBooksHost> {
  late MergePageState _state = MergePageState.fromBatch(_demoBatch());

  static ScanBatch _demoBatch() => ScanBatch(
        id: 'pending',
        roots: const <String>['/sdcard/Books'],
        scope: ScanScope.safDirectory,
        formats: <ScanFormat>{ScanFormat.all},
        files: <ScanFile>[
          ScanFile(
            id: 'f1',
            name: '纸白纪事 第一卷.txt',
            format: 'txt',
            path: '/sdcard/Books/纸白纪事 第一卷.txt',
            parentPath: '/sdcard/Books',
          ),
          ScanFile(
            id: 'f2',
            name: '纸白纪事 第二卷.txt',
            format: 'txt',
            path: '/sdcard/Books/纸白纪事 第二卷.txt',
            parentPath: '/sdcard/Books',
          ),
          ScanFile(
            id: 'f3',
            name: '雨街漫画志.cbz',
            format: 'cbz',
            path: '/sdcard/Books/雨街漫画志.cbz',
            parentPath: '/sdcard/Books',
          ),
          ScanFile(
            id: 'f4',
            name: '海边的目录.epub',
            format: 'epub',
            path: '/sdcard/Books/海边的目录.epub',
            parentPath: '/sdcard/Books',
          ),
        ],
      );

  MergePageState _copyWith({
    String? query,
    ScanFormat? activeFormat,
    Set<String>? selectedFileIds,
    int? loadedCount,
  }) =>
      MergePageState(
        query: query ?? _state.query,
        facets: _state.facets,
        activeFormat: activeFormat ?? _state.activeFormat,
        groups: _state.groups,
        selectedFileIds: selectedFileIds ?? _state.selectedFileIds,
        loadedCount: loadedCount ?? _state.loadedCount,
        pageSize: _state.pageSize,
      );

  void _hint(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => MergeBooksPage(
        state: _state,
        onQuery: (String q) => setState(() => _state = _copyWith(query: q)),
        onFormat: (ScanFormat f) =>
            setState(() => _state = _copyWith(activeFormat: f)),
        onToggle: (String fileId) =>
            setState(() => _state = _state.toggle(fileId)),
        onLoadMore: () => setState(() => _state = _state.loadMore()),
        onImportSelected: () {
          final int count = _state.selectedFileIds.length;
          setState(() => _state = _copyWith(
                selectedFileIds: const <String>{},
              ));
          _hint(context, '已导入 $count 个文件（演示写入）');
        },
        onBack: widget.onBack,
      );
}
