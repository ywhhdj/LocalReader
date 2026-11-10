import 'dart:math';

/// 限流与退避（第二十三轮）。
///
/// 参考仓库 README：第三方服务可能变更、限流或不可用；公开客户端资料也提示
/// 「遇大量失败请降低调用频率」。所以这里不写「失败就立刻重试三次」，而是：
/// - 任意两次请求之间有最小间隔（默认 1.5s）；
/// - 429 / 503 优先尊重 `Retry-After`；
/// - 退避指数增长 + 抖动，最多 2 次；
/// - **遇版权受限 / 验证质询一律不重试**（见 `shouldRetry` 的调用方判定）。
class Wenku8Throttle {
  Wenku8Throttle({
    this.minInterval = const Duration(milliseconds: 1500),
    this.maxRetries = 2,
    this.zeroBackoff = false,
    Random? random,
  }) : _random = random ?? Random();

  final Duration minInterval;
  final int maxRetries;

  /// 规格单测用：跳过真实等待，但仍验证重试次数与状态映射。
  final bool zeroBackoff;
  final Random _random;
  DateTime? _lastRequest;

  /// 真正发出请求前登记一次，供 `pendingDelay()` 计算最小间隔。
  void markRequest({DateTime? now}) => _lastRequest = now ?? DateTime.now();

  Duration pendingDelay({DateTime? now}) {
    final DateTime? last = _lastRequest;
    if (last == null) return Duration.zero;
    final Duration elapsed = (now ?? DateTime.now()).difference(last);
    final Duration left = minInterval - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// 第 attempt 次重试（0 起）的等待时长；带 ±20% 抖动避免同步重试风暴。
  Duration backoffFor(int attempt, {Duration? retryAfter}) {
    if (zeroBackoff) return Duration.zero;
    if (retryAfter != null && retryAfter > Duration.zero) {
      return retryAfter > const Duration(seconds: 30)
          ? const Duration(seconds: 30)
          : retryAfter;
    }
    final int seconds = 1 << (attempt + 1); // 2, 4, 8...
    final double jitter = 0.8 + _random.nextDouble() * 0.4;
    return Duration(milliseconds: (seconds * 1000 * jitter).round());
  }

  bool get canRetry => maxRetries > 0;

  static Duration? parseRetryAfter(String value) {
    final int? secs = int.tryParse(value.trim());
    if (secs != null && secs >= 0) return Duration(seconds: secs);
    // 不实现 HTTP-date 解析：静态阶段无需，明确返回 null 交给默认退避。
    return null;
  }
}
