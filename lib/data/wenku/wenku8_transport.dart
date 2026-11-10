import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/model/wenku/wenku8_cookie.dart';
import '../../core/model/wenku/wenku8_endpoints.dart';
import '../../core/model/wenku/wenku8_form_encoding.dart';

/// 原始 HTTP 响应。保留 `bodyBytes` 而不是 `body`：Wenku8 网页是 GBK/GB18030，
/// `package:http` 的 `Response.body` 会按默认编码解码成乱码，正文解码必须由
/// `Wenku8BodyDecoder` 依据响应头 / meta charset 单独处理。
///
/// 第二十五轮新增 `setCookies`：302 登录响应里的认证 Cookie 必须原样交给
/// `Wenku8CookieStore`，不能只留一个合并后的 headers 字符串。
class Wenku8RawResponse {
  const Wenku8RawResponse({
    required this.statusCode,
    required this.bodyBytes,
    required this.headers,
    this.setCookies = const <String>[],
  });

  final int statusCode;
  final Uint8List bodyBytes;
  final Map<String, String> headers;
  final List<String> setCookies;

  String header(String name) {
    for (final MapEntry<String, String> e in headers.entries) {
      if (e.key.toLowerCase() == name.toLowerCase()) return e.value;
    }
    return '';
  }
}

/// 可注入的传输层：真机用 `HttpWenku8Transport`，规格单测用内存 Fake。
abstract interface class Wenku8Transport {
  Future<Wenku8RawResponse> get(Uri uri);
  void close();
}

/// 第二十五轮新增：**表单 POST 能力单独成接口**，不往 `Wenku8Transport`
/// 里加方法——那样会破坏既有 Fake 实现与 23 轮规格单测。
/// `HttpWenku8Transport` 同时实现两个接口，`Wenku8Session` 只依赖这两个窄契约。
abstract interface class Wenku8AuthTransport {
  Future<Wenku8RawResponse> postForm(
    Uri uri,
    Map<String, String> fields, {
    bool followRedirects = false,
  });
}

/// 真实 HTTP 传输（`package:http`，纯 Dart、跨平台，不引 `dart:io`）。
///
/// 合规护栏：
/// - **明确标识自己是第三方客户端**，不伪装浏览器 UA（伪装属于绕过访问限制）；
/// - 只走 `Wenku8Endpoints.owns()` 校验过的地址，不拼第三方中继；
/// - 登录 Cookie 只由来源站点下发的 Set-Cookie 产生，不伪造、不注入第三方凭据；
/// - 有超时上限，遇限流不疯狂重试（退避交给 `Wenku8Throttle`）。
class HttpWenku8Transport implements Wenku8Transport, Wenku8AuthTransport {
  HttpWenku8Transport({
    http.Client? client,
    required this.endpoints,
    Wenku8CookieStore? cookieStore,
    this.timeout = const Duration(seconds: 12),
  })  : _client = client ?? http.Client(),
        _cookieStore = cookieStore ?? InMemoryWenku8CookieStore();

  final http.Client _client;
  final Wenku8Endpoints endpoints;
  final Wenku8CookieStore _cookieStore;
  final Duration timeout;

  Wenku8CookieStore get cookieStore => _cookieStore;

  /// 公开、可识别的 UA；不模拟任何浏览器指纹。
  static const String userAgent =
      'LocalReader/1.0 (third-party Wenku8 reading client; non-official)';

  static const Map<String, String> _headers = <String, String>{
    'User-Agent': userAgent,
    'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9',
  };

  Map<String, String> _headersFor(Uri uri, {String? contentType}) {
    final Map<String, String> out = <String, String>{..._headers};
    final String cookie = _cookieStore.cookieHeader(uri);
    if (cookie.isNotEmpty) out['Cookie'] = cookie;
    if (contentType != null) out['Content-Type'] = contentType;
    return out;
  }

  @override
  Future<Wenku8RawResponse> get(Uri uri) async {
    // 护栏：拒绝任何不是由端点层构造的地址（防止中继 / 绕过）。
    if (!endpoints.owns(uri)) {
      throw ArgumentError('Wenku8Transport: 拒绝非端点层构造的地址 $uri');
    }
    final http.Response r = await _client
        .get(uri, headers: _headersFor(uri))
        .timeout(timeout);
    final List<String> setCookies = _setCookiesOf(r.headers);
    _cookieStore.absorb(setCookies);
    return Wenku8RawResponse(
      statusCode: r.statusCode,
      bodyBytes: r.bodyBytes,
      headers: Map<String, String>.unmodifiable(r.headers),
      setCookies: setCookies,
    );
  }

  /// POST 表单：`followRedirects = false` 才能看到 302 与 Location。
  /// 表单按页面 GBK 编码（见 `Wenku8FormEncoding`），不用 UTF-8 默认编码。
  @override
  Future<Wenku8RawResponse> postForm(
    Uri uri,
    Map<String, String> fields, {
    bool followRedirects = false,
  }) async {
    if (!endpoints.owns(uri)) {
      throw ArgumentError('Wenku8Transport: 拒绝非端点层构造的地址 $uri');
    }
    final http.Request request = http.Request('POST', uri)
      ..followRedirects = followRedirects
      ..maxRedirects = 0
      ..headers.addAll(_headersFor(
        uri,
        contentType: 'application/x-www-form-urlencoded',
      ))
      ..bodyBytes = utf8.encode(Wenku8FormEncoding.encode(fields));

    final http.StreamedResponse r =
        await _client.send(request).timeout(timeout);
    final Uint8List bytes = Uint8List.fromList(await r.stream.toBytes());
    final Map<String, String> headers =
        Map<String, String>.unmodifiable(r.headers);
    final List<String> setCookies = _setCookiesOf(headers);
    _cookieStore.absorb(setCookies);
    return Wenku8RawResponse(
      statusCode: r.statusCode,
      bodyBytes: bytes,
      headers: headers,
      setCookies: setCookies,
    );
  }

  /// `package:http` 可能把多个 Set-Cookie 合并成一条逗号相连的头；
  /// 解析器按属性段切分，不会被 Expires 里的逗号切坏。
  static List<String> _setCookiesOf(Map<String, String> headers) {
    for (final MapEntry<String, String> e in headers.entries) {
      if (e.key.toLowerCase() == 'set-cookie' && e.value.isNotEmpty) {
        return <String>[e.value];
      }
    }
    return const <String>[];
  }

  @override
  void close() => _client.close();
}

/// 传输层异常到产品状态的归类（不把「版权受限」当成普通网络错误）。
enum Wenku8TransportIssue { none, timeout, socket, rateLimited, serverError, denied }

Wenku8TransportIssue classifyTransport(int statusCode, {Object? error}) {
  if (error is TimeoutException) return Wenku8TransportIssue.timeout;
  if (statusCode == 429 || statusCode == 503) {
    return Wenku8TransportIssue.rateLimited;
  }
  if (statusCode >= 500) return Wenku8TransportIssue.serverError;
  if (statusCode == 401 || statusCode == 403) {
    return Wenku8TransportIssue.denied;
  }
  if (statusCode >= 400) return Wenku8TransportIssue.serverError;
  return Wenku8TransportIssue.none;
}
