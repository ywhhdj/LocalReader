import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/wenku/wenku8_body_decoder.dart';
import 'package:local_reader/core/wenku/wenku8_throttle.dart';
import 'package:local_reader/core/wenku/wenku8_transport.dart';

void main() {
  group('GBK / UTF-8 正文解码', () {
    const DefaultWenku8BodyDecoder dec = DefaultWenku8BodyDecoder();

    test('响应头声明 GBK 时不乱码', () {
      final Uint8List bytes = Uint8List.fromList(gbk.encode('轻小说文库'));
      expect(dec.decode(bytes, 'text/html; charset=GBK', ''), '轻小说文库');
    });

    test('声明 gb2312 / gb18030 也走 GBK 解码器', () {
      final Uint8List bytes = Uint8List.fromList(gbk.encode('目录'));
      expect(dec.decode(bytes, 'text/html; charset=gb2312', ''), '目录');
      expect(dec.decode(bytes, 'text/html; charset=gb18030', ''), '目录');
    });

    test('meta charset 声明也能识别', () {
      final Uint8List bytes = Uint8List.fromList(gbk.encode('正文'));
      expect(dec.decode(bytes, '', '<meta charset="gbk">'), '正文');
    });

    test('UTF-8 页面按 utf8 解码', () {
      final Uint8List bytes = Uint8List.fromList(utf8.encode('Wenku8 目录'));
      expect(dec.decode(bytes, 'text/html; charset=utf-8', ''), 'Wenku8 目录');
    });

    test('没有声明时默认 GBK（站点常见口径）', () {
      final Uint8List bytes = Uint8List.fromList(gbk.encode('默认编码'));
      expect(dec.decode(bytes, '', ''), '默认编码');
    });

    test('probeAscii 只取前 2048 字节', () {
      final Uint8List bytes = Uint8List.fromList(List<int>.filled(5000, 65));
      expect(probeAscii(bytes).length, 2048);
    });
  });

  group('限流退避', () {
    test('Retry-After 秒数被尊重，且夹在 30 秒内', () {
      final Wenku8Throttle t = Wenku8Throttle();
      expect(Wenku8Throttle.parseRetryAfter('20'), const Duration(seconds: 20));
      expect(t.backoffFor(0, retryAfter: const Duration(seconds: 20)),
          const Duration(seconds: 20));
      expect(t.backoffFor(0, retryAfter: const Duration(seconds: 999)),
          const Duration(seconds: 30));
      expect(Wenku8Throttle.parseRetryAfter('not-a-date'), isNull);
    });

    test('退避随重试次数增长', () {
      final Wenku8Throttle t = Wenku8Throttle();
      expect(t.backoffFor(1).inMilliseconds,
          greaterThan(t.backoffFor(0).inMilliseconds));
    });

    test('zeroBackoff 供规格单测跳过真实等待', () {
      expect(Wenku8Throttle(zeroBackoff: true).backoffFor(0), Duration.zero);
    });

    test('markRequest 后 pendingDelay 反映最小间隔', () {
      final Wenku8Throttle t =
          Wenku8Throttle(minInterval: const Duration(seconds: 2));
      expect(t.pendingDelay(), Duration.zero);
      final DateTime now = DateTime.utc(2026, 11, 9, 12);
      t.markRequest(now: now);
      expect(t.pendingDelay(now: now.add(const Duration(milliseconds: 500))),
          const Duration(milliseconds: 1500));
      expect(t.pendingDelay(now: now.add(const Duration(seconds: 3))),
          Duration.zero);
    });
  });

  group('传输层状态归类与 UA', () {
    test('状态码映射到传输问题', () {
      expect(classifyTransport(200), Wenku8TransportIssue.none);
      expect(classifyTransport(429), Wenku8TransportIssue.rateLimited);
      expect(classifyTransport(503), Wenku8TransportIssue.rateLimited);
      expect(classifyTransport(500), Wenku8TransportIssue.serverError);
      expect(classifyTransport(403), Wenku8TransportIssue.denied);
      expect(classifyTransport(404), Wenku8TransportIssue.serverError);
    });

    test('UA 明确标识第三方客户端，不伪装浏览器', () {
      expect(HttpWenku8Transport.userAgent, contains('third-party'));
      expect(HttpWenku8Transport.userAgent, isNot(contains('Mozilla')));
      expect(HttpWenku8Transport.userAgent, isNot(contains('Chrome')));
    });
  });
}
