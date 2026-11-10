import 'device_tier.dart';

/// 对应原项目 `core/common/内存工具` 与 App.kt 的 Coil 内存裁剪。
///
/// 图片缓存是阅读器最容易涨到几百 MB 的地方：漫画页解码后尤其明显。
/// 这里只给出**预算**，真正的 `imageCache.maximumSizeBytes` 赋值在
/// `assembly/app_bootstrap.dart` 里做，业务层不碰 Flutter binding。
class MemoryBudget {
  const MemoryBudget({
    required this.maxImageCacheBytes,
    required this.maxImageCacheEntries,
    required this.pagePrefetchWindow,
  });

  /// 解码位图缓存上限（字节）。
  final int maxImageCacheBytes;

  /// 缓存条目上限；与字节上限同时生效，先到先裁。
  final int maxImageCacheEntries;

  /// 漫画 / PDF 连续页的预取窗口，越大越吃内存。
  final int pagePrefetchWindow;

  static const MemoryBudget conservative = MemoryBudget(
    maxImageCacheBytes: 48 * 1024 * 1024,
    maxImageCacheEntries: 80,
    pagePrefetchWindow: 2,
  );

  static MemoryBudget resolve(DeviceTier tier) => switch (tier) {
        DeviceTier.low || DeviceTier.unknown => conservative,
        DeviceTier.mid => const MemoryBudget(
            maxImageCacheBytes: 96 * 1024 * 1024,
            maxImageCacheEntries: 160,
            pagePrefetchWindow: 3,
          ),
        DeviceTier.high => const MemoryBudget(
            maxImageCacheBytes: 192 * 1024 * 1024,
            maxImageCacheEntries: 260,
            pagePrefetchWindow: 4,
          ),
      };
}
