import 'package:flutter/foundation.dart';

/// 来源域名
enum Wenku8Host { net, com }

@immutable
class Wenku8Hosts {
  const Wenku8Hosts._();

  static const Map<Wenku8Host, String> authorities = <Wenku8Host, String>{
    Wenku8Host.net: 'www.wenku8.net',
    Wenku8Host.com: 'www.wenku8.com',
  };

  static const Map<Wenku8Host, String> labels = <Wenku8Host, String>{
    Wenku8Host.net: 'Net',
    Wenku8Host.com: 'Com',
  };

  /// 端点层 `owns()` 的唯一白名单
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
