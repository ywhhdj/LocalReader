import 'dart:async';
import 'dart:convert';

import '../storage/sqlite_progress_store.dart';

/// 云端缓存的四种对象（第二十九轮：解冻「云端缓存」）。
/// 只缓存公开列表 / 目录 / 个人书架元数据与**用户点开的单章**，
/// 不整本预下载、不打包分发；退出登录或关闭在线目录时统一清空。
enum Wenku8CacheKind { listing, detail, chapter, bookcase }

class Wenku8CachePolicy {
  const Wenku8CachePolicy({
    this.enabled = true,
    this.offlineChapters = true,
    this.maxEntries = 400,
    this.maxBytes = 32 * 1024 * 1024,
  });

  final bool enabled;

  /// 已缓存章节是否允许离线阅读；关闭时章节缓存只读不写。
  final bool offlineChapters;
  final int maxEntries;
  final int maxBytes;

  /// 不同对象的有效期：榜单变化快，正文基本不变。
  static const Map<Wenku8CacheKind, Duration> ttl = <Wenku8CacheKind, Duration>{
    Wenku8CacheKind.listing: Duration(minutes: 10),
    Wenku8CacheKind.bookcase: Duration(minutes: 5),
    Wenku8CacheKind.detail: Duration(hours: 6),
    Wenku8CacheKind.chapter: Duration(days: 14),
  };

  bool allows(Wenku8CacheKind kind) =>
      enabled && (kind != Wenku8CacheKind.chapter || offlineChapters);

  Wenku8CachePolicy copyWith({
    bool? enabled,
    bool? offlineChapters,
    int? maxEntries,
    int? maxBytes,
  }) =>
      Wenku8CachePolicy(
        enabled: enabled ?? this.enabled,
        offlineChapters: offlineChapters ?? this.offlineChapters,
        maxEntries: maxEntries ?? this.maxEntries,
        maxBytes: maxBytes ?? this.maxBytes,
      );

  Map<String, Object> toMap() => <String, Object>{
        'enabled': enabled,
        'offlineChapters': offlineChapters,
        'maxEntries': maxEntries,
        'maxBytes': maxBytes,
      };

  static Wenku8CachePolicy fromMap(Map<String, Object?> m) => Wenku8CachePolicy(
        enabled: m['enabled'] as bool? ?? true,
        offlineChapters: m['offlineChapters'] as bool? ?? true,
        maxEntries: m['maxEntries'] as int? ?? 400,
        maxBytes: m['maxBytes'] as int? ?? 32 * 1024 * 1024,
      );

  @override
  bool operator ==(Object other) =>
      other is Wenku8CachePolicy &&
      other.enabled == enabled &&
      other.offlineChapters == offlineChapters &&
      other.maxEntries == maxEntries &&
      other.maxBytes == maxBytes;

  @override
  int get hashCode =>
      Object.hash(enabled, offlineChapters, maxEntries, maxBytes);
}

class Wenku8CacheEntry {
  const Wenku8CacheEntry({
    required this.key,
    required this.kind,
    required this.payload,
    required this.storedAt,
    required this.bytes,
    this.etag,
  });

  final String key;
  final Wenku8CacheKind kind;
  final String payload;
  final DateTime storedAt;
  final int bytes;
  final String? etag;

  bool isFresh(DateTime now, Duration ttl) =>
      now.difference(storedAt) <= ttl;

  Map<String, Object?> toMap() => <String, Object?>{
        'key': key,
        'kind': kind.name,
        'payload': payload,
        'storedAt': storedAt.millisecondsSinceEpoch,
        'bytes': bytes,
        'etag': etag,
      };

  static Wenku8CacheEntry? fromMap(Map<String, Object?> m) {
    final String? k = m['key'] as String?;
    final String? p = m['payload'] as String?;
    final Object? ts = m['storedAt'];
    if (k == null || p == null || ts is! int) return null;
    final Wenku8CacheKind kind = Wenku8CacheKind.values.firstWhere(
      (Wenku8CacheKind e) => e.name == m['kind'],
      orElse: () => Wenku8CacheKind.listing,
    );
    return Wenku8CacheEntry(
      key: k,
      kind: kind,
      payload: p,
      storedAt: DateTime.fromMillisecondsSinceEpoch(ts),
      bytes: m['bytes'] as int? ?? p.length,
      etag: m['etag'] as String?,
    );
  }
}

/// 存储窄接口：内存实现用于静态 / 单测，SQLite 实现由平台层注入 executor，
/// 换实现不动缓存策略与页面。
abstract interface class Wenku8CacheStore {
  Future<Wenku8CacheEntry?> read(String key);
  Future<void> write(Wenku8CacheEntry entry);
  Future<void> remove(String key);
  Future<void> clear();
  Future<List<Wenku8CacheEntry>> all();
}

class MemoryWenku8CacheStore implements Wenku8CacheStore {
  MemoryWenku8CacheStore();

  final Map<String, Wenku8CacheEntry> _rows = <String, Wenku8CacheEntry>{};

  @override
  Future<Wenku8CacheEntry?> read(String key) async => _rows[key];

  @override
  Future<void> write(Wenku8CacheEntry entry) async {
    _rows[entry.key] = entry;
  }

  @override
  Future<void> remove(String key) async => _rows.remove(key);

  @override
  Future<void> clear() async => _rows.clear();

  @override
  Future<List<Wenku8CacheEntry>> all() async =>
      List<Wenku8CacheEntry>.unmodifiable(_rows.values);
}

