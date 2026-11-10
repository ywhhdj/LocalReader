import 'package:flutter/foundation.dart';

/// 第三十轮：性能与动效的**唯一模型**。
///
/// 用户要求设置里出现「帧率 / 设备检测 / 视觉效果 / 交互动效是否减少」，
/// 并且「沉浸阅读收起系统栏，默认关闭」。这四项如果散在页面里各自解释，
/// 就会重演前几轮反复修掉的「设了没反应」。所以：
///   * 偏好只写在 [PerformancePrefs]；
///   * 归一化只走 [PerformancePrefs.normalized]；
///   * 实际生效值只由 [PerformanceBudget.resolve] 裁决；
///   * 组件只读 `PerformanceScope.of(context)`，不自己拼一份。
enum FrameRateProfile { auto, power30, standard60, high120 }

enum VisualEffectLevel { full, reduced, minimal }

enum DeviceTier { unknown, low, mid, high }

@immutable
class DeviceCapability {
  const DeviceCapability({
    this.tier = DeviceTier.unknown,
    this.ramMB = 0,
    this.cores = 0,
    this.maxRefreshHz = 0,
    this.platformLabel = '',
  });

  final DeviceTier tier;
  final int ramMB;
  final int cores;
  final int maxRefreshHz;
  final String platformLabel;

  bool get isDetected => tier != DeviceTier.unknown;

  Map<String, Object> toMap() => <String, Object>{
        'tier': tier.name,
        'ramMB': ramMB,
        'cores': cores,
        'maxRefreshHz': maxRefreshHz,
        'platformLabel': platformLabel,
      };

