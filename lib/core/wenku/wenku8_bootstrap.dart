import 'demo_wenku8_source.dart';
import 'http_wenku8_source.dart';
import 'wenku8_endpoints.dart';
import 'wenku8_cookie.dart';
import 'wenku8_session.dart';
import 'wenku8_source.dart';
import 'wenku8_transport.dart';

/// 接入装配入口（第二十三轮解锁）。
///
/// `AppState.wenku8` 仍是唯一注入点：默认注入**真实** `HttpWenku8Source`，
/// `useDemo: true` 可切回确定性演示源（便于离线演示与回归）。
/// 纯本地模式锁定态由 AppState 提前返回，所以默认注入真实源**不会**在启动时
/// 产生任何请求；只有用户显式开启在线目录才会走网络。
class Wenku8Bootstrap {
  const Wenku8Bootstrap._();

  static Wenku8Source build({
    Wenku8Endpoints? endpoints,
    bool useDemo = false,
    Wenku8CookieStore? cookieStore,
  }) {
    if (useDemo) return const DemoWenku8Source();
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
    return HttpWenku8Source(
      endpoints: ep,
      transport: transport,
      session: session,
    );
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
