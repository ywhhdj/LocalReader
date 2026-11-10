import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/wenku/http_wenku8_source.dart';
import 'package:local_reader/core/wenku/wenku8_compliance.dart';
import 'package:local_reader/core/wenku/wenku8_endpoints.dart';
import 'package:local_reader/core/wenku/wenku8_models.dart';
import 'package:local_reader/core/wenku/wenku8_source.dart';
import 'package:local_reader/core/wenku/wenku8_throttle.dart';
import 'package:local_reader/core/wenku/wenku8_transport.dart';

/// 内存 Fake：不联网、不需要 SDK，把状态映射写成可编译规格。
class FakeWenku8Transport implements Wenku8Transport {
  FakeWenku8Transport(this.respond);

  final Wenku8RawResponse Function(Uri uri) respond;
  final List<Uri> requested = <Uri>[];
  bool closed = false;

  @override
  Future<Wenku8RawResponse> get(Uri uri) async {
    requested.add(uri);
    return respond(uri);
  }

  @override
  void close() => closed = true;
}

Wenku8RawResponse html(String body,
        {int status = 200, Map<String, String>? headers}) =>
    Wenku8RawResponse(
      statusCode: status,
      bodyBytes: Uint8List.fromList(utf8.encode(body)),
      headers: headers ??
          const <String, String>{'content-type': 'text/html; charset=utf-8'},
    );

const String kListingPage = '''
<html><head><meta charset="utf-8"></head><body>
<a href="/book/101.htm">雪国的旅行者</a>
<a href="/book/102.htm">与星群同行的午后</a>
<a href="/book/103.htm">被目录遗忘的那一册</a>
</body></html>
''';

const String kDetailPage = '''
<html><body><a href="/book/101.htm">目录</a>
<a href="reader.php?cid=1">第一章</a><a href="reader.php?cid=2">第二章</a>
</body></html>
''';

HttpWenku8Source sourceFor(FakeWenku8Transport t, {int maxRetries = 0}) {
  final Wenku8Endpoints ep = Wenku8Endpoints.publicWeb();
  return HttpWenku8Source(
    endpoints: ep,
    transport: t,
    throttle: Wenku8Throttle(maxRetries: maxRetries, zeroBackoff: true),
  );
}

