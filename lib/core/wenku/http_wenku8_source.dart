import 'dart:async';

import 'dart:ui' show Color;

import 'wenku8_body_decoder.dart';
import 'wenku8_compliance.dart';
import 'wenku8_endpoints.dart';
import 'wenku8_models.dart';
import 'wenku8_page_parser.dart';
import 'wenku8_session.dart';
import 'wenku8_source.dart';
import 'wenku8_throttle.dart';
import 'wenku8_transport.dart';

/// 章节正文读取是**可选能力**：演示数据源不实现它，AppState 用 `is` 判断。
/// 只读取用户显式点开的单章，不整本下载、不批量抓取、不导出分发。
abstract interface class Wenku8ChapterSource {
  Future<Wenku8ChapterText> chapter(String bookId, String chapterId);
}

/// 真实 Wenku8 数据源（第二十三轮解锁，**替代原静态骨架**）。
///
/// 与 `DemoWenku8Source` 共用同一个 `Wenku8Source` 契约，所以页面、AppState、
/// 合规层、状态机一行都不用改——这正是二十二轮把接入点收成唯一注入口的价值。
///
/// 合规护栏（对应参考仓库 README 与公开资料）：
/// - 只请求 `Wenku8Endpoints` 构造的公开页面；会话 Cookie 只来自来源站点下发的
///   Set-Cookie，不实现中继、代理、appver 伪造、伪装浏览器 UA 或绕过访问限制；
/// - 遇版权受限 / 验证质询**立即停止**，引导用户去官网，不重试、不绕过；
/// - 429 / 503 尊重 `Retry-After` 并退避，不制造重试风暴；
/// - 所有列表出口过 `Wenku8Compliance.withoutWithdrawn()`；
/// - 只取列表 / 目录 / 用户点开的单章，不打包、不缓存整本、不分发。
class HttpWenku8Source implements Wenku8Source, Wenku8ChapterSource {
  HttpWenku8Source({
    required this.endpoints,
    required this.transport,
    Wenku8PageParser? parser,
    Wenku8BodyDecoder? decoder,
    Wenku8Throttle? throttle,
    this.session,
  })  : parser = parser ?? const Wenku8WebPageParser(),
        decoder = decoder ?? const DefaultWenku8BodyDecoder(),
        throttle = throttle ?? Wenku8Throttle();

  final Wenku8Endpoints endpoints;
  final Wenku8Transport transport;
  final Wenku8PageParser parser;
  final Wenku8BodyDecoder decoder;
  final Wenku8Throttle throttle;

  /// 表单登录会话
  final Wenku8Session? session;

  @override
  String get sourceId => Wenku8Compliance.wenku8SourceId;

  void close() => transport.close();

  @override
  Future<Wenku8Listing> listing(Wenku8Query query) async {
    final Wenku8Query q = query.normalized();
    // 第二十五轮：按用户提供的端点清单分流——搜索走 search.php?searchkey=，
    // 榜单走 toplist.php?type=，其余走默认榜单页。
    final Uri uri = q.keyword.isNotEmpty
        ? endpoints.search(q.keyword)
        : endpoints.topList(_typeForFeed(q.feed));
    final _FetchResult r = await _fetch(uri);
    if (r.html == null) {
      return Wenku8Listing(feed: q.feed, books: const <Wenku8Book>[],
          status: r.status, note: r.note);
    }
    final Wenku8ParseOutcome<List<Wenku8Book>> parsed = parser.parseListing(r.html!);
    if (!parsed.isOk) {
      return Wenku8Listing(
        feed: q.feed,
        books: const <Wenku8Book>[],
        status: _statusForParse(parsed.issue),
        note: parsed.note,
      );
    }
    // 合规层是所有列表出口的必经之路。
    final List<Wenku8Book> books =
        Wenku8Compliance.withoutWithdrawn(parsed.value!);
    return Wenku8Listing(
      feed: q.feed,
      books: books,
      status: Wenku8Status.ok,
      note: '公开目录 · 仅元数据',
    );
  }

  /// 榜单类型映射：站点参数含义待真机核对，改这里即可，不动页面。
  static String _typeForFeed(Wenku8FeedKind feed) {
    switch (feed) {
      case Wenku8FeedKind.ranking:
        return 'ranking';
      case Wenku8FeedKind.recent:
        return 'lastupdate';
      case Wenku8FeedKind.completed:
        return 'fullflag';
      case Wenku8FeedKind.recommendation:
      case Wenku8FeedKind.search:
        return 'recommend';
    }
  }

  /// 个人书架：`bookcase.php`，需要登录 Cookie。未登录时不发请求，
  /// 明确返回「请先登录」，不把空书架误显示成「没有书」。
  Future<Wenku8Listing> bookcase() async {
    if (session == null || !session!.isAuthenticated) {
      return const Wenku8Listing(
        feed: Wenku8FeedKind.recommendation,
        books: <Wenku8Book>[],
        status: Wenku8Status.unavailable,
        note: '个人书架需要登录后才能读取；公开目录仍可浏览。',
      );
    }
    final _FetchResult r = await _fetch(endpoints.bookcase());
    if (r.html == null) {
      return Wenku8Listing(
          feed: Wenku8FeedKind.recommendation,
          books: const <Wenku8Book>[],
          status: r.status,
          note: r.note);
    }
    final Wenku8ParseOutcome<List<Wenku8Book>> parsed =
        parser.parseListing(r.html!);
    if (!parsed.isOk) {
      return Wenku8Listing(
          feed: Wenku8FeedKind.recommendation,
          books: const <Wenku8Book>[],
          status: _statusForParse(parsed.issue),
          note: parsed.note);
    }
    return Wenku8Listing(
      feed: Wenku8FeedKind.recommendation,
      books: Wenku8Compliance.withoutWithdrawn(parsed.value!),
      status: Wenku8Status.ok,
      note: '个人书架 · 仅元数据',
    );
  }

