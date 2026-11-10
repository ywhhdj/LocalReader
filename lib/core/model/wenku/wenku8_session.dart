import 'package:flutter/foundation.dart';

import '../../../data/wenku/wenku8_body_decoder.dart';
import 'wenku8_cookie.dart';
import 'wenku8_endpoints.dart';
import 'wenku8_form_encoding.dart';
import 'wenku8_hosts.dart';
import 'wenku8_login_inspection.dart';
import '../../../data/wenku/wenku8_transport.dart';

/// 认证状态与连接状态**分开**：`Wenku8Status` 管「目录能不能读」，
/// 这里管「登录会话在不在」。两者不互相覆盖，页面不会把「站点关闭」误报成「密码错误」。
enum Wenku8AuthState {
  loggedOut,
  inspecting,
  submitting,
  loggedIn,
  failed,
  sessionExpired,
  sourceClosed,
  upstreamChanged,
  challenge,
  unavailable,
}

enum Wenku8LoginResult {
  ok,
  emptyFields,
  noSession,
  sourceClosed,
  noForm,
  missingFields,
  challenge,
  upstreamChanged,
  rejected,
  network,
}

@immutable
class Wenku8LoginOutcome {
  const Wenku8LoginOutcome(this.result, {this.note = ''});

  final Wenku8LoginResult result;
  final String note;

  bool get isSuccess => result == Wenku8LoginResult.ok;
}

/// 凭据只存在内存，且 `toString()` 永不明文。
@immutable
class Wenku8Credentials {
  const Wenku8Credentials(this.username, this.password);

  final String username;
  final String password;

  bool get isComplete => username.trim().isNotEmpty && password.isNotEmpty;

  @override
  String toString() => 'Wenku8Credentials([凭据已移除])';
}

/// 表单登录 + Cookie 会话（第二十五轮）。
///
/// 流程按用户提供的清单：GET `login.php` 看表单 → POST 表单（302 不自动跟随）
/// → 依据 Location 与认证 Cookie 判成功 → 后续请求自动携带 Cookie。
/// 差异（相对用户给的 dio 示例）见 `docs/Wenku8网页表单登录与内容接入.md`：
/// 用 `package:http` 单传输层、`Wenku8CookieStore` 可注入、表单按 GBK 编码、
/// 「Cookie 非空」不算已登录、凭据不落盘、提交前先检查页面是否为公告页。
class Wenku8Session extends ChangeNotifier {
  Wenku8Session({
    required Wenku8Endpoints endpoints,
    required Wenku8Transport transport,
    required Wenku8AuthTransport authTransport,
    Wenku8CookieStore? cookieStore,
    Wenku8BodyDecoder? decoder,
    Wenku8LoginPageInspector? inspector,
  })  : _endpoints = endpoints,
        _transport = transport,
        _authTransport = authTransport,
        _store = cookieStore ?? InMemoryWenku8CookieStore(),
        _decoder = decoder ?? const DefaultWenku8BodyDecoder(),
        _inspector = inspector ?? const Wenku8LoginPageInspector();

  Wenku8Endpoints _endpoints;
  final Wenku8Transport _transport;
  final Wenku8AuthTransport _authTransport;
  final Wenku8CookieStore _store;
  final Wenku8BodyDecoder _decoder;
  final Wenku8LoginPageInspector _inspector;

  Wenku8AuthState _state = Wenku8AuthState.loggedOut;
  Wenku8Credentials? _credentials;
  String _note = '';

  Wenku8Endpoints get endpoints => _endpoints;
  Wenku8AuthState get state => _state;
  String get note => _note;
  bool get isAuthenticated =>
      _state == Wenku8AuthState.loggedIn && _store.isAuthenticated;
  Wenku8CookieStore get cookieStore => _store;

  /// 显式切换来源域名（用户说明两个域名都可能用到）。切换即退出登录态，
  /// 避免把 .net 的 Cookie 带到 .com，或反过来。
  void switchHost(String authority) {
    if (!Wenku8Hosts.allowed.contains(authority)) return;
    if (_endpoints.authority == authority) return;
    _endpoints = _endpoints.withAuthority(authority);
    _store.clear();
    _credentials = null;
    _state = Wenku8AuthState.loggedOut;
    _note = '';
    notifyListeners();
  }

