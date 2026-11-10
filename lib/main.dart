import 'assembly/app_bootstrap.dart';

/// 对应原项目 `MainActivity.kt`：单入口，只做一件事——交给装配层启动。
/// App.kt 的初始化项（崩溃兜底 / 图片缓存裁剪 / 容器）全部在
/// `assembly/app_bootstrap.dart`，页面与业务层不散写启动代码。
void main() {
  AppBootstrap.run();
}
