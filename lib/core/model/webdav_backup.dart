import 'package:flutter/foundation.dart';

/// WebDAV 备份（第二十四轮）。
///
/// 原项目 README：「WebDAV 备份默认关闭，备份书库元数据、进度、分组与阅读
/// 会话；支持测试连接、立即备份、远端列表恢复、导出到本地」。
///
/// **默认关闭**，且关闭态连「测试连接」都不能发请求（对齐 `pureLocal` 的口径）。
/// 静态阶段只做状态机与预览文本：不读文件、不写文件、不发网络请求。
/// 真实 `WebDavClient` / 平台文件导出是 ❄️ 冻结。
enum BackupState { disabled, idle, testing, backingUp, restoring, exporting, ok, failed }

enum BackupAction { testConnection, backupNow, listRemote, restore, exportLocal }

@immutable
class BackupSnapshot {
  const BackupSnapshot({
    this.enabled = false,
    this.state = BackupState.disabled,
    this.remoteEntries = const <String>[],
    this.lastResult = '',
  });

  final bool enabled;
  final BackupState state;
  final List<String> remoteEntries;
  final String lastResult;

  static const List<BackupAction> actions = <BackupAction>[
    BackupAction.testConnection,
    BackupAction.backupNow,
    BackupAction.listRemote,
    BackupAction.restore,
    BackupAction.exportLocal,
  ];

  static const Map<BackupAction, String> actionLabels = <BackupAction, String>{
    BackupAction.testConnection: '测试连接',
    BackupAction.backupNow: '立即备份',
    BackupAction.listRemote: '远端列表',
    BackupAction.restore: '从远端恢复',
    BackupAction.exportLocal: '导出到本地',
  };

  /// 归一化：关闭时强制回落到 disabled，丢弃残留的远端列表与结果文本。
  BackupSnapshot normalized() => enabled
      ? this
      : const BackupSnapshot(enabled: false, state: BackupState.disabled);

  bool get isBusy =>
      state == BackupState.testing ||
      state == BackupState.backingUp ||
      state == BackupState.restoring ||
      state == BackupState.exporting;

  /// **唯一裁决点**：关闭态任何动作都被拒绝，页面不自己判断。
  BackupSnapshot dispatch(BackupAction action) {
    final BackupSnapshot n = normalized();
    if (!n.enabled || n.isBusy) return n;
    switch (action) {
      case BackupAction.testConnection:
        return BackupSnapshot(enabled: true, state: BackupState.testing,
            remoteEntries: n.remoteEntries);
      case BackupAction.backupNow:
        return BackupSnapshot(enabled: true, state: BackupState.backingUp,
            remoteEntries: n.remoteEntries);
      case BackupAction.listRemote:
        return BackupSnapshot(enabled: true, state: BackupState.restoring,
            remoteEntries: n.remoteEntries);
      case BackupAction.restore:
        return BackupSnapshot(enabled: true, state: BackupState.restoring,
            remoteEntries: n.remoteEntries);
      case BackupAction.exportLocal:
        return BackupSnapshot(enabled: true, state: BackupState.exporting,
            remoteEntries: n.remoteEntries);
    }
  }

  BackupSnapshot finish({required bool ok, String note = '', List<String>? entries}) {
    if (!enabled) return normalized();
    return BackupSnapshot(
      enabled: true,
      state: ok ? BackupState.ok : BackupState.failed,
      remoteEntries: entries ?? remoteEntries,
      lastResult: note,
    );
  }

  BackupSnapshot setEnabled(bool value) => value
      ? BackupSnapshot(enabled: true, state: BackupState.idle,
          remoteEntries: remoteEntries)
      : const BackupSnapshot();

  /// 备份内容清单：与原 README 四项一致，只有一份，不散写在页面。
  static const List<String> payloadLabels = <String>[
    '书库元数据', '阅读进度', '分组', '阅读会话',
  ];
}
