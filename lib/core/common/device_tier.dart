/// 对应原项目 `core/common/设备分级`：纯函数，不读平台通道。
///
/// 平台侧只需把内存 / 核心数 / 刷新率填进 [DeviceCapability]，
/// 分档结果交给 `MemoryBudget` 与 `PerformanceBudget.resolve()`；
/// 静态阶段拿不到设备信息时一律回落 [DeviceTier.unknown]（最保守档）。
enum DeviceTier { low, mid, high, unknown }

class DeviceCapability {
  const DeviceCapability({
    this.memoryMb,
    this.cores,
    this.refreshHz,
  });

  final int? memoryMb;
  final int? cores;
  final int? refreshHz;

  static const DeviceCapability unknown = DeviceCapability();

  bool get isComplete =>
      memoryMb != null && cores != null && refreshHz != null;
}

class DeviceTierResolver {
  const DeviceTierResolver._();

  static DeviceTier classify(DeviceCapability c) {
    if (!c.isComplete) return DeviceTier.unknown;
    final int mem = c.memoryMb!;
    final int cores = c.cores!;
    final int hz = c.refreshHz!;
    if (mem < 3072 || cores <= 4 || hz < 60) return DeviceTier.low;
    if (mem >= 6144 && cores >= 8 && hz >= 90) return DeviceTier.high;
    return DeviceTier.mid;
  }
}
