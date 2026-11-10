import 'package:flutter/foundation.dart';

/// 来源域名（第二十五轮，来自用户提供的两个地址）。
///
/// 用户明确写「域名可能随项目版本不同，常见的是 wenku8.net 或 wenku8.com」，
/// 因此两者都在端点护栏白名单内，且可在应用内显式切换。
/// **不因为可切换就允许任意域名**：白名单仍是常量集合，自定义书源依旧禁用。
enum Wenku8Host { net, com }

@immutable
class Wenku8Hosts {
  const Wenku8Hosts._();

  static const Map<Wenku8Host, String> authorities = <Wenku8Host, String>{
    Wenku8Host.net: 'www.wenku8.net',
    Wenku8Host.com: 'www.wenku8.com',
  };

  static const Map<Wenku8Host, String> labels = <Wenku8Host, String>{
    Wenku8Host.net: 'wenku8.net',
    Wenku8Host.com: 'wenku8.com',
  };

  /// 端点层 `owns()` 的唯一白名单；不拼第三方中继 / 代理地址。
  static const Set<String> allowed = <String>{
    'www.wenku8.net',
    'www.wenku8.com',
  };

  static const Wenku8Host defaultHost = Wenku8Host.net;

  static String authorityOf(Wenku8Host h) => authorities[h]!;

  static Wenku8Host fromAuthority(String authority) =>
      authority == authorities[Wenku8Host.com]
          ? Wenku8Host.com
          : Wenku8Host.net;
}
