import 'package:flutter/services.dart';

/// 沉浸阅读：阅读时收起系统状态栏 / 导航栏。默认关闭。
///
/// 这是 Flutter 框架自带的 SystemChrome，不是三端原生插件；
/// 但真机上不同 OEM / 鸿蒙的表现仍需验证，静态交付只登记接口与行为，
/// 不声称「所有设备已生效」。
class ImmersiveModeController {
  const ImmersiveModeController();

  Future<void> apply(bool enabled) => SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );

  Future<void> restore() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}
