import 'dart:async';

import 'package:flutter/material.dart';

import '../../../assembly/app_scope.dart';
import '../../../assembly/app_services.dart';
import '../../../core/model/webdav_backup.dart';
import '../../../data/platform/backup_service.dart';
import '../../../data/platform/webdav_client.dart';

/// WebDAV 配置 + 五个真实动作（测试连接 / 立即备份 / 远端列表 /
/// 从远端恢复 / 导出到本地）。第三十二轮之前这些按钮要么被禁用，
/// 要么只把状态机写成「静态演示」；这里全部接真实服务。
class WebDavSheet extends StatefulWidget {
  const WebDavSheet({super.key});

  static Future<void> open(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (BuildContext _) => const WebDavSheet(),
      );

  @override
  State<WebDavSheet> createState() => _WebDavSheetState();
}

class _WebDavSheetState extends State<WebDavSheet> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _user = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _dir = TextEditingController(text: 'LocalReader');

  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final WebDavConfig config =
        await AppServices.of(context).webDavConfig.load();
    if (!mounted) return;
    setState(() {
      _url.text = config.url;
      _user.text = config.username;
      _pass.text = config.password;
      _dir.text = config.remoteDir;
    });
  }

  WebDavConfig get _config => WebDavConfig(
        url: _url.text.trim(),
        username: _user.text.trim(),
        password: _pass.text,
        remoteDir: _dir.text.trim().isEmpty ? 'LocalReader' : _dir.text.trim(),
      );

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _dir.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await AppServices.of(context).webDavConfig.save(_config);
    if (!mounted) return;
    setState(() => _status = '配置已保存到本机（密码只存在应用私有数据库）');
  }

  Future<void> _run(BackupAction action) async {
    final AppState state = AppScope.of(context);
    final AppServices services = AppServices.of(context);
    final BackupSnapshot snapshot = state.backup;

    // 未开启时点击不再「没反应」：自动启用备份并打开对应联网能力。
    if (!snapshot.enabled) {
      state.enableWebdav();
      state.updateBackup(snapshot.setEnabled(true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已开启 WebDAV 备份并切换到联网模式')),
      );
    }
    if (!state.networkingAllowed) {
      if (!mounted) return;
      setState(() => _status = '当前为纯本地模式，请先关闭「纯本地」开关');
      return;
    }

    setState(() {
      _busy = true;
      _status = '正在执行 ${BackupSnapshot.actionLabels[action]}…';
    });
    final BackupSnapshot dispatched =
        state.backup.dispatch(action);
    state.updateBackup(dispatched);

    final BackupOutcome outcome = await services.backup.run(
      action,
      state.backupPayload(),
      override: _config,
      onRestore: state.restoreFromBackup,
    );

    if (!mounted) return;
    final BackupSnapshot current = AppScope.of(context).backup;
    AppScope.of(context).updateBackup(current.finish(
      ok: outcome.ok,
      note: outcome.note,
      entries: outcome.entries.isEmpty ? null : outcome.entries,
    ));
    setState(() {
      _busy = false;
      _status = outcome.note;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final BackupSnapshot snapshot = state.backup;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('WebDAV 备份',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '仅在你点击备份动作时发起请求；关闭备份或开启纯本地模式后不会产生任何网络请求。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: '服务器地址（https://…/dav）',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _user,
              decoration: const InputDecoration(
                labelText: '账号',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码 / 应用专用密码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dir,
              decoration: const InputDecoration(
                labelText: '远端目录',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('保存配置'),
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final BackupAction a in BackupSnapshot.actions)
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => unawaited(_run(a)),
                    child: Text(BackupSnapshot.actionLabels[a]!),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_status.isNotEmpty)
              Text(_status, style: Theme.of(context).textTheme.bodySmall),
            if (snapshot.remoteEntries.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('远端备份：', style: Theme.of(context).textTheme.labelLarge),
              for (final String e in snapshot.remoteEntries)
                Text('· $e', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (snapshot.lastResult.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('上次结果：${snapshot.lastResult}',
                    style: Theme.of(context).textTheme.labelSmall),
              ),
          ],
        ),
      ),
    );
  }
}
