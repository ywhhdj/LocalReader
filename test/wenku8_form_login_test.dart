import 'dart:typed_data';

import 'package:charset/charset.dart';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/wenku/http_wenku8_source.dart';
import 'package:local_reader/core/wenku/wenku8_cookie.dart';
import 'package:local_reader/core/wenku/wenku8_endpoints.dart';
import 'package:local_reader/core/wenku/wenku8_form_encoding.dart';
import 'package:local_reader/core/wenku/wenku8_hosts.dart';
import 'package:local_reader/core/wenku/wenku8_login_inspection.dart';
import 'package:local_reader/core/wenku/wenku8_page_parser.dart';
import 'package:local_reader/core/wenku/wenku8_session.dart';
import 'package:local_reader/core/wenku/wenku8_models.dart';
import 'package:local_reader/core/wenku/wenku8_transport.dart';

const String kLoginForm = '<html><form method="post" action="/login.php">'
    '<input name="username"><input type="password" name="password">'
    '<input type="submit" name="submit" value="login"></form></html>';

const String kClosurePage = '<html><body>感谢每一位朋友的支持，希望我们有缘再相聚。'
    '本站正式关闭。 轻小说文库(2009.03.16-2015.12.24)'
    '<h1>用户登录</h1></body></html>';

const String kListingPage = '<html><a href="/book/2312.htm">Book A</a>'
    '<a href="/book/2313.htm">Book B</a></html>';

Wenku8RawResponse resp(
  String html, {
  int status = 200,
  String location = '',
  List<String> setCookies = const <String>[],
}) =>
    Wenku8RawResponse(
      statusCode: status,
      bodyBytes: Uint8List.fromList(gbk.encode(html)),
      headers: <String, String>{
        'content-type': 'text/html; charset=gbk',
        if (location.isNotEmpty) 'location': location,
      },
      setCookies: setCookies,
    );

class FakeTransport implements Wenku8Transport, Wenku8AuthTransport {
  FakeTransport({required this.loginHtml, this.postResponse});

  final String loginHtml;
  Wenku8RawResponse? postResponse;
  int getCount = 0;
  int postCount = 0;
  Uri? lastPostUri;
  Map<String, String> lastFields = <String, String>{};

  @override
  Future<Wenku8RawResponse> get(Uri uri) async {
    getCount++;
    return resp(loginHtml);
  }

  @override
  Future<Wenku8RawResponse> postForm(
    Uri uri,
    Map<String, String> fields, {
    bool followRedirects = false,
  }) async {
    postCount++;
    lastPostUri = uri;
    lastFields = fields;
    return postResponse ?? resp('');
  }

  @override
  void close() {}
}

Wenku8Session sessionFor(FakeTransport t, {Wenku8CookieStore? store}) {
  final Wenku8Endpoints ep = Wenku8Endpoints.publicWeb();
  return Wenku8Session(
    endpoints: ep,
    transport: t,
    authTransport: t,
    cookieStore: store,
  );
}

