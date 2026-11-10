import 'package:flutter/foundation.dart';

/// 数据层第一原则：**从第一天登记迁移版本**。
/// 原 Kotlin 工程 AppDatabase version = 1 且未登记迁移，实体变更后需同步维护
/// schema.sql 与 Room 导出的 schemas/ JSON，否则 Room 直接抛异常。这个坑不带过来。
const int kSchemaVersion = 3;

@immutable
class SchemaMigration {
  const SchemaMigration({
    required this.from,
    required this.to,
    required this.description,
    required this.up,
  });

  final int from;
  final int to;
  final String description;
  final List<String> up;

  int get next => to;
}

/// v1 建表；v2 补进度页内偏移；v3 补分组与阅读会话。
/// 每条迁移都是纯 SQL 字符串列表，便于注入任意 SQLite executor 执行与单测校验。
const List<SchemaMigration> kMigrations = <SchemaMigration>[
  SchemaMigration(
    from: 0,
    to: 1,
    description: '建表：书籍 / 章节 / 进度 / 索引',
    up: <String>[
      '''CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL DEFAULT '',
        source_path TEXT NOT NULL,
        source_format TEXT NOT NULL,
        cover_path TEXT,
        encoding TEXT,
        added_at INTEGER NOT NULL,
        last_read_at INTEGER
      )''',
      '''CREATE TABLE chapters (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        ordinal INTEGER NOT NULL,
        title TEXT NOT NULL,
        block_count INTEGER NOT NULL DEFAULT 0
      )''',
      '''CREATE TABLE progress (
        book_id TEXT PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE,
        chapter_index INTEGER NOT NULL DEFAULT 0,
        page_index INTEGER NOT NULL DEFAULT 0,
        block_index INTEGER NOT NULL DEFAULT 0,
        line_index INTEGER NOT NULL DEFAULT 0,
        char_offset INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )''',
      'CREATE INDEX idx_books_last_read ON books(last_read_at DESC)',
      'CREATE INDEX idx_chapters_book_ordinal ON chapters(book_id, ordinal)',
    ],
  ),
  SchemaMigration(
    from: 1,
    to: 2,
    description: '进度补页内位置（对应原项目「采样含页内位置」）',
    up: <String>[
      'ALTER TABLE progress ADD COLUMN page_offset REAL NOT NULL DEFAULT 0.0',
      'ALTER TABLE progress ADD COLUMN anchor_block INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE progress ADD COLUMN anchor_line INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE progress ADD COLUMN anchor_char INTEGER NOT NULL DEFAULT 0',
    ],
  ),
  SchemaMigration(
    from: 2,
    to: 3,
    description: '分组与阅读会话（WebDAV 备份范围）',
    up: <String>[
      '''CREATE TABLE groups_table (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )''',
      '''CREATE TABLE book_groups (
        book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        group_id TEXT NOT NULL REFERENCES groups_table(id) ON DELETE CASCADE,
        PRIMARY KEY (book_id, group_id)
      )''',
      '''CREATE TABLE reading_sessions (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        minutes INTEGER NOT NULL DEFAULT 0
      )''',
      'CREATE INDEX idx_sessions_book_started ON reading_sessions(book_id, started_at)',
    ],
  ),
];

class SchemaIntegrityException implements Exception {
  const SchemaIntegrityException(this.reason);
  final String reason;

  @override
  String toString() => 'SchemaIntegrityException: $reason';
}

/// 迁移注册表的纯逻辑：可单测、可在启动时先自检再执行，避免「改了实体忘了登记」。
class SchemaRegistry {
  const SchemaRegistry([this.migrations = kMigrations]);

  final List<SchemaMigration> migrations;

  void validate({required int currentVersion}) {
    int expected = 0;
    for (final SchemaMigration m in migrations) {
      if (m.from != expected) {
        throw SchemaIntegrityException('版本断档：期望 from=$expected，实际 ${m.from}');
      }
      if (m.to != m.from + 1) {
        throw SchemaIntegrityException('版本必须逐级递增：${m.from}→${m.to}');
      }
      if (m.up.isEmpty || m.up.any((String sql) => sql.trim().isEmpty)) {
        throw SchemaIntegrityException('迁移 ${m.from}→${m.to} 存在空 SQL');
      }
      expected = m.to;
    }
    if (expected != currentVersion) {
      throw SchemaIntegrityException('登记版本 $expected 与声明的 kSchemaVersion=$currentVersion 不一致');
    }
  }

  /// 返回从 from 升到 to 需要按顺序执行的 SQL；已是最新版本时返回空列表。
  List<String> plan({required int from, required int? to}) {
    final int target = to ?? kSchemaVersion;
    if (from > target) {
      throw SchemaIntegrityException('不能降级：$from → $target');
    }
    final List<String> sql = <String>[];
    for (final SchemaMigration m in migrations) {
      if (m.from >= from && m.to <= target) sql.addAll(m.up);
    }
    return List<String>.unmodifiable(sql);
  }

  /// 启动时对照 PRAGMA user_version 决定要跑哪几条。
  List<SchemaMigration> pending({required int userVersion}) =>
      List<SchemaMigration>.unmodifiable(
        migrations.where((SchemaMigration m) => m.from >= userVersion && m.to <= kSchemaVersion),
      );
}