void main() {
  group('真实数据源：榜单 / 搜索 / 详情 / 章节', () {
    test('公开目录解析成书，且只请求端点层构造的地址', () async {
      final FakeWenku8Transport t =
          FakeWenku8Transport((Uri _) => html(kListingPage));
      final HttpWenku8Source s = sourceFor(t);
      final Wenku8Listing l = await s.listing(const Wenku8Query());
      expect(l.status, Wenku8Status.ok);
      expect(l.books.length, 3);
      expect(l.books.first.id, '101');
      expect(t.requested.length, 1);
      expect(t.requested.single.scheme, 'https');
      expect(t.requested.single.host, 'www.wenku8.net');
      expect(s.sourceId, Wenku8Compliance.wenku8SourceId);
    });

    test('搜索走 search 端点并带关键词', () async {
      final FakeWenku8Transport t =
          FakeWenku8Transport((Uri _) => html(kListingPage));
      await sourceFor(t).listing(const Wenku8Query(keyword: '雪国'));
      expect(t.requested.single.queryParameters['keyword'], '雪国');
    });

    test('详情给卷与章，chapterId 可传给章节读取', () async {
      final FakeWenku8Transport t =
          FakeWenku8Transport((Uri _) => html(kDetailPage));
      final Wenku8Detail? d = await sourceFor(t).detail('101');
      expect(d, isNotNull);
      expect(d!.chapterCount, 2);
      expect(d.volumes.first.chapters.first.chapterId, '1');
    });

    test('单章只取用户点开的那一章，不整本拼接', () async {
      final String page = '<html><body><div>' +
          List<String>.filled(30, '正文内容').join() +
          '</div></body></html>';
      final FakeWenku8Transport t = FakeWenku8Transport((Uri _) => html(page));
      final Wenku8ChapterText c = await sourceFor(t).chapter('101', '1');
      expect(c.isReadable, isTrue);
      expect(c.bookId, '101');
      expect(c.chapterId, '1');
    });

    test('下架 / 版权受限页面不返回书，也不重试', () async {
      final FakeWenku8Transport t = FakeWenku8Transport(
          (Uri _) => html('<html><body>因版权原因已下架，暂不提供阅读</body></html>'));
      final Wenku8Listing l =
          await sourceFor(t, maxRetries: 2).listing(const Wenku8Query());
      expect(l.status, Wenku8Status.restricted);
      expect(l.books, isEmpty);
      expect(t.requested.length, 1, reason: '受限一律不重试、不绕过');
    });

    test('访问验证质询明确提示去官网，不尝试绕过', () async {
      final FakeWenku8Transport t = FakeWenku8Transport(
          (Uri _) => html('<html><body>请完成访问验证</body></html>'));
      final Wenku8Listing l =
          await sourceFor(t, maxRetries: 2).listing(const Wenku8Query());
      expect(l.status, Wenku8Status.restricted);
      expect(l.note, contains('官网'));
      expect(t.requested.length, 1);
    });
  });

  group('第三方服务常态映射到状态机', () {
    test('429 尊重限流，不立刻重试', () async {
      final FakeWenku8Transport t = FakeWenku8Transport((Uri _) => html(
          'slow down',
          status: 429,
          headers: const <String, String>{'retry-after': '20'}));
      final Wenku8Listing l =
          await sourceFor(t, maxRetries: 2).listing(const Wenku8Query());
      expect(l.status, Wenku8Status.rateLimited);
      expect(l.note, contains('20'));
      expect(t.requested.length, 1);
    });

    test('503 带 Retry-After 也归类为限流', () async {
      final FakeWenku8Transport t =
          FakeWenku8Transport((Uri _) => html('busy', status: 503));
      expect((await sourceFor(t).listing(const Wenku8Query())).status,
          Wenku8Status.rateLimited);
    });

    test('5xx 有限退避重试后仍失败 → unavailable', () async {
      final FakeWenku8Transport t =
          FakeWenku8Transport((Uri _) => html('oops', status: 500));
      expect(
          (await sourceFor(t, maxRetries: 2).listing(const Wenku8Query()))
              .status,
          Wenku8Status.unavailable);
      expect(t.requested.length, 3);
    });

    test('401/403 归为受限，明确不尝试登录或伪造凭据', () async {
      final FakeWenku8Transport t =
          FakeWenku8Transport((Uri _) => html('forbidden', status: 403));
      expect(
          (await sourceFor(t, maxRetries: 2).listing(const Wenku8Query()))
              .status,
          Wenku8Status.restricted);
      expect(t.requested.length, 1);
    });

    test('页面结构不匹配 → upstreamChanged，不把乱码当内容', () async {
      final FakeWenku8Transport t = FakeWenku8Transport(
          (Uri _) => html('<html><body>short</body></html>'));
      final Wenku8Listing l = await sourceFor(t).listing(const Wenku8Query());
      expect(l.status, Wenku8Status.upstreamChanged);
      expect(l.books, isEmpty);
    });
  });

  group('端点与装配护栏', () {
    test('端点层 owns() 拒绝第三方中继地址', () {
      final Wenku8Endpoints ep = Wenku8Endpoints.publicWeb();
      expect(ep.owns(ep.listing()), isTrue);
      expect(
          ep.owns(Uri.parse('https://relay.example.com/book/1.htm')), isFalse);
      expect(ep.owns(Uri.parse('http://www.wenku8.net/')), isFalse,
          reason: '强制 HTTPS');
    });

    test('HttpWenku8Transport 拒绝非端点地址', () async {
      final Wenku8Endpoints ep = Wenku8Endpoints.publicWeb();
      final HttpWenku8Transport t = HttpWenku8Transport(endpoints: ep);
      await expectLater(
        t.get(Uri.parse('https://relay.example.com/')),
        throwsArgumentError,
      );
      t.close();
    });

    test('dispose 时关闭真实源的底层 client', () {
      final FakeWenku8Transport t =
          FakeWenku8Transport((Uri _) => html(kListingPage));
      sourceFor(t).close();
      expect(t.closed, isTrue);
    });
  });
}
