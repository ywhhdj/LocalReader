import 'package:Local_reader/core/network/network_policy.dart';
import 'package:Local_reader/assembly/route_contract.dart';
import 'package:Local_reader/core/model/navigation_spec.dart' show SearchScope;

/// 防抖 + 取消：不在输入每个字符时打网络请求。
class SearchQueryPolicy {
  const SearchQueryPolicy({
    this.debounceMs = 300,
    this.cancelPreviousOnNewInput = true,
    this.minLength = 1,
  });

  final int debounceMs;
  final bool cancelPreviousOnNewInput;
  final int minLength;
}

enum HitSource { local, cloud, wenku }

class SearchHit {
  const SearchHit({
    required this.id,
    required this.title,
    required this.source,
    this.author = '',
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final HitSource source;
  final String author;
  final List<String> tags;

  bool get isCloud => source != HitSource.local;
}

/// 搜索页从上到下：SearchField → SearchScopeNav（书名/作者/标签）→ 结果区。
/// 返回页面保留关键词与已加载结果。
class SearchPageState {
  const SearchPageState({
    required this.args,
    this.query = '',
    this.localHits = const <SearchHit>[],
    this.cloudHits = const <SearchHit>[],
    this.wenkuHits = const <SearchHit>[],
    this.page = 1,
    this.hasMore = false,
    this.status = CloudFeedState.ok,
    this.token,
  });

  final SearchSpecArgs args;
  final String query;
  final List<SearchHit> localHits;
  final List<SearchHit> cloudHits;
  final List<SearchHit> wenkuHits;
  final int page;
  final bool hasMore;
  final CloudFeedState status;
  final RequestToken? token;

  bool get isShelf => args.isShelfSearch;
  bool get isWenku => args.isWenkuSearch;
  bool get showSkeleton => status == CloudFeedState.loading;
}

/// 范围筛选是唯一出口：标签不从书名猜测（对齐参考仓库 SEARCH.md）。
bool matchesScope(SearchHit hit, SearchScope scope, String query) {
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) return false;
  switch (scope) {
    case SearchScope.all:
      return hit.title.toLowerCase().contains(q) ||
          hit.author.toLowerCase().contains(q) ||
          hit.tags.any((String t) => t.toLowerCase().contains(q));
    case SearchScope.title:
      return hit.title.toLowerCase().contains(q);
    case SearchScope.author:
      return hit.author.toLowerCase().contains(q);
    case SearchScope.tag:
      // 只匹配显式标签字段，绝不从 title 反推。
      return hit.tags.any((String t) => t.toLowerCase().contains(q));
    case SearchScope.id:
      return hit.id.toLowerCase() == q;
  }
}

/// 书架搜索合并本地 + 云端两路结果：按来源分组、按 id 去重，
/// 本地优先；云端刷新不得把本地结果顶掉。文库搜索只走 wenku，支持续载。
class SearchMerger {
  const SearchMerger();

  List<SearchHit> mergeShelf(
    List<SearchHit> local,
    List<SearchHit> cloud, {
    SearchScope scope = SearchScope.all,
    String query = '',
  }) {
    final Set<String> seen = <String>{};
    final List<SearchHit> out = <SearchHit>[];
    for (final SearchHit h in local) {
      if (seen.add(h.id) && _pass(h, scope, query)) out.add(h);
    }
    for (final SearchHit h in cloud) {
      if (seen.add(h.id) && _pass(h, scope, query)) out.add(h);
    }
    return out;
  }

  List<SearchHit> mergeWenku(
    List<SearchHit> existing,
    List<SearchHit> incoming, {
    SearchScope scope = SearchScope.all,
    String query = '',
  }) {
    final Set<String> seen = existing.map((SearchHit h) => h.id).toSet();
    final List<SearchHit> out = <SearchHit>[...existing];
    for (final SearchHit h in incoming) {
      if (seen.add(h.id) && _pass(h, scope, query)) out.add(h);
    }
    return out;
  }

  bool _pass(SearchHit h, SearchScope scope, String query) =>
      query.trim().isEmpty || matchesScope(h, scope, query);
}
