import 'package:flutter/foundation.dart';

/// 登录会话 Cookie（第二十五轮）。
///
/// 与用户示例的 `PersistCookieJar + path_provider` 取舍：**保持 `package:http`
/// 单一传输层，不引入 dio 全家桶与平台文件插件**。Cookie 存取收口成这个窄接口，
/// 默认内存实现；接 SDK 后可注入 `SharedPreferences` / `PersistCookieJar` 的适配实现，
/// 页面、状态、会话逻辑一行都不用改。
///
/// Cookie 属于凭据：不写日志、不进反馈；`Wenku8Compliance.redact()` 会命中
/// `set-cookie` / `cookie` 键。密码本身从不写入任何 store。
@immutable
class Wenku8Cookie {
  const Wenku8Cookie(this.name, this.value);

  final String name;
  final String value;

  @override
  String toString() => '$name=[凭据已移除]';
}

/// `Set-Cookie` 解析。**只取 name=value**，忽略 Expires / Path / Domain 等属性；
/// 这样即便 `package:http` 把多个 Set-Cookie 合并成一条带逗号的字符串，
/// 也不会被 `Expires=Wed, 09 Jun 2027` 里的逗号切坏。
@immutable
class Wenku8CookieCodec {
  const Wenku8CookieCodec._();

  static const Set<String> attributes = <String>{
    'expires', 'max-age', 'domain', 'path', 'secure', 'httponly',
    'samesite', 'priority', 'partitioned', 'version', 'comment',
  };

  static List<Wenku8Cookie> parse(String raw) {
    final List<Wenku8Cookie> out = <Wenku8Cookie>[];
    final Set<String> seen = <String>{};
    for (final String segment in raw.split(';')) {
      final int eq = segment.indexOf('=');
      if (eq <= 0) continue;
      // 合并头里前一段的最后一个属性可能和下一个 cookie 名挤在同一段，
      // 只取逗号之后的部分作为候选名。
      final String head = segment.substring(0, eq);
      final int comma = head.lastIndexOf(',');
      final String name = (comma >= 0 ? head.substring(comma + 1) : head).trim();
      if (name.isEmpty || attributes.contains(name.toLowerCase())) continue;
      if (!RegExp(r"^[A-Za-z0-9_!#$%&'*+\-.^`|~]+$").hasMatch(name)) continue;
      String value = segment.substring(eq + 1).trim();
      final int nextComma = value.indexOf(',');
      if (nextComma >= 0) value = value.substring(0, nextComma).trim();
      if (seen.add(name)) out.add(Wenku8Cookie(name, value));
    }
    return List<Wenku8Cookie>.unmodifiable(out);
  }

  static List<Wenku8Cookie> parseAll(Iterable<String> raws) {
    final Map<String, Wenku8Cookie> byName = <String, Wenku8Cookie>{};
    for (final String raw in raws) {
      for (final Wenku8Cookie c in parse(raw)) {
        byName[c.name] = c;
      }
    }
    return List<Wenku8Cookie>.unmodifiable(byName.values);
  }
}

abstract interface class Wenku8CookieStore {
  /// 吸收响应里的 Set-Cookie（原始头，可多条）。
  void absorb(Iterable<String> setCookieHeaders);

  /// 生成后续请求的 Cookie 头；空串表示不带。
  String cookieHeader(Uri uri);

  /// 登录成功后显式登记「哪些 Cookie 构成认证态」。
  /// 修掉用户示例里「Cookie 非空就算已登录」的缺陷：匿名 Cookie 也会被误判。
  void markAuthenticated(Iterable<String> names);

  bool get isAuthenticated;

  /// 退出 / 会话失效：Cookie 与认证标记一起清空。
  void clear();
}

/// 默认内存实现：重启后需重新登录。
/// 不写文件、不依赖 path_provider，三端骨架无需改动。
class InMemoryWenku8CookieStore implements Wenku8CookieStore {
  InMemoryWenku8CookieStore();

  final Map<String, Wenku8Cookie> _cookies = <String, Wenku8Cookie>{};
  final Set<String> _authNames = <String>{};

  @override
  void absorb(Iterable<String> setCookieHeaders) {
    for (final Wenku8Cookie c in Wenku8CookieCodec.parseAll(setCookieHeaders)) {
      _cookies[c.name] = c;
    }
  }

  @override
  String cookieHeader(Uri uri) => _cookies.values
      .map((Wenku8Cookie c) => '${c.name}=${c.value}')
      .join('; ');

  @override
  void markAuthenticated(Iterable<String> names) {
    _authNames
      ..clear()
      ..addAll(names.where((String n) => _cookies.containsKey(n)));
  }

  @override
  bool get isAuthenticated =>
      _authNames.isNotEmpty && _authNames.every((String n) => _cookies.containsKey(n));

  @override
  void clear() {
    _cookies.clear();
    _authNames.clear();
  }

  int get cookieCount => _cookies.length;
}