/// SQLite 实现：表由 `SchemaRegistry` 的第 4 版迁移创建。
/// 只存文本与元数据，不存整本书、不存凭据。
class SqliteWenku8CacheStore implements Wenku8CacheStore {
  const SqliteWenku8CacheStore(this.db);

  final SqlExecutor db;

  static const String table = 'wenku8_cache';

  @override
  Future<Wenku8CacheEntry?> read(String key) async {
    final List<Map<String, Object?>> rows = await db.query(
      'SELECT key, kind, payload, stored_at, bytes, etag FROM $table WHERE key = ?',
      <Object?>[key],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<void> write(Wenku8CacheEntry entry) async {
    await db.execute(
      'INSERT OR REPLACE INTO $table '
      '(key, kind, payload, stored_at, bytes, etag) VALUES (?, ?, ?, ?, ?, ?)',
      <Object?>[
        entry.key,
        entry.kind.name,
        entry.payload,
        entry.storedAt.millisecondsSinceEpoch,
        entry.bytes,
        entry.etag,
      ],
    );
  }

  @override
  Future<void> remove(String key) async {
    await db.execute('DELETE FROM $table WHERE key = ?', <Object?>[key]);
  }

  @override
  Future<void> clear() async => db.execute('DELETE FROM $table');

  @override
  Future<List<Wenku8CacheEntry>> all() async {
    final List<Map<String, Object?>> rows = await db.query(
      'SELECT key, kind, payload, stored_at, bytes, etag FROM $table',
    );
    return <Wenku8CacheEntry>[
      for (final Map<String, Object?> r in rows)
        if (_fromRow(r) != null) _fromRow(r)!,
    ];
  }

  static Wenku8CacheEntry? _fromRow(Map<String, Object?> r) =>
      Wenku8CacheEntry.fromMap(<String, Object?>{
        'key': r['key'],
        'kind': r['kind'],
        'payload': r['payload'],
        'storedAt': r['stored_at'],
        'bytes': r['bytes'],
        'etag': r['etag'],
      });
}

class Wenku8CacheStats {
  const Wenku8CacheStats({
    required this.entries,
    required this.bytes,
    required this.chapterCount,
    required this.policy,
  });

  final int entries;
  final int bytes;
  final int chapterCount;
  final Wenku8CachePolicy policy;

  String get sizeLabel => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)} KB'
          : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// 云端缓存：TTL + LRU + 容量上限 + 策略开关，出口统一。
/// `clock` 可注入，规格单测不需要真机时间。
class Wenku8Cache {
  Wenku8Cache(
    this.store, {
    Wenku8CachePolicy policy = const Wenku8CachePolicy(),
    DateTime Function()? clock,
  })  : policy = policy,
        _clock = clock ?? DateTime.now;

  final Wenku8CacheStore store;
  Wenku8CachePolicy policy;
  final DateTime Function() _clock;

  /// 缓存键只由来源 URL 生成，不含凭据、Cookie、Token。
  static String keyFor(Uri uri) => uri.toString();

  void updatePolicy(Wenku8CachePolicy next) => policy = next;

  Future<String?> read(
    Uri uri,
    Wenku8CacheKind kind, {
    bool allowStale = false,
  }) async {
    if (!policy.allows(kind)) return null;
    final Wenku8CacheEntry? e = await store.read(keyFor(uri));
    if (e == null || e.kind != kind) return null;
    final Duration ttl = Wenku8CachePolicy.ttl[kind]!;
    if (!allowStale && !e.isFresh(_clock(), ttl)) return null;
    return e.payload;
  }

  Future<String?> readStale(Uri uri, Wenku8CacheKind kind) =>
      read(uri, kind, allowStale: true);

  Future<void> write(
    Uri uri,
    Wenku8CacheKind kind,
    String payload, {
    String? etag,
  }) async {
    if (!policy.allows(kind)) return;
    final int bytes = utf8.encode(payload).length;
    await store.write(Wenku8CacheEntry(
      key: keyFor(uri),
      kind: kind,
      payload: payload,
      storedAt: _clock(),
      bytes: bytes,
      etag: etag,
    ));
    await enforceLimits();
  }

  /// 先删过期，再按「最久未用」淘汰到条目数与字节数上限内。
  Future<void> enforceLimits() async {
    final List<Wenku8CacheEntry> rows = await store.all();
    final DateTime now = _clock();
    for (final Wenku8CacheEntry e in rows) {
      if (!e.isFresh(now, Wenku8CachePolicy.ttl[e.kind]!)) {
        await store.remove(e.key);
      }
    }
    final List<Wenku8CacheEntry> alive = await store.all();
    alive.sort((Wenku8CacheEntry a, Wenku8CacheEntry b) =>
        b.storedAt.compareTo(a.storedAt));
    int totalBytes = 0;
    int kept = 0;
    for (final Wenku8CacheEntry e in alive) {
      kept += 1;
      totalBytes += e.bytes;
      if (kept > policy.maxEntries || totalBytes > policy.maxBytes) {
        await store.remove(e.key);
      }
    }
  }

  Future<void> clear() => store.clear();

  Future<Wenku8CacheStats> stats() async {
    final List<Wenku8CacheEntry> rows = await store.all();
    int bytes = 0;
    int chapters = 0;
    for (final Wenku8CacheEntry e in rows) {
      bytes += e.bytes;
      if (e.kind == Wenku8CacheKind.chapter) chapters += 1;
    }
    return Wenku8CacheStats(
      entries: rows.length,
      bytes: bytes,
      chapterCount: chapters,
      policy: policy,
    );
  }
}
