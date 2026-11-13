import 'assembly/app_bootstrap.dart';

/// 对应原项目 `MainActivity.kt`：单入口，只做一件事——交给装配层启动。
/// App.kt 的初始化项（崩溃兜底 / 图片缓存裁剪 / 容器）全部在
/// `assembly/app_bootstrap.dart`，页面与业务层不散写启动代码。
///
/// **SQLite 属于可选初始化，默认完全不初始化**：应用启动不建表、不查库，
/// 设置 / 进度 / WebDAV 配置只在本次会话内生效。
///
/// 需要持久化时，由用户代码显式置 true 才会初始化一次：
/// ```dart
/// import 'package:flutter/widgets.dart';
/// import 'data/platform/sqlite_runtime.dart';
///
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await SqliteRuntime.instance.setEnabled(true); // 唯一触发初始化的地方
///   AppBootstrap.run();
/// }
/// ```
/// 也可以不改入口，在应用内「设置 → 启用本地数据库（可选）」随时开启。
void main() {
  AppBootstrap.run();
}
