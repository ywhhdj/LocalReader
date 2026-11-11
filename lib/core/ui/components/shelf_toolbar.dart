import 'package:flutter/material.dart';

import '../../common/design_tokens.dart';
import '../../model/library_scope.dart';

/// 工具条左侧的「本地 / 云端」范围切换。云端一侧还带来源选择入口，
/// 但组件不发起请求、不读 AppState，只把选择回传给页面。
class LibraryScopeBar extends StatelessWidget {
  const LibraryScopeBar({
    super.key,
    required this.value,
    required this.localLabel,
    required this.cloudLabel,
    required this.onChanged,
  });

  final LibraryScope value;
  final String localLabel;
  final String cloudLabel;
  final ValueChanged<LibraryScope> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<LibraryScope>(
        segments: <ButtonSegment<LibraryScope>>[
          ButtonSegment<LibraryScope>(
              value: LibraryScope.local, label: Text(localLabel)),
          ButtonSegment<LibraryScope>(
              value: LibraryScope.cloud, label: Text(cloudLabel)),
        ],
        selected: <LibraryScope>{value},
        onSelectionChanged: (Set<LibraryScope> s) => onChanged(s.first),
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
      );
}

/// 分类下拉：本地用自定义分组，云端用 Wenku8 分类 + 来源。
/// 选项与文案都由页面传入，组件只负责呈现与回传。
class CategoryOption {
  const CategoryOption({required this.id, required this.label});

  final String id;
  final String label;
}

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onChanged,
    this.sources = const <CategoryOption>[],
    this.selectedSourceId,
    this.onSourceChanged,
  });

  final String label;
  final List<CategoryOption> options;
  final String selectedId;
  final ValueChanged<String> onChanged;
  final List<CategoryOption> sources;
  final String? selectedSourceId;
  final ValueChanged<String>? onSourceChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: (String value) {
        if (value.startsWith('source:') && onSourceChanged != null) {
          onSourceChanged!(value.substring('source:'.length));
          return;
        }
        onChanged(value);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        for (final CategoryOption o in options)
          PopupMenuItem<String>(
            value: o.id,
            child: Row(
              children: <Widget>[
                if (o.id == selectedId)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: LrSpacing.xs),
                Text(o.label, style: text.bodyMedium),
              ],
            ),
          ),
        if (sources.isNotEmpty) ...<PopupMenuEntry<String>>[
          const PopupMenuDivider(),
          for (final CategoryOption s in sources)
            PopupMenuItem<String>(
              value: 'source:${s.id}',
              child: Row(
                children: <Widget>[
                  if (s.id == selectedSourceId)
                    const Icon(Icons.cloud_outlined, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: LrSpacing.xs),
                  Text(s.label, style: text.bodySmall),
                ],
              ),
            ),
        ],
      ],
      child: Chip(
        label: Text(label, style: text.labelMedium),
        avatar: const Icon(Icons.category_outlined, size: 16),
      ),
    );
  }
}

/// 书架页唯一的一栏：左侧「范围 + 分类」，右侧「布局 + 筛选」。
/// 页面只展示数据，设置 / 关于 / 提示一律不放在这一栏。
class ShelfToolbar extends StatelessWidget {
  const ShelfToolbar({
    super.key,
    required this.scope,
    required this.localLabel,
    required this.cloudLabel,
    required this.onScopeChanged,
    required this.categoryLabel,
    required this.categoryOptions,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.layoutLabel,
    required this.onLayoutPressed,
    required this.filterLabel,
    required this.filterActive,
    required this.onFilterPressed,
    this.sources = const <CategoryOption>[],
    this.selectedSourceId,
    this.onSourceChanged,
  });

  final LibraryScope scope;
  final String localLabel;
  final String cloudLabel;
  final ValueChanged<LibraryScope> onScopeChanged;
  final String categoryLabel;
  final List<CategoryOption> categoryOptions;
  final String selectedCategoryId;
  final ValueChanged<String> onCategoryChanged;
  final String layoutLabel;
  final VoidCallback onLayoutPressed;
  final String filterLabel;
  final bool filterActive;
  final VoidCallback onFilterPressed;
  final List<CategoryOption> sources;
  final String? selectedSourceId;
  final ValueChanged<String>? onSourceChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LrSpacing.m),
      child: Row(
        children: <Widget>[
          LibraryScopeBar(
            value: scope,
            localLabel: localLabel,
            cloudLabel: cloudLabel,
            onChanged: onScopeChanged,
          ),
          const SizedBox(width: LrSpacing.xs),
          Expanded(
            child: CategorySelector(
              label: categoryLabel,
              options: categoryOptions,
              selectedId: selectedCategoryId,
              onChanged: onCategoryChanged,
              sources: scope == LibraryScope.cloud
                  ? sources
                  : const <CategoryOption>[],
              selectedSourceId: selectedSourceId,
              onSourceChanged: onSourceChanged,
            ),
          ),
          IconButton(
            tooltip: layoutLabel,
            icon: const Icon(Icons.view_quilt_outlined, size: 20),
            onPressed: onLayoutPressed,
          ),
          IconButton(
            tooltip: filterLabel,
            icon: Icon(
              filterActive ? Icons.filter_alt : Icons.filter_alt_outlined,
              size: 20,
              color: filterActive ? scheme.primary : null,
            ),
            onPressed: onFilterPressed,
          ),
        ],
      ),
    );
  }
}
