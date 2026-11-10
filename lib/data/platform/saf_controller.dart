import 'package:flutter/foundation.dart';

import '../../domain/repositories/reader_bridge.dart';

@immutable
class GrantedDirectory {
  const GrantedDirectory({required this.uri, required this.grantedAt});
  final String uri;
  final DateTime grantedAt;
}

/// SAF 目录授权的 Dart 侧状态：对齐原项目「选择目录 → 授权持久化 → 重启一键重扫」。
/// Android 由 takePersistableUriPermission 持久化；iOS 用 bookmark；ohos 用系统选择器。
/// 文档类书籍（EPUB/TXT/PDF）不在媒体库覆盖范围内，必须走这条链路或「所有文件访问」。
class SafController {
  const SafController(this.bridge);

  final SafBridge bridge;

  Future<bool> hasGrant() => bridge.hasPersistedGrant();

  Future<String?> pickDirectory() => bridge.pickDirectory();

  /// 重扫：返回已持久化授权的目录列表；空列表时 UI 应明确提示当前状态，
  /// 而不是静默显示空书架。
  Future<List<GrantedDirectory>> rescan() async {
    final List<String> uris = await bridge.rescanPersisted();
    final DateTime now = DateTime.now();
    return <GrantedDirectory>[
      for (final String uri in uris) GrantedDirectory(uri: uri, grantedAt: now),
    ];
  }
}
