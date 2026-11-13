import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;

import '../storage/sqlite_progress_store.dart'
    show SqlExecutor, migrateDatabase;
import 'persistence.dart' show SqlPrefsStore;
import 'platform_bridges.dart' show PlatformSqlExecutor;

/// SQLite 属于**可选初始化**：默认关闭，用户代码显式置 `true` 才建表、才预热。
///
/// 关闭态（默认）：
///  - 不创建原生 executor、不跑迁移、**一次平台通道都不碰**；
///  - 设置 / WebDAV 配置 / 崩溃计数走内存 KV，本次会话内读写完全一致，只是不落盘；
///  - 进度与书籍写入暂存内存队列，开启时一次性回放，数据不丢。
///
/// 开启态（`await SqliteRuntime.instance.setEnabled(true)`）：
///  - 幂等：只做 **一次** `migrateDatabase` + **一次** `app_prefs` 全表预热；
///  - 之后 `app_prefs` 全部读内存镜像，业务侧「设置 / 配置 / 崩溃记录」**0 次查库**；
///  - 其它表按需查并缓存，任何写操作使缓存失效，绝不每次交互都查库。
///
/// 用户代码示例（按需，不是必须）：
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await SqliteRuntime.instance.setEnabled(true); // 只有这一句会触发初始化
///   AppBootstrap.run();
/// }
/// ```
/// 不写这句时应用照常运行，SQLite 完全不初始化。
class SqliteRuntime {
  SqliteRuntime._() : executor = GatedSqlExecutor() {
    // 预热完成后先清掉关闭态的 KV 缓存，再通知崩溃保护等可选链路，
    // 保证它们读到的是「磁盘 + 本次会话」合并后的最新值。
    executor.onWarm = () => prefs.invalidate();
  }

  static final SqliteRuntime instance = SqliteRuntime._();

  /// 全应用唯一门控 executor：所有 Store / Service 都注入它，不再各自 new 通道。
  final GatedSqlExecutor executor;

  /// 全应用唯一 KV 访问口：`AppServices` 与 `AppBootstrap` 共用这一份缓存。
  late final SqlPrefsStore prefs = SqlPrefsStore(executor);

  bool get enabled => executor.state.value;
  ValueNotifier<bool> get enabledListenable => executor.state;

  /// 用户代码设 `true` 才初始化；设 `false` 只停止落库，保留内存态与已建的表。
  Future<void> setEnabled(bool value) => executor.setEnabled(value);

  /// 供崩溃保护等可选链路注册「开启后再执行一次」的钩子。
  void addOnEnabled(Future<void> Function() callback) =>
      executor.addOnEnabled(callback);

  /// 观测用：真实跨通道查询次数。关闭态恒为 0，开启态只有预热那 1 次是必然的。
  int get channelQueryCount => executor.channelQueryCount;
}

typedef SqlExecutorFactory = SqlExecutor Function();

class _Write {
  const _Write(this.sql, this.args);

  final String sql;
  final List<Object?> args;
}

/// 门控 + 缓存的 [SqlExecutor]：实现同一个窄接口，因此现有
/// `SqlPrefsStore` / `SqliteProgressStore` / `ImportService` / `BackupService`
/// 一行都不用改，只要注入点从 `PlatformSqlExecutor` 换成这里。
class GatedSqlExecutor implements SqlExecutor {
  GatedSqlExecutor({SqlExecutorFactory? delegateFactory})
      : _delegateFactory = delegateFactory ?? _defaultFactory;

  static SqlExecutor _defaultFactory() => const PlatformSqlExecutor();

  static const String _upsertPrefs =
      '''INSERT INTO app_prefs (key, value) VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value''';

  final SqlExecutorFactory _delegateFactory;
  SqlExecutor? _delegate;

  final ValueNotifier<bool> state = ValueNotifier<bool>(false);
  bool _enabled = false;
  bool _initialized = false;
  bool _initializing = false;
  Completer<void>? _init;
  Future<void> _writeQueue = Future<void>.value();

  /// `app_prefs` 的内存镜像：开启后即全量预热，之后永不回表查询。
  final Map<String, String> _prefs = <String, String>{};

  /// 非 `app_prefs` 查询的结果缓存，键 = SQL + 参数。
  final Map<String, List<Map<String, Object?>>> _queryCache =
      <String, List<Map<String, Object?>>>{};

  /// 关闭态累积的「非 app_prefs」写入，开启时回放一次。
  final List<_Write> _pending = <_Write>[];
  final List<Future<void> Function()> _onEnabled = <Future<void> Function()>[];

  int _memoryVersion = 0;
  int _channelQueries = 0;

  bool get enabled => _enabled;
  bool get initialized => _initialized;
  int get channelQueryCount => _channelQueries;

  /// 预热完成、通知 [_onEnabled] 之前调用，用于让上层 KV 缓存失效。
  void Function()? onWarm;

  void addOnEnabled(Future<void> Function() callback) =>
      _onEnabled.add(callback);