  /// 登录。**任何失败路径都不会把密码写进日志或异常文本**。
  Future<Wenku8LoginOutcome> login(String username, String password) async {
    final Wenku8Credentials credentials =
        Wenku8Credentials(username.trim(), password);
    if (!credentials.isComplete) {
      return _finish(const Wenku8LoginOutcome(
        Wenku8LoginResult.emptyFields,
        note: '用户名或密码为空，未发出任何请求。',
      ), Wenku8AuthState.failed);
    }

    _state = Wenku8AuthState.inspecting;
    _note = '正在检查来源登录页…';
    notifyListeners();

    // ① 先看页面有没有可提交的表单。命中站点关闭公告 / 验证页直接停。
    final Wenku8RawResponse page;
    try {
      page = await _transport.get(_endpoints.login());
    } catch (_) {
      return _finish(const Wenku8LoginOutcome(
        Wenku8LoginResult.network,
        note: '无法读取来源登录页，请稍后再试；未提交账号密码。',
      ), Wenku8AuthState.unavailable);
    }
    final String html = _decoder.decode(
      page.bodyBytes, page.header('content-type'), probeAscii(page.bodyBytes));
    final Wenku8LoginInspection inspection = _inspector.inspect(html);
    if (!inspection.canSubmit) {
      switch (inspection.issue) {
        case Wenku8LoginPageIssue.sourceClosed:
          return _finish(const Wenku8LoginOutcome(
            Wenku8LoginResult.sourceClosed,
            note: '来源页面返回站点关闭或公告内容，没有可用的登录表单；未提交账号密码。',
          ), Wenku8AuthState.sourceClosed);
        case Wenku8LoginPageIssue.challenge:
          return _finish(const Wenku8LoginOutcome(
            Wenku8LoginResult.challenge,
            note: '来源要求访问验证，请到官网完成后再试；本应用不绕过验证。',
          ), Wenku8AuthState.challenge);
        case Wenku8LoginPageIssue.noForm:
        case Wenku8LoginPageIssue.missingFields:
        case Wenku8LoginPageIssue.empty:
          return _finish(const Wenku8LoginOutcome(
            Wenku8LoginResult.noForm,
            note: '来源登录页结构与预期不符，需核对表单字段；未提交账号密码。',
          ), Wenku8AuthState.upstreamChanged);
        case Wenku8LoginPageIssue.ok:
          break;
      }
    }

    // ② POST 表单，302 不自动跟随（用户示例强调的关键点）。
    _state = Wenku8AuthState.submitting;
    _note = '正在提交登录表单…';
    notifyListeners();
    final Wenku8RawResponse response;
    try {
      response = await _authTransport.postForm(
        _endpoints.login(),
        Wenku8FormEncoding.loginFields(credentials.username, credentials.password),
        followRedirects: false,
      );
    } catch (_) {
      _credentials = null;
      return _finish(const Wenku8LoginOutcome(
        Wenku8LoginResult.network,
        note: '登录请求未完成，请检查网络后重试。',
      ), Wenku8AuthState.unavailable);
    }

    _store.absorb(response.setCookies);
    final String location = response.header('location');
    final bool redirected = _isSuccessfulRedirect(response.statusCode, location);
    // ③ 「Cookie 非空」不算成功：匿名 Cookie 也会被误判。必须同时有
    //    成功重定向 + 这一轮响应确实下发了 Cookie。
    if (!redirected || response.setCookies.isEmpty) {
      _credentials = null;
      return _finish(const Wenku8LoginOutcome(
        Wenku8LoginResult.rejected,
        note: '登录未完成，请确认账号与来源站点状态；页面异常不会被当作密码错误。',
      ), Wenku8AuthState.failed);
    }

    _store.markAuthenticated(
      Wenku8CookieCodec.parseAll(response.setCookies)
          .map((Wenku8Cookie c) => c.name),
    );
    _credentials = null; // 密码只在这次调用期间存在，成功后立即丢弃。
    return _finish(const Wenku8LoginOutcome(
      Wenku8LoginResult.ok,
      note: '已登录；后续请求会携带来源下发的会话 Cookie。',
    ), Wenku8AuthState.loggedIn);
  }

  static bool _isSuccessfulRedirect(int statusCode, String location) {
    if (statusCode != 301 && statusCode != 302 && statusCode != 303) return false;
    if (location.isEmpty) return false;
    final String lower = location.toLowerCase();
    // 又跳回登录页 = 登录失败，不能算成功。
    return !lower.contains('login') && !lower.contains('logon');
  }

  /// 401 / 403 / 书架页缺少登录标记时调用：Cookie 与认证态一起失效。
  void invalidate() {
    _store.clear();
    _credentials = null;
    _state = Wenku8AuthState.sessionExpired;
    _note = '登录态已失效，请重新登录。';
    notifyListeners();
  }

  void logout() {
    _store.clear();
    _credentials = null;
    _state = Wenku8AuthState.loggedOut;
    _note = '';
    notifyListeners();
  }

  Wenku8LoginOutcome _finish(Wenku8LoginOutcome outcome, Wenku8AuthState next) {
    _state = next;
    _note = outcome.note;
    notifyListeners();
    return outcome;
  }

  @override
  void dispose() {
    // dispose 也清一次，避免凭据 / Cookie 残留在内存里比会话更久。
    _store.clear();
    _credentials = null;
    super.dispose();
  }
}
