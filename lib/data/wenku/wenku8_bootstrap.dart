import 'dart:async';

import 'demo_wenku8_source.dart';
import 'http_wenku8_source.dart';
import 'wenku8_cache.dart';
import '../../core/model/wenku/wenku8_endpoints.dart';
import '../../core/model/wenku/wenku8_cookie.dart';
import '../../core/model/wenku/wenku8_session.dart';
import '../../domain/repositories/wenku8_source.dart';
import 'wenku8_transport.dart';

/// 接入装配入口（第二十三轮解锁；第二十九轮接入云端缓存）。
///
/// `AppState.wenku8` 仍是唯一注入点：默认注入**真实** `HttpWenku8Source`，
/// `useDemo: true` 可切回确定性演示源（便于离线演示与回归）。
/// 纯本地模式锁定态由 AppState 提前返回，所以默认注入真实源**不会**在启动时
/// 产生任何请求；只有用户显式开启在线目录才会走网络。
class Wenku8Bootstrap {
  const Wenku8Bootstrap._();

  static Wenku8Cache? _activeCache;

  /// 应用内设置页 / 关于页读同一份缓存，不另建实例。
  static Wenku8Cache cacheFor([Wenku8Source? source]) {
    final Wenku8Cache? c = _activeCache;
    if (c != null) return c;
    return _activeCache = Wenku8Cache(MemoryWenku8CacheStore());
  }

  static Wenku8Source build({
    Wenku8Endpoints? endpoints,
    bool useDemo = false,
    Wenku8CookieStore? cookieStore,
    Wenku8CacheStore? cacheStore,
    Wenku8CachePolicy? cachePolicy,
  }) {
    if (useDemo) {
      _activeCache = Wenku8Cache(cacheStore ?? MemoryWenku8CacheStore(),
          policy: cachePolicy ?? const Wenku8CachePolicy());
      return const DemoWenku8Source();
    }
    final Wenku8Endpoints ep = endpoints ?? Wenku8Endpoints.publicWeb();
    // 第二十五轮：同一个 CookieStore 同时给传输层与会话层，
    // 保证「POST 下发的 Cookie」和「后续 GET 携带的 Cookie」是同一份。
    final Wenku8CookieStore store =
        cookieStore ?? InMemoryWenku8CookieStore();
    final HttpWenku8Transport transport = HttpWenku8Transport(
      endpoints: ep,
      cookieStore: store,
    );
    final Wenku8Session session = Wenku8Session(
      endpoints: ep,
      transport: transport,
      authTransport: transport,
      cookieStore: store,
    );
    // 第二十九轮：云端缓存策略可注入；默认内存存储，SQLite 存储由平台层提供。
    final Wenku8Cache cache = Wenku8Cache(
      cacheStore ?? MemoryWenku8CacheStore(),
      policy: cachePolicy ?? const Wenku8CachePolicy(),
    );
    _activeCache = cache;
    return HttpWenku8Source(
      endpoints: ep,
      transport: transport,
      session: session,
      cache: cache,
    );
  }

  /// 退出登录 / 关闭在线目录：清空缓存，不保留任何云端正文副本。
  static void clearCache() {
    final Wenku8Cache? c = _activeCache;
    if (c != null) unawaited(c.clear());
  }

  /// 装配层 dispose 时关闭底层 HTTP client，避免连接泄漏。
  static void dispose(Wenku8Source source) {
    if (source is HttpWenku8Source) {
      // 先清凭据 / Cookie，再关连接。
      source.session?.dispose();
      source.close();
    }
  }
}
