import 'package:flutter/foundation.dart';

import 'wenku8_models.dart';
export 'wenku8_status.dart';

@immutable
class Wenku8Query {
  const Wenku8Query({
    this.feed = Wenku8FeedKind.recommendation,
    this.keyword = '',
  });

  final Wenku8FeedKind feed;
  final String keyword;

  Wenku8Query copyWith({Wenku8FeedKind? feed, String? keyword}) => Wenku8Query(
        feed: feed ?? this.feed,
        keyword: keyword ?? this.keyword,
      );

  /// 搜索时强制归一到 `search` 榜单，避免「排行榜 + 关键词」这种自相矛盾的条件。
  Wenku8Query normalized() => keyword.trim().isEmpty
      ? (feed == Wenku8FeedKind.search
          ? Wenku8Query(feed: Wenku8FeedKind.recommendation)
          : this)
      : Wenku8Query(feed: Wenku8FeedKind.search, keyword: keyword.trim());

  @override
  bool operator ==(Object other) =>
      other is Wenku8Query && other.feed == feed && other.keyword == keyword;

  @override
  int get hashCode => Object.hash(feed, keyword);
}

/// Wenku8 **唯一可注入的数据源契约**。
///
/// 默认由 `Wenku8Bootstrap.build()` 注入 `HttpWenku8Source`（真实 HTTP）；
/// `useDemo: true` 切回 `DemoWenku8Source`（确定性演示数据、零请求）。
/// 两者共用同一契约，页面 / 状态 / 合规层一行都不用改——这是二十二轮把接入点
/// 收成唯一注入口的价值。`pureLocal` 锁定态由 AppState 提前返回，零请求。
abstract interface class Wenku8Source {
  Future<Wenku8Listing> listing(Wenku8Query query);
  Future<Wenku8Detail?> detail(String bookId);

  /// 单一来源标识，供合规层核对「不允许自定义书源」。
  String get sourceId;
}
