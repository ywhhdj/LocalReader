import 'dart:convert';

import '../../core/model/app_settings.dart';
import '../../data/storage/sqlite_progress_store.dart';
import 'webdav_client.dart';

/// app_prefs KV 表（schema.dart v4）的统一访问口。
///
/// 全应用只应存在**一个实例**（`SqliteRuntime.instance.prefs`）：
///  - 命中内存缓存的读直接返回，**不会再查数据库**；
///  - 写先更新缓存再落库，写失败时本次会话仍读到新值。
/// 配合门控 executor，关闭态下连 `db.query` 都不会被调用。
class SqlPrefsStore {
  SqlPrefsStore(this.db);

  final SqlExecutor db;
  final Map<String, String?> _cache = <String, String?>{};

  /// SQLite 从「关闭」切到「开启」并完成全表预热后调用：
  /// 丢掉关闭态缓存的旧值，让下一次读命中门控层已预热好的内存镜像。
  void invalidate() => _cache.clear();

  Future<String?> read(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    final List<Map<String, Object?>> rows = await db.query(
      'SELECT value FROM app_prefs WHERE key = ?',
      <Object?>[key],
    );
    final String? value =
        rows.isEmpty ? null : rows.first['value'] as String?;
    // null 也缓存，避免「不存在的 key」被反复查。
    _cache[key] = value;
    return value;
  }

  Future<void> write(String key, String value) async {
    _cache[key] = value;
    await db.execute(
      '''INSERT INTO app_prefs (key, value) VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''',
      <Object?>[key, value],
    );
  }

  Future<void> remove(String key) async {
    _cache[key] = null;
    await db.execute(
      'DELETE FROM app_prefs WHERE key = ?',
      <Object?>[key],
    );
  }

  Future<Map<String, Object?>> readJson(String key) async {
    final String? raw = await read(key);
    if (raw == null || raw.isEmpty) return <String, Object?>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } catch (_) {
      // 损坏的偏好不应导致启动崩溃：忽略并回落到默认值。
    }
    return <String, Object?>{};
  }

  Future<void> writeJson(String key, Map<String, Object?> value) =>
      write(key, jsonEncode(value));
}

/// 真实设置持久化：替换 app.dart 里的 InMemorySettingsStore。
/// 注入的是全应用共享、带缓存的 prefs 实例；SQLite 未开启时读内存镜像，
/// 不会触发任何平台通道调用。
class SqlSettingsStore implements SettingsStore {
  SqlSettingsStore(this.prefs);

  final SqlPrefsStore prefs;
  static const String _key = 'app_settings';

  @override
  Future<AppSettings> load() async {
    try {
      final Map<String, Object?> m = await prefs.readJson(_key);
      if (m.isEmpty) return const AppSettings().normalized();
      return AppSettings.fromMap(m);
    } catch (_) {
      return const AppSettings().normalized();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      await prefs.writeJson(_key, settings.toMap());
    } catch (_) {
      // 平台数据库未就绪（例如首次启动迁移中）：本次改动仍留在内存态，
      // 下一次设置变更会重试写入，不向用户弹「保存失败」。
    }
  }
}

/// WebDAV 配置持久化。密码只落在应用私有数据库，绝不进日志 / 反馈 / 崩溃记录。
class WebDavConfigStore {
  WebDavConfigStore(this.prefs);

  /// 共享同一个带缓存的 prefs 实例：不再每次 `SqlPrefsStore(db)` 新建、
  /// 也不再每次 `load()` 都回表查一次。
  final SqlPrefsStore prefs;
  static const String _key = 'webdav_config';

  Future<WebDavConfig> load() async {
    try {
      final Map<String, Object?> m = await prefs.readJson(_key);
      return WebDavConfig.fromMap(m);
    } catch (_) {
      return WebDavConfig.empty;
    }
  }

  Future<void> save(WebDavConfig config) async {
    try {
      await prefs.writeJson(_key, config.toMap());
    } catch (_) {
      // 同上：配置仍在本会话生效。
    }
  }
}

/// 连续崩溃计数持久化：CrashGuard 的「时间窗内达到阈值进入安全模式」
/// 之前只在内存里，进程重启就清零。这里把计数与时间戳写进 app_prefs。
class CrashRecord {
  const CrashRecord({this.count = 0, this.firstAtMs = 0, this.lastAtMs = 0});

  final int count;
  final int firstAtMs;
  final int lastAtMs;

  Map<String, Object?> toMap() => <String, Object?>{
        'count': count,
        'firstAtMs': firstAtMs,
        'lastAtMs': lastAtMs,
      };

  static CrashRecord fromMap(Map<String, Object?> m) => CrashRecord(
        count: (m['count'] as num?)?.toInt() ?? 0,
        firstAtMs: (m['firstAtMs'] as num?)?.toInt() ?? 0,
        lastAtMs: (m['lastAtMs'] as num?)?.toInt() ?? 0,
      );
}

class CrashRecordStore {
  CrashRecordStore(this.prefs);

  final SqlPrefsStore prefs;
  static const String _key = 'crash_guard';

  Future<CrashRecord> load() async {
    try {
      return CrashRecord.fromMap(await prefs.readJson(_key));
    } catch (_) {
      return const CrashRecord();
    }
  }

  Future<void> save(CrashRecord record) async {
    try {
      await prefs.writeJson(_key, record.toMap());
    } catch (_) {
      // 崩溃链路本身必须永不再抛异常。
    }
  }

  Future<void> clear() async {
    try {
      await prefs.remove(_key);
    } catch (_) {
      // 同上。
    }
  }
}
