import 'dart:convert';

import '../../core/model/webdav_backup.dart';
import '../../data/platform/platform_bridges.dart';
import '../../data/platform/webdav_client.dart';
import 'persistence.dart';

/// 一次备份动作的真实结果，直接喂给 BackupSnapshot.finish()。
class BackupOutcome {
  const BackupOutcome({
    required this.ok,
    required this.note,
    this.entries = const <String>[],
    this.restored,
  });

  final bool ok;
  final String note;
  final List<String> entries;
  final Map<String, Object?>? restored;
}

/// 第三十二轮：替换「dispatch().finish(ok: true, note: 静态演示)」的假动作。
///
/// - 测试连接 / 立即备份 / 远端列表 / 从远端恢复：真实 WebDAV 请求；
/// - 导出到本地：通过 PlatformShareBridge 写应用私有文件并回传路径；
/// - 从远端恢复：把 JSON 交回 onRestore，由 AppState 应用，页面零改动。
class BackupService {
  const BackupService({
    required this.configStore,
    required this.share,
  });

  final WebDavConfigStore configStore;
  final PlatformShareBridge share;

  Future<BackupOutcome> run(
    BackupAction action,
    Map<String, Object?> payload, {
    WebDavConfig? override,
    void Function(Map<String, Object?>)? onRestore,
  }) async {
    final WebDavConfig config =
        override ?? await configStore.load();
    if (!config.isConfigured && action != BackupAction.exportLocal) {
      return const BackupOutcome(
        ok: false,
        note: '请先填写 WebDAV 服务器地址与账号',
      );
    }

    try {
      switch (action) {
        case BackupAction.exportLocal:
          return await _exportLocal(payload);
        case BackupAction.testConnection:
          return await _test(config);
        case BackupAction.backupNow:
          return await _backupNow(config, payload);
        case BackupAction.listRemote:
          return await _list(config);
        case BackupAction.restore:
          return await _restore(config, onRestore);
      }
    } on WebDavException catch (e) {
      return BackupOutcome(ok: false, note: e.toString());
    } catch (e) {
      return BackupOutcome(ok: false, note: '备份失败：$e');
    }
  }

  Future<BackupOutcome> _test(WebDavConfig config) async {
    final WebDavClient client = WebDavClient(config);
    try {
      final String note = await client.testConnection();
      return BackupOutcome(ok: true, note: note);
    } finally {
      client.close();
    }
  }

  Future<BackupOutcome> _backupNow(
      WebDavConfig config, Map<String, Object?> payload) async {
    final WebDavClient client = WebDavClient(config);
    try {
      final String name = _fileName();
      await client.put(name, _encode(payload));
      return BackupOutcome(
        ok: true,
        note: '已备份到 $name',
        entries: <String>[name],
      );
    } finally {
      client.close();
    }
  }

  Future<BackupOutcome> _list(WebDavConfig config) async {
    final WebDavClient client = WebDavClient(config);
    try {
      final List<String> entries = await client.list();
      return BackupOutcome(
        ok: true,
        note: entries.isEmpty ? '远端暂无备份文件' : '找到 ${entries.length} 个备份',
        entries: entries,
      );
    } finally {
      client.close();
    }
  }

  Future<BackupOutcome> _restore(WebDavConfig config,
      void Function(Map<String, Object?>)? onRestore) async {
    final WebDavClient client = WebDavClient(config);
    try {
      final List<String> entries = await client.list();
      if (entries.isEmpty) {
        return const BackupOutcome(ok: false, note: '远端没有可恢复的备份');
      }
      final String name = entries.first;
      final String text = await client.get(name);
      final Object? decoded = jsonDecode(text);
      if (decoded is! Map) {
        return const BackupOutcome(ok: false, note: '备份文件格式不正确');
      }
      final Map<String, Object?> root = Map<String, Object?>.from(decoded);
      final Object? inner = root['payload'];
      final Map<String, Object?> payload = inner is Map
          ? Map<String, Object?>.from(inner)
          : root;
      onRestore?.call(payload);
      return BackupOutcome(
        ok: true,
        note: '已从 $name 恢复书库元数据与阅读进度',
        entries: entries,
        restored: payload,
      );
    } finally {
      client.close();
    }
  }

  Future<BackupOutcome> _exportLocal(Map<String, Object?> payload) async {
    final String name = 'localreader-${_stamp()}.json';
    final String? path = await share.saveText(name, _encode(payload));
    if (path == null || path.isEmpty) {
      return const BackupOutcome(
        ok: false,
        note: '导出失败：原生文件写入通道未返回路径',
      );
    }
    return BackupOutcome(ok: true, note: '已导出到 $path', entries: <String>[name]);
  }

  String _encode(Map<String, Object?> payload) => jsonEncode(<String, Object?>{
        'schema': 1,
        'exportedAt': DateTime.now().millisecondsSinceEpoch,
        'payload': payload,
      });

  String _fileName() => 'localreader-${_stamp()}.json';

  String _stamp() {
    final DateTime now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
