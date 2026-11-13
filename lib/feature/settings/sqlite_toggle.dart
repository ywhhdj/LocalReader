import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/platform/sqlite_runtime.dart';

/// 设置页里的 SQLite 可选开关。
class SqliteToggle extends StatefulWidget {
  const SqliteToggle({super.key});

  @override
  State<SqliteToggle> createState() => _SqliteToggleState();
}

class _SqliteToggleState extends State<SqliteToggle> {
  bool _busy = false;
  String? _error;

  Future<void> _set(bool value) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SqliteRuntime.instance.setEnabled(value);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SqliteRuntime.instance.enabledListenable,
      builder: (BuildContext context, bool enabled, Widget? _) {
        final int queries = SqliteRuntime.instance.channelQueryCount;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: _busy ? null : (bool v) => unawaited(_set(v)),
              title: const Text('启用本地数据库（可选）'),
              subtitle: Text(enabled
                  ? '已初始化：设置 / 进度 / 备份配置落盘；KV 读内存，不重复查库'
                  : '默认关闭：不建表、不查库，设置仅本次会话有效'),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('初始化失败：$_error',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12)),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                '跨通道数据库查询次数：$queries'
                '${enabled ? '' : '（关闭态恒为 0）'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}