  Future<void> setEnabled(bool value) async {
    if (!value) {
      if (_enabled) {
        _enabled = false;
        state.value = false;
      }
      return;
    }
    if (_enabled) return;
    // 并发调用只初始化一次：后来者复用同一个 Completer。
    if (_initializing) return _init!.future;
    _initializing = true;
    _init = Completer<void>();
    try {
      await _initialize();
      _enabled = true;
      state.value = true;
      if (!_init!.isCompleted) _init!.complete();
      for (final Future<void> Function() callback
          in List<Future<void> Function()>.of(_onEnabled)) {
        try {
          await callback();
        } catch (_) {
          // 可选初始化钩子失败不能影响「已开启」这个事实。
        }
      }
    } catch (error, stack) {
      if (!_init!.isCompleted) _init!.completeError(error, stack);
      rethrow;
    } finally {
      _initializing = false;
    }
  }

  /// 唯一一次真实初始化：迁移 → 预热 → 刷入会话数据 → 回放队列。
  Future<void> _initialize() async {
    if (_initialized) return;
    final SqlExecutor db = _delegate ??= _delegateFactory();

    // ① 直接把真实 executor 交给 migrateDatabase，绕过本类的 transaction 包装；
    //    这是全流程唯一一次建表 / 读 user_version。
    await migrateDatabase(db);

    // ② 唯一一次全表预热。此后所有 app_prefs 读都命中 _prefs，不再查库。
    _channelQueries++;
    final List<Map<String, Object?>> rows =
        await db.query('SELECT key, value FROM app_prefs');
    for (final Map<String, Object?> row in rows) {
      final Object? key = row['key'];
      final Object? value = row['value'];
      if (key != null && value != null && !_prefs.containsKey('$key')) {
        _prefs['$key'] = '$value';
      }
    }

    // ③ 内存优先：本次会话里改过的设置比磁盘上的旧值新，刷回去而不是被覆盖。
    for (final MapEntry<String, String> entry in _prefs.entries) {
      await db.execute(_upsertPrefs, <Object?>[entry.key, entry.value]);
    }

    // ④ 关闭态累积的进度 / 书籍写入一次性回放，避免「开启前白读」。
    for (final _Write write in _pending) {
      await db.execute(write.sql, write.args);
    }
    _pending.clear();
    _queryCache.clear();
    _initialized = true;
    onWarm?.call();
  }

  // ------------------------------------------------------------ SqlExecutor

  @override
  Future<int> userVersion() async =>
      _enabled ? _delegate!.userVersion() : _memoryVersion;

  @override
  Future<void> setUserVersion(int version) async {
    _memoryVersion = version;
    if (_enabled) await _delegate!.setUserVersion(version);
  }

  @override
  Future<void> transaction(Future<void> Function() body) async {
    // 关闭态：body 里的 execute 会进 _pending，不需要真事务。
    if (!_enabled) {
      await body();
      return;
    }
    await _delegate!.transaction(body);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> args = const <Object?>[],
  ]) async {
    final String head = sql.trimLeft().toUpperCase();
    if (head.startsWith('SELECT') && sql.contains('app_prefs')) {
      // 无论开关状态，app_prefs 一律读内存镜像：**0 次数据库查询**。
      if (args.isEmpty) {
        return <Map<String, Object?>>[
          for (final MapEntry<String, String> e in _prefs.entries)
            <String, Object?>{'key': e.key, 'value': e.value},
        ];
      }
      final String key = '${args.first}';
      final String? value = _prefs[key];
      return value == null
          ? <Map<String, Object?>>[]
          : <Map<String, Object?>>[
              <String, Object?>{'value': value},
            ];
    }

    // 关闭态：其它表也不查库，返回空集（进度等由业务层内存态兜底）。
    if (!_enabled) return const <Map<String, Object?>>[];

    final String cacheKey = _cacheKey(sql, args);
    final List<Map<String, Object?>>? hit = _queryCache[cacheKey];
    if (hit != null) return hit;
    _channelQueries++;
    final List<Map<String, Object?>> rows = await _delegate!.query(sql, args);
    _queryCache[cacheKey] = rows;
    return rows;
  }

  @override
  Future<void> execute(
    String sql, [
    List<Object?> args = const <Object?>[],
  ]) async {
    final String head = sql.trimLeft().toUpperCase();
    final bool isPrefs = sql.contains('app_prefs');

    if (isPrefs) {
      if (head.startsWith('INSERT') || head.startsWith('REPLACE')) {
        if (args.length >= 2) _prefs['${args[0]}'] = '${args[1]}';
      } else if (head.startsWith('DELETE')) {
        if (args.isNotEmpty) _prefs.remove('${args[0]}');
      }
    }

    _queryCache.clear();

    if (!_enabled) {
      // 关闭态只记内存：app_prefs 已进镜像，其它表进回放队列。
      if (!isPrefs) _pending.add(_Write(sql, List<Object?>.of(args)));
      return;
    }

    // 串行化写入，避免 unawaited 并发下 SQL 顺序交错。
    final Future<void> task = _writeQueue.then<void>((_) async {
      await _delegate!.execute(sql, args);
    });
    _writeQueue = task.catchError((Object _) {});
    await task;
  }

  String _cacheKey(String sql, List<Object?> args) =>
      '$sql\u0001${args.map((Object? a) => '$a').join('\u0002')}';
}
