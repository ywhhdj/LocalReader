// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖
// 合并状态 E13：已落入工程路径 lib/feature/shelf/cloud_book_grid_spec.dart；同名类型已隔离；未编译 / 未运行 / 未下载依赖。
// 设计源：scaffold/cloud_book_grid.dart（交付包内保留，作为规格基线）
// 建议落点：lib/feature/shelf/cloud_book_grid.dart + cloud_shelf_view.dart
//           + lib/core/model/shelf_prefs.dart
// 对应需求：R1（云端以宫格呈现、可切列表/两栏/三栏、无云端书空态提示收藏）
// 对齐：docs/03 §3.5、PLAN.md P8；纯 Dart 便于模型级测试。

import 'package:Local_reader/core/network/network_policy.dart';
import 'package:Local_reader/core/model/navigation_spec.dart'
    show ShelfGridMode, columnsOf;

/// 云端书只登记元数据壳，不整本下载、不导出。
class CloudBook {
  const CloudBook({
    required this.cloudId,
    required this.title,
    this.author = '',
    this.coverUrl,
    this.categories = const <String>[],
  });

  final String cloudId;
  final String title;
  final String author;
  final String? coverUrl;
  final List<String> categories;

  /// `cloud-` 前缀仍是来源筛选唯一判据（docs/03 §3.5）。
  bool get isCloudId => cloudId.startsWith('cloud-');
}

/// 云端列表状态机：空态只在 `books.isEmpty && status != loading` 出现；
/// 失败不覆盖已有缓存（给「重试」而不是清空）；offline 只显示可离线书。
/// 状态枚举复用 network_policy.dart 的 CloudFeedState（六态互斥 + ok）。
class CloudShelfState {
  const CloudShelfState({
    this.books = const <CloudBook>[],
    this.status = CloudFeedState.loading,
    this.gridMode = ShelfGridMode.grid2,
    this.hasCachedData = false,
  });

  final List<CloudBook> books;
  final CloudFeedState status;
  final ShelfGridMode gridMode;
  final bool hasCachedData;

  bool get isLoading => status == CloudFeedState.loading;
  bool get showSkeleton => isLoading && books.isEmpty;
  bool get showEmpty =>
      books.isEmpty &&
      !isLoading &&
      status != CloudFeedState.rateLimited &&
      status != CloudFeedState.unavailable &&
      status != CloudFeedState.upstreamChanged;
  bool get showRetry =>
      status == CloudFeedState.rateLimited ||
      status == CloudFeedState.upstreamChanged ||
      (status == CloudFeedState.unavailable && !hasCachedData);

  /// 三种布局共用同一数据源；切换只改 columns，不触发请求。
  int get columns => columnsOf(gridMode);
}

/// 云端空态：插画 +「还没有云端藏书」+ 主按钮「去收藏」。
class CloudEmptyStateSpec {
  const CloudEmptyStateSpec({
    this.titleKey = 'uiCloudEmpty',
    this.actionKey = 'uiGoCollect',
    this.targets = const <String>['/wenkuLibrary', '/favorites'],
  });

  final String titleKey;
  final String actionKey;
  final List<String> targets;
}

/// 宫格项只渲染封面 + 书名 + 来源角标；封面并发解码由性能档位裁决。
class CloudBookGridSpec {
  const CloudBookGridSpec({
    required this.state,
    this.coverConcurrency = 4,
    this.cacheExtent = 600,
    this.showSourceBadge = true,
  });

  final CloudShelfState state;
  final int coverConcurrency;
  final double cacheExtent;
  final bool showSourceBadge;

  /// 静态验收：grid3 与 list 拿到的是同一个 List<CloudBook> 引用语义，
  /// 合并实现时不得按布局分别缓存两份数据。
  List<CloudBook> get dataSource => state.books;
}

/// CloudShelfGridPrefs 归一化：非宫格模式把列数锁回默认（docs/05 §5.6）。
class CloudShelfGridPrefs {
  const CloudShelfGridPrefs({this.gridEnabled = true, this.gridMode = ShelfGridMode.grid2});

  final bool gridEnabled;
  final ShelfGridMode gridMode;

  CloudShelfGridPrefs normalized() => CloudShelfGridPrefs(
        gridEnabled: gridEnabled,
        gridMode: gridEnabled ? gridMode : ShelfGridMode.list,
      );
}