  @override
  Future<Wenku8Detail?> detail(String bookId) async {
    if (bookId.isEmpty) return null;
    final _FetchResult r = await _fetch(endpoints.detail(bookId));
    if (r.html == null) return null;
    // 详情需要一本基础书壳：优先用已缓存列表里的条目，避免再发一次请求。
    final Wenku8Book fallback = Wenku8Book(
      id: bookId,
      title: 'Wenku8 书目 $bookId',
      author: '',
      coverColor: const Color(0xFF6E8CA8),
      tags: const <String>['Wenku8'],
      latestChapter: '',
      updatedKey: '',
    );
    final Wenku8ParseOutcome<Wenku8Detail> parsed =
        parser.parseDetail(r.html!, fallback);
    return parsed.isOk ? parsed.value : null;
  }

  @override
  Future<Wenku8ChapterText> chapter(String bookId, String chapterId) async {
    final _FetchResult r = await _fetch(endpoints.reader(bookId, chapterId));
    if (r.html == null) {
      return Wenku8ChapterText.failed(bookId, chapterId, r.status, r.note);
    }
    final Wenku8ParseOutcome<Wenku8ChapterText> parsed =
        parser.parseChapter(r.html!, bookId, chapterId);
    if (parsed.isOk) return parsed.value!;
    return Wenku8ChapterText.failed(
      bookId,
      chapterId,
      _statusForParse(parsed.issue),
      parsed.note,
    );
  }

  Wenku8Status _statusForParse(Wenku8ParseIssue issue) {
    switch (issue) {
      case Wenku8ParseIssue.upstreamChanged:
        return Wenku8Status.upstreamChanged;
      case Wenku8ParseIssue.restricted:
      case Wenku8ParseIssue.challenge:
        return Wenku8Status.restricted;
      case Wenku8ParseIssue.empty:
        return Wenku8Status.unavailable;
      case Wenku8ParseIssue.none:
        return Wenku8Status.ok;
    }
  }

  /// 单次取页：超时 / 5xx 才有限退避；限流与受限一律不重试。
  Future<_FetchResult> _fetch(Uri uri) async {
    final Duration pending = throttle.pendingDelay();
    if (pending > Duration.zero) await Future<void>.delayed(pending);
    retry: for (int attempt = 0; attempt <= throttle.maxRetries; attempt++) {
      try {
        throttle.markRequest();
        final Wenku8RawResponse response = await transport.get(uri);
        final Wenku8TransportIssue issue = classifyTransport(response.statusCode);
        switch (issue) {
          case Wenku8TransportIssue.rateLimited: {
            // 尊重限流，不立刻重试；把 Retry-After 写进说明供界面呈现。
            final String ra = response.header('retry-after');
            final Duration? wait = Wenku8Throttle.parseRetryAfter(ra);
            return _FetchResult(
              Wenku8Status.rateLimited,
              wait == null
                  ? '来源已限流，请稍后再试，不要反复刷新。'
                  : '来源已限流，建议 ${wait.inSeconds} 秒后再试。',
            );
          }
          case Wenku8TransportIssue.denied:
            // 401 / 403 通常意味着登录态失效：Cookie 与认证标记一起清空。
            session?.invalidate();
            return const _FetchResult(
              Wenku8Status.restricted,
              '来源拒绝该请求；请到官网确认可读状态，本应用不绕过访问限制。',
            );
          case Wenku8TransportIssue.serverError:
            if (attempt < throttle.maxRetries) {
              await Future<void>.delayed(throttle.backoffFor(attempt));
              continue retry;
            }
            return const _FetchResult(
                Wenku8Status.unavailable, '来源暂时不可用，请稍后再试。');
          case Wenku8TransportIssue.timeout:
          case Wenku8TransportIssue.socket:
            if (attempt < throttle.maxRetries) {
              await Future<void>.delayed(throttle.backoffFor(attempt));
              continue retry;
            }
            return const _FetchResult(
                Wenku8Status.unavailable, '请求超时或网络不可用，请稍后再试。');
          case Wenku8TransportIssue.none: {
            final String probe = probeAscii(response.bodyBytes);
            final String html = decoder.decode(
              response.bodyBytes,
              response.header('content-type'),
              probe,
            );
            return _FetchResult(Wenku8Status.ok, '公开目录 · 仅元数据', html);
          }
        }
      } on TimeoutException {
        if (attempt < throttle.maxRetries) {
          await Future<void>.delayed(throttle.backoffFor(attempt));
          continue;
        }
        return const _FetchResult(
            Wenku8Status.unavailable, '请求超时，请稍后再试。');
      } catch (_) {
        if (attempt < throttle.maxRetries) {
          await Future<void>.delayed(throttle.backoffFor(attempt));
          continue;
        }
        return const _FetchResult(
            Wenku8Status.unavailable, '网络请求失败，请检查连接后重试。');
      }
    }
    return const _FetchResult(Wenku8Status.unavailable, '请求未完成。');
  }
}

class _FetchResult {
  const _FetchResult(this.status, this.note, [this.html]);

  final Wenku8Status status;
  final String note;
  final String? html;
}
