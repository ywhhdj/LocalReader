// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖
// 合并状态 E13：已落入工程路径 lib/data/wenku/wenku8_adapter.dart；同名类型已隔离；未编译 / 未运行 / 未下载依赖。
// 设计源：scaffold/wenku8_adapter.dart（交付包内保留，作为规格基线）
// 建议落点：lib/domain/repositories/wenku8_source.dart（契约）
//           + lib/data/wenku/wenku8_adapter_registry.dart（适配规则）
// 对应需求：R3 R7 R10 R12；对齐 mikufoxxx/Wenku8_Flutter 的公开规格。
// 纯 Dart，无 Flutter 依赖，便于 Fake 单测。
//
// 合规：只取列表 / 目录 / 个人书架 / 用户点开的单章；不整本下载、不绕过限制、
//       不下架内容、不伪装 UA、不用中继代理。

enum Wenku8SearchScope { all, title, author, tag, id }

enum Wenku8RankKind { daily, weekly, monthly, all, category, imprint }

enum Wenku8ParseIssueView { none, upstreamChanged, restricted, challenge, empty }

enum Wenku8FeedStatus { ok, loading, rateLimited, unavailable, offline, empty }

// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class Wenku8BookView {
  const Wenku8BookView({
    required this.id,
    required this.title,
    this.author = '',
    this.categories = const <String>[],
    this.tags = const <String>[],
    this.coverUrl = '',
    this.available = true,
  });

  final String id;
  final String title;
  final String author;
  final List<String> categories;
  final List<String> tags;
  final String coverUrl;

  /// 下架 / 版权受限的书为 false，列表出口一律过滤。
  final bool available;
}

// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class Wenku8ListingView {
  const Wenku8ListingView({
    this.books = const <Wenku8BookView>[],
    this.status = Wenku8FeedStatus.ok,
    this.note = '',
    this.hasMore = false,
    this.page = 1,
  });

  final List<Wenku8BookView> books;
  final Wenku8FeedStatus status;
  final String note;
  final bool hasMore;
  final int page;
}

/// 本地阅读口味：只把类别/作者/标签权重交给榜单过滤，不上传阅读明细（R3）。
// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class Wenku8Taste {
  const Wenku8Taste({
    this.categoryWeights = const <String, double>{},
    this.authorWeights = const <String, double>{},
    this.tagWeights = const <String, double>{},
    this.readBookIds = const <String>{},
  });

  final Map<String, double> categoryWeights;
  final Map<String, double> authorWeights;
  final Map<String, double> tagWeights;
  final Set<String> readBookIds;
}

// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class Wenku8ParseOutcomeView<T> {
  const Wenku8ParseOutcomeView.ok(this.value)
      : issue = Wenku8ParseIssueView.none,
        note = '';
  const Wenku8ParseOutcomeView.failed(this.issue, this.note) : value = null;

  final T? value;
  final Wenku8ParseIssueView issue;
  final String note;

  bool get isOk => value != null && issue == Wenku8ParseIssueView.none;
}

/// 目标契约：dev 已有 listing/detail/bookcase，补 rankings / recommendations / searchBy。
abstract interface class Wenku8SourceContract {
  Future<Wenku8ListingView> listing(Object query);
  Future<Wenku8ListingView> rankings(Wenku8RankKind kind, {int page = 1});
  Future<Wenku8ListingView> recommendations(Wenku8Taste taste, {int page = 1});
  Future<Wenku8ListingView> searchBy(
    Wenku8SearchScope scope,
    String keyword, {
    int page = 1,
  });
  Future<Wenku8ListingView?> bookcase();
  Future<Wenku8BookView?> detail(String bookId);

  /// 可选能力：只有用户点开的单章才请求，不批量抓取。
  // Future<String> chapter(String bookId, String chapterId);
}

/// 站点适配规则：按 host + 结构标记选择；核对不上返回 upstreamChanged，
/// 提示页（含「本站正式关闭」类公告）只是站点提示，不代表停服；
/// 绝不把公告页 / 质询页 / 乱码渲染成书目，也不据此推断站点状态。
abstract interface class Wenku8Adapter {
  String get host;
  Wenku8ParseOutcomeView<List<Wenku8BookView>> parseListing(String html, String charset);
  Wenku8ParseOutcomeView<Wenku8BookView> parseDetail(String html, String charset);
}

class Wenku8AdapterRegistry {
  final Map<String, Wenku8Adapter> _byHost = <String, Wenku8Adapter>{};

  void register(Wenku8Adapter adapter) => _byHost[adapter.host] = adapter;

  Wenku8Adapter? select(String host) => _byHost[host];

  /// 无匹配适配规则时，调用方必须据此返回 upstreamChanged 并提示「来源结构已变化」。
  bool supports(String host) => _byHost.containsKey(host);
}

/// 所有列表出口的必经之路（对齐参考仓库 README：不提供下架内容）。
class Wenku8ComplianceView {
  const Wenku8ComplianceView._();

  static List<Wenku8BookView> withoutWithdrawn(List<Wenku8BookView> books) =>
      books.where((Wenku8BookView b) => b.available).toList(growable: false);

  /// 只支持「轻小说文库 + 本地导入」，不提供自定义书源。
  static bool isSupportedSource(String sourceId) =>
      sourceId == 'wenku8' || sourceId == 'local-import';
}

/// 页面分类（用户 2026-11-10 确认口径）：
/// 站点仍在运行，登录 / 注册 / 维护功能正常；「本站正式关闭」类公告只是**提示页**。
/// 返回 notice 时按「非书目、非登录结果」处理，调用方不得据此触发
/// Wenku8FeedStatus.offline / unavailable，也不推断站点停服，继续按实际公开页面适配。
enum Wenku8PageClass { book, login, notice, challenge, unknown }

Wenku8PageClass classifyWenku8Page(String html, {required bool hasForm}) {
  final String h = html.toLowerCase();
  if (h.contains('验证码') || h.contains('captcha') || h.contains('challenge')) {
    return Wenku8PageClass.challenge;
  }
  if (h.contains('本站正式关闭') ||
      h.contains('维护中') ||
      h.contains('站点提示')) {
    return Wenku8PageClass.notice;
  }
  if (hasForm) return Wenku8PageClass.login;
  if (h.contains('toplist') || h.contains('booklist') || h.contains('article')) {
    return Wenku8PageClass.book;
  }
  return Wenku8PageClass.unknown;
}