  static DeviceCapability fromMap(Map<String, Object?> m) {
    DeviceTier tier = DeviceTier.unknown;
    final Object? rawTier = m['tier'];
    if (rawTier is String) {
      for (final DeviceTier t in DeviceTier.values) {
        if (t.name == rawTier) tier = t;
      }
    }
    int intOf(String key) {
      final Object? v = m[key];
      return v is int ? v : 0;
    }

    return DeviceCapability(
      tier: tier,
      ramMB: intOf('ramMB'),
      cores: intOf('cores'),
      maxRefreshHz: intOf('maxRefreshHz'),
      platformLabel: m['platformLabel'] is String ? m['platformLabel']! as String : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceCapability &&
      other.tier == tier &&
      other.ramMB == ramMB &&
      other.cores == cores &&
      other.maxRefreshHz == maxRefreshHz &&
      other.platformLabel == platformLabel;

  @override
  int get hashCode =>
      Object.hash(tier, ramMB, cores, maxRefreshHz, platformLabel);
}

/// 设备探测的窄接口。静态交付环境只挂 [StaticDeviceProbe]；
/// 接 SDK 后由 `AppServices.device` 提供三端实现，页面一行不改。
abstract interface class DeviceProbe {
  Future<DeviceCapability> detect();
}

class StaticDeviceProbe implements DeviceProbe {
  const StaticDeviceProbe();

  @override
  Future<DeviceCapability> detect() async => const DeviceCapability();
}

@immutable
class PerformancePrefs {
  const PerformancePrefs({
    this.frameRate = FrameRateProfile.auto,
    this.visualEffects = VisualEffectLevel.full,
    this.reduceInteractionMotion = false,
    this.immersiveReading = false,
    this.autoDegradeByDevice = true,
    this.device = const DeviceCapability(),
  });

  final FrameRateProfile frameRate;
  final VisualEffectLevel visualEffects;

  /// 「交互动效是否减少」：与全局 `motion` 不是同一个开关。
  /// 全局动效关闭时它被强制置 true；单独开启它则停掉悬浮球旋转、
  /// 贴边过渡、卡片渐隐这类**交互反馈**，但保留必要的状态变化。
  final bool reduceInteractionMotion;

  /// 沉浸阅读：阅读时收起系统栏。默认关闭，且只在阅读页生效。
  final bool immersiveReading;

  /// 低端设备自动降级（真实档位由设备检测给出，静态阶段为 unknown）。
  final bool autoDegradeByDevice;
  final DeviceCapability device;

  PerformancePrefs copyWith({
    FrameRateProfile? frameRate,
    VisualEffectLevel? visualEffects,
    bool? reduceInteractionMotion,
    bool? immersiveReading,
    bool? autoDegradeByDevice,
    DeviceCapability? device,
  }) =>
      PerformancePrefs(
        frameRate: frameRate ?? this.frameRate,
        visualEffects: visualEffects ?? this.visualEffects,
        reduceInteractionMotion:
            reduceInteractionMotion ?? this.reduceInteractionMotion,
        immersiveReading: immersiveReading ?? this.immersiveReading,
        autoDegradeByDevice: autoDegradeByDevice ?? this.autoDegradeByDevice,
        device: device ?? this.device,
      );

  /// 归一化裁决点：关掉全局界面动效 → 交互动效必然减少、视觉必然最低档。
  /// 页面不自己解释这条规则，避免出现「设置说关了、卡片还在渐隐」。
  PerformancePrefs normalized(bool globalMotion) => globalMotion
      ? this
      : copyWith(
          reduceInteractionMotion: true,
          visualEffects: VisualEffectLevel.minimal,
        );

  Map<String, Object> toMap() => <String, Object>{
        'frameRate': frameRate.name,
        'visualEffects': visualEffects.name,
        'reduceInteractionMotion': reduceInteractionMotion,
        'immersiveReading': immersiveReading,
        'autoDegradeByDevice': autoDegradeByDevice,
        'device': device.toMap(),
      };

  static PerformancePrefs fromMap(Map<String, Object?> m) {
    T enumOf<T>(String key, List<T> values, T fallback) {
      final Object? v = m[key];
      if (v is String) {
        for (final T item in values) {
          if ((item as Enum).name == v) return item;
        }
      }
      return fallback;
    }

    bool flag(String key, bool fallback) {
      final Object? v = m[key];
      return v is bool ? v : fallback;
    }

    final Object? rawDevice = m['device'];
    return PerformancePrefs(
      frameRate: enumOf<FrameRateProfile>(
          'frameRate', FrameRateProfile.values, FrameRateProfile.auto),
      visualEffects: enumOf<VisualEffectLevel>(
          'visualEffects', VisualEffectLevel.values, VisualEffectLevel.full),
      reduceInteractionMotion: flag('reduceInteractionMotion', false),
      immersiveReading: flag('immersiveReading', false),
      autoDegradeByDevice: flag('autoDegradeByDevice', true),
      device: rawDevice is Map
          ? DeviceCapability.fromMap(Map<String, Object?>.from(rawDevice))
          : const DeviceCapability(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PerformancePrefs &&
      other.frameRate == frameRate &&
      other.visualEffects == visualEffects &&
      other.reduceInteractionMotion == reduceInteractionMotion &&
      other.immersiveReading == immersiveReading &&
      other.autoDegradeByDevice == autoDegradeByDevice &&
      other.device == device;

  @override
  int get hashCode => Object.hash(frameRate, visualEffects,
      reduceInteractionMotion, immersiveReading, autoDegradeByDevice, device);
}

/// 真正生效的一组值。所有视觉组件与动画只认它，不直接读偏好。
@immutable
class PerformanceBudget {
  const PerformanceBudget({
    required this.frameRate,
    required this.visualEffects,
    required this.reduceMotion,
    required this.immersiveReading,
    required this.autoDegraded,
    required this.device,
  });

  final FrameRateProfile frameRate;
  final VisualEffectLevel visualEffects;
  final bool reduceMotion;
  final bool immersiveReading;
  final bool autoDegraded;
  final DeviceCapability device;

  /// 最低档直接**跳过 BackdropFilter**（GPU 模糊是整页最贵的一笔）。
  bool get useBackdropFilter => visualEffects != VisualEffectLevel.minimal;

  double get blurSigma {
    if (visualEffects == VisualEffectLevel.full) return 18;
    if (visualEffects == VisualEffectLevel.reduced) return 6;
    return 0;
  }

  bool get useShadows => visualEffects == VisualEffectLevel.full;
  bool get useHighlightBorder => visualEffects == VisualEffectLevel.full;

  /// 减少交互动效时不准起无限 Ticker（旋转封面等），是真省电不是只改透明度。
  bool get allowInfiniteAnimation => !reduceMotion;

  /// 用贴边动画时长而不是帧率数字驱动 UI；实际刷新率由系统调度。
  Duration get snapDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

  int get targetFps {
    if (frameRate == FrameRateProfile.power30) return 30;
    if (frameRate == FrameRateProfile.high120) return 120;
    if (frameRate == FrameRateProfile.standard60) return 60;
    return device.maxRefreshHz > 0 ? device.maxRefreshHz : 60;
  }

  static PerformanceBudget resolve(PerformancePrefs prefs, bool globalMotion) {
    final PerformancePrefs p = prefs.normalized(globalMotion);
    bool degraded = false;
    VisualEffectLevel effects = p.visualEffects;
    FrameRateProfile rate = p.frameRate;
    if (p.autoDegradeByDevice && p.device.tier == DeviceTier.low) {
      effects = VisualEffectLevel.minimal;
      rate = FrameRateProfile.power30;
      degraded = true;
    }
    return PerformanceBudget(
      frameRate: rate,
      visualEffects: effects,
      reduceMotion: p.reduceInteractionMotion || !globalMotion,
      immersiveReading: p.immersiveReading,
      autoDegraded: degraded,
      device: p.device,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PerformanceBudget &&
      other.frameRate == frameRate &&
      other.visualEffects == visualEffects &&
      other.reduceMotion == reduceMotion &&
      other.immersiveReading == immersiveReading &&
      other.autoDegraded == autoDegraded &&
      other.device == device;

  @override
  int get hashCode => Object.hash(frameRate, visualEffects, reduceMotion,
      immersiveReading, autoDegraded, device);
}
