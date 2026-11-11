// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖
// 合并状态 E13：已落入工程路径 lib/core/network/network_policy.dart；同名类型已隔离；未编译 / 未运行 / 未下载依赖。
// 设计源：scaffold/network_policy.dart（交付包内保留，作为规格基线）
// 建议落点：lib/core/network/network_policy.dart
// 对应需求：R1（默认开网络）、R7（云端异步加载）
// 对齐：docs/05 §5.4「云端异步加载」、PLAN.md P0
// 纯 Dart，无 Flutter / 第三方依赖；@immutable 语义用注释表达，避免引入 foundation。

/// 云端列表状态（docs/05 §5.4）：ok + 六种互斥态。
/// 注意 offline 是「纯本地总开关开启 / 设备无网」，不是「站点停服」。
enum CloudFeedState {
  ok,
  loading,
  empty,
  rateLimited,
  unavailable,
  upstreamChanged,
  offline,
}

/// 站点提示页（含「本站正式关闭」类公告）只是提示，不代表停服。
/// 用户 2026-11-10 确认：网站仍在运行，登录 / 注册 / 维护正常。
enum NoticeKind { none, notice, challenge, restricted }

/// 轻量取消令牌：切 tab、退出页面、输入新关键词时 cancel 旧 Future，
/// 迟到响应必须丢弃，不得覆盖新结果或已有缓存。
class RequestToken {
  RequestToken(this.id);

  final String id;
  bool _cancelled = false;
  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  /// 只有「未取消且仍属于当前请求」的结果才允许回填。
  bool accepts(String resultTokenId) =>
      !_cancelled && resultTokenId == id;
}

/// 唯一联网裁决点（生产里由 AppSettings.onlineEnabled 注入）。
/// 默认开网络 ≠ 启动即请求：首帧只渲染缓存 / 骨架，页面可见后才异步刷新。
class NetworkPolicy {
  const NetworkPolicy({
    this.onlineEnabled = true,
    this.pureLocal = false,
    this.fetchOnLaunch = false,
    this.autoLogin = false,
    this.staleWhileRevalidate = true,
    this.failureFallsBackToEmpty = true,
    this.coverConcurrency = 4,
  });

  /// R1：默认开启。生产环境由 AppSettings.normalized() 供给。
  final bool onlineEnabled;
  final bool pureLocal;

  /// 首次启动不预取、不自动登录（P0 明确要求）。
  final bool fetchOnLaunch;
  final bool autoLogin;

  /// 先读 Wenku8Cache，再异步 refreshWenku8()。
  final bool staleWhileRevalidate;
  final bool failureFallsBackToEmpty;
  final int coverConcurrency;

  bool get networkingAllowed => onlineEnabled && !pureLocal;

  /// 纯本地总开关开启时全应用零请求（docs/00 §0.5 第 2 条）。
  bool shouldFetch({required bool pageVisible}) =>
      networkingAllowed && pageVisible && !fetchOnLaunch;

  /// 提示页 / 质询页 / 版权受限页一律不当书目、不当登录结果，
  /// 最重要的是**不得映射成 offline / unavailable**（站点仍在运行）。
  CloudFeedState resolve({
    required NoticeKind notice,
    required bool hasCachedData,
    required CloudFeedState transportState,
  }) {
    if (!networkingAllowed) return CloudFeedState.offline;
    switch (notice) {
      case NoticeKind.notice:
        // 提示页：按「非书目」处理，保留缓存，继续按实际公开页面适配。
        return hasCachedData ? CloudFeedState.ok : CloudFeedState.empty;
      case NoticeKind.challenge:
      case NoticeKind.restricted:
        // 验证质询 / 版权受限立即停止并引导官网，不重试绕过。
        return CloudFeedState.unavailable;
      case NoticeKind.none:
        break;
    }
    if (transportState == CloudFeedState.rateLimited) {
      return CloudFeedState.rateLimited; // 尊重 Retry-After 退避
    }
    if (transportState == CloudFeedState.upstreamChanged) {
      return CloudFeedState.upstreamChanged; // 「来源结构已变化」
    }
    if (transportState == CloudFeedState.unavailable) {
      // 失败不覆盖已有缓存：有缓存就继续展示，无缓存才落空态。
      return hasCachedData
          ? CloudFeedState.ok
          : (failureFallsBackToEmpty
              ? CloudFeedState.empty
              : CloudFeedState.unavailable);
    }
    return transportState;
  }
}

/// 一次云端刷新的静态描述，便于页面层做占位与竞态控制。
class CloudRefreshSpec {
  const CloudRefreshSpec({
    required this.token,
    required this.state,
    this.showSkeleton = false,
    this.showRetry = false,
  });

  final RequestToken token;
  final CloudFeedState state;
  final bool showSkeleton;
  final bool showRetry;

  factory CloudRefreshSpec.of(CloudFeedState state, RequestToken token) =>
      CloudRefreshSpec(
        token: token,
        state: state,
        showSkeleton: state == CloudFeedState.loading,
        showRetry: state == CloudFeedState.rateLimited ||
            state == CloudFeedState.unavailable ||
            state == CloudFeedState.upstreamChanged,
      );
}
