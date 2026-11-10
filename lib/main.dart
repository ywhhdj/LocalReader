import 'package:flutter/widgets.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO(P1): 初始化数据库（Drift/Isar）、平台通道、崩溃兜底。
  // 对应原 Kotlin 工程 App.kt（Coil / 崩溃兜底 / 容器 / 内存裁剪）与 CrashGuard.kt。
  // FlutterError.onError / PlatformDispatcher.onError 需在此注册，并保留「连续崩溃保护」语义。

  runApp(const LocalReaderApp());
}