void main() {
  group('用户提供的六类端点', () {
    final Wenku8Endpoints ep = Wenku8Endpoints.publicWeb();

    test('登录 / 书架 / 搜索 / 榜单 / 详情 / 章节路径齐全', () {
      expect(ep.login().path, '/login.php');
      expect(ep.bookcase().path, '/modules/article/bookcase.php');
      expect(ep.search('雪国').path, '/modules/article/search.php');
      expect(ep.search('雪国').queryParameters['searchkey'], '雪国');
      expect(ep.topList('ranking').path, '/modules/article/toplist.php');
      expect(ep.topList('ranking').queryParameters['type'], 'ranking');
      expect(ep.detail('2312').path, '/book/2312.htm');
      expect(ep.reader('2312', '7').path, '/modules/article/reader.php');
      expect(ep.reader('2312', '7').queryParameters['aid'], '2312');
      expect(ep.reader('2312', '7').queryParameters['cid'], '7');
      expect(ep.chapter('2312', '7').queryParameters['cid'], '7');
    });

    test('两个域名都在白名单，第三方中继被拒绝', () {
      expect(ep.owns(Uri.parse('https://www.wenku8.net/login.php')), isTrue);
      expect(ep.owns(Uri.parse('https://www.wenku8.com/login.php')), isTrue);
      expect(ep.owns(Uri.parse('https://relay.example/login.php')), isFalse);
      expect(ep.owns(Uri.parse('http://www.wenku8.net/login.php')), isFalse);
      expect(Wenku8Hosts.allowed.length, 2);
    });

    test('切换域名只接受白名单值', () {
      expect(ep.withAuthority('www.wenku8.com').authority, 'www.wenku8.com');
      expect(ep.withAuthority('evil.example').authority, 'www.wenku8.net');
    });
  });

  group('Cookie 解析', () {
    test('单条与属性段', () {
      final List<Wenku8Cookie> c = Wenku8CookieCodec.parse(
          'sid=abc123; Path=/; HttpOnly; Expires=Wed, 09 Jun 2027 10:00:00 GMT');
      expect(c.length, 1);
      expect(c.single.name, 'sid');
      expect(c.single.value, 'abc123');
    });

    test('多个 Set-Cookie 合并成一条时不被 Expires 逗号切坏', () {
      final List<Wenku8Cookie> c = Wenku8CookieCodec.parse(
          'a=1; Expires=Wed, 09 Jun 2027 10:00:00 GMT, b=2; Path=/, c=3');
      expect(c.map((Wenku8Cookie x) => x.name).toList(), <String>['a', 'b', 'c']);
    });

    test('认证标记：匿名 Cookie 不算已登录', () {
      final InMemoryWenku8CookieStore store = InMemoryWenku8CookieStore();
      store.absorb(<String>['anon=xyz; Path=/']);
      expect(store.isAuthenticated, isFalse);
      store.absorb(<String>['sid=abc; Path=/']);
      store.markAuthenticated(<String>['sid']);
      expect(store.isAuthenticated, isTrue);
      expect(store.cookieHeader(Uri.parse('https://www.wenku8.net/')),
          contains('sid=abc'));
      store.clear();
      expect(store.isAuthenticated, isFalse);
      expect(store.cookieCount, 0);
    });

    test('Cookie 的 toString 不含明文值', () {
      expect(const Wenku8Cookie('sid', 'secret').toString(),
          isNot(contains('secret')));
    });
  });

  group('GBK 表单编码', () {
    test('中文字段值按 GBK 百分号编码，不是 UTF-8', () {
      final String encoded = Wenku8FormEncoding.encodeValue('登录');
      expect(encoded, isNot(contains('登录')));
      expect(encoded.startsWith('%'), isTrue);
      // UTF-8 的「登」是 E7 99 BB，GBK 是 B5 C7；这里只验证不是 UTF-8 序列。
      expect(encoded.toUpperCase(), isNot(contains('%E7%99%BB')));
      expect(gbk.decode(<int>[0xB5, 0xC7]), '登');
    });

    test('ASCII 保持可读，空格转 +', () {
      expect(Wenku8FormEncoding.encodeValue('abc-123'), 'abc-123');
      expect(Wenku8FormEncoding.encodeValue('a b'), 'a+b');
    });

    test('登录表单三个字段齐全', () {
      final Map<String, String> f =
          Wenku8FormEncoding.loginFields('user', 'pass');
      expect(f.keys, <String>['username', 'password', 'submit']);
      expect(f['submit'], '登录');
      expect(Wenku8FormEncoding.encode(f), contains('username=user'));
    });
  });

  group('登录页结构检查', () {
    const Wenku8LoginPageInspector inspector = Wenku8LoginPageInspector();

    test('正常表单可提交', () {
      expect(inspector.inspect(kLoginForm).canSubmit, isTrue);
    });

    test('站点关闭公告被识别，且不可提交', () {
      final Wenku8LoginInspection r = inspector.inspect(kClosurePage);
      expect(r.issue, Wenku8LoginPageIssue.sourceClosed);
      expect(r.closureNotice, isTrue);
      expect(r.canSubmit, isFalse);
    });

    test('没有表单 / 验证质询 / 空页面分别归类', () {
      expect(inspector.inspect('<html><body>hello</body></html>').issue,
          Wenku8LoginPageIssue.noForm);
      expect(inspector.inspect('<html>访问验证</html>').issue,
          Wenku8LoginPageIssue.challenge);
      expect(inspector.inspect('  ').issue, Wenku8LoginPageIssue.empty);
    });
  });

  group('会话状态机', () {
    test('302 + Location 非登录页 + 认证 Cookie → 登录成功', () async {
      final FakeTransport t = FakeTransport(
        loginHtml: kLoginForm,
        postResponse: resp('', status: 302,
            location: '/modules/article/bookcase.php',
            setCookies: <String>['sid=abc; Path=/; HttpOnly']),
      );
      final Wenku8Session s = sessionFor(t);
      final Wenku8LoginOutcome o = await s.login('user', 'pass');
      expect(o.isSuccess, isTrue);
      expect(s.isAuthenticated, isTrue);
      expect(s.state, Wenku8AuthState.loggedIn);
      expect(t.getCount, 1);
      expect(t.postCount, 1);
      expect(t.lastFields['username'], 'user');
      expect(t.lastPostUri!.path, '/login.php');
    });

    test('302 又跳回登录页 = 失败，不误判为成功', () async {
      final FakeTransport t = FakeTransport(
        loginHtml: kLoginForm,
        postResponse: resp('', status: 302, location: '/login.php?error=1',
            setCookies: <String>['sid=abc']),
      );
      final Wenku8Session s = sessionFor(t);
      expect((await s.login('u', 'p')).isSuccess, isFalse);
      expect(s.isAuthenticated, isFalse);
    });

    test('只有 Cookie、没有成功重定向也不算登录', () async {
      final FakeTransport t = FakeTransport(
        loginHtml: kLoginForm,
        postResponse: resp('ok', setCookies: <String>['sid=abc']),
      );
      final Wenku8Session s = sessionFor(t);
      expect((await s.login('u', 'p')).isSuccess, isFalse);
    });

    test('站点关闭公告：一次 POST 都不发，凭据不被提交', () async {
      final FakeTransport t = FakeTransport(loginHtml: kClosurePage);
      final Wenku8Session s = sessionFor(t);
      final Wenku8LoginOutcome o = await s.login('user', 'pass');
      expect(o.result, Wenku8LoginResult.sourceClosed);
      expect(s.state, Wenku8AuthState.sourceClosed);
      expect(t.postCount, 0);
      expect(t.getCount, 1);
    });

    test('空用户名 / 密码不发出任何请求', () async {
      final FakeTransport t = FakeTransport(loginHtml: kLoginForm);
      final Wenku8Session s = sessionFor(t);
      expect((await s.login('', 'p')).result, Wenku8LoginResult.emptyFields);
      expect((await s.login('u', '')).result, Wenku8LoginResult.emptyFields);
      expect(t.getCount, 0);
      expect(t.postCount, 0);
    });

    test('退出 / 失效 / 换域名都清空认证态', () async {
      final FakeTransport t = FakeTransport(
        loginHtml: kLoginForm,
        postResponse: resp('', status: 302, location: '/index.php',
            setCookies: <String>['sid=abc']),
      );
      final Wenku8Session s = sessionFor(t);
      await s.login('u', 'p');
      s.logout();
      expect(s.isAuthenticated, isFalse);
      expect(s.state, Wenku8AuthState.loggedOut);
      await s.login('u', 'p');
      s.invalidate();
      expect(s.state, Wenku8AuthState.sessionExpired);
      expect(s.isAuthenticated, isFalse);
      await s.login('u', 'p');
      s.switchHost('www.wenku8.com');
      expect(s.endpoints.authority, 'www.wenku8.com');
      expect(s.isAuthenticated, isFalse);
      s.switchHost('evil.example');
      expect(s.endpoints.authority, 'www.wenku8.com');
    });

    test('凭据 toString 永不明文', () {
      expect(const Wenku8Credentials('u', 'super-secret').toString(),
          isNot(contains('super-secret')));
      expect(const Wenku8Credentials('', 'x').isComplete, isFalse);
    });
  });

  group('个人书架与解析器守卫', () {
    test('未登录时 bookcase 不发请求，给明确说明', () async {
      final FakeTransport t = FakeTransport(loginHtml: kLoginForm);
      final HttpWenku8Source src = HttpWenku8Source(
        endpoints: Wenku8Endpoints.publicWeb(),
        transport: t,
        session: sessionFor(t),
      );
      final listing = await src.bookcase();
      expect(listing.books, isEmpty);
      expect(listing.note, contains('登录'));
      expect(t.getCount, 0);
    });

    test('列表 / 详情 / 章节遇关闭公告都报结构变化，不当空内容', () {
      const Wenku8WebPageParser parser = Wenku8WebPageParser();
      final list = parser.parseListing(kClosurePage);
      expect(list.issue, Wenku8ParseIssue.upstreamChanged);
      final detail = parser.parseDetail(kClosurePage, _fallback());
      expect(detail.issue, Wenku8ParseIssue.upstreamChanged);
      final chapter = parser.parseChapter(kClosurePage, '2312', '7');
      expect(chapter.issue, Wenku8ParseIssue.upstreamChanged);
      expect(Wenku8WebPageParser.noteFor(Wenku8ParseIssue.upstreamChanged),
          contains('公告'));
    });

    test('正常列表仍能提取书目', () {
      expect(const Wenku8WebPageParser().parseListing(kListingPage).value!.length, 2);
    });

    test('302 响应头能读到 location 与 set-cookie', () {
      final Wenku8RawResponse r = resp('',
          status: 302, location: '/index.php',
          setCookies: <String>['sid=abc']);
      expect(r.header('Location'), '/index.php');
      expect(r.setCookies.length, 1);
    });
  });
}

Wenku8Book _fallback() => const Wenku8Book(
      id: '2312',
      title: 'Demo',
      author: '',
      coverColor: Color(0xFF6E8CA8),
      tags: <String>['Wenku8'],
      latestChapter: '',
      updatedKey: '',
    );
