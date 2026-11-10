import '../../core/model/book_document.dart';
import '../../domain/usecases/progress_sampler.dart';
import '../../core/database/schema.dart';

/// 抽象 SQL 执行器：真实实现由 sqflite / drift 的 executor 注入。
/// 这样数据层逻辑（迁移、upsert、锚点还原）可用 FakeExecutor 单测，不依赖 Flutter SDK。
abstract interface class SqlExecutor {
  Future<int> userVersion();
  Future<void> setUserVersion(int version);
  Future<void> execute(String sql, [List<Object?> args]);
  Future<List<Map<String, Object?>>> query(String sql, [List<Object?> args]);

  /// 在单个事务里顺序执行，避免迁移跑到一半留下脏版本。
  Future<void> transaction(Future<void> Function() body);
}

/// 启动时统一入口：先自检注册表，再按 PRAGMA user_version 逐条升级。
Future<void> migrateDatabase(SqlExecutor db, {SchemaRegistry registry = const SchemaRegistry()}) async {
  registry.validate(currentVersion: kSchemaVersion);
  final int current = await db.userVersion();
  final List<SchemaMigration> pending = registry.pending(userVersion: current);
  if (pending.isEmpty) return;

  await db.transaction(() async {
    for (final SchemaMigration m in pending) {
      for (final String sql in m.up) {
        await db.execute(sql);
      }
      await db.setUserVersion(m.to);
    }
  });
}

/// ProgressStore 的 SQLite 实现。窗口尺寸变化会重排页码，
/// 所以除 pageIndex 外必须存锚点三元组，还原时按锚点定位而不是直接跳页码。
class SqliteProgressStore implements ProgressStore {
  const SqliteProgressStore(this.db);

  final SqlExecutor db;

  @override
  Future<void> write(ReadingProgress progress) async {
    await db.execute(
      '''INSERT INTO progress
           (book_id, chapter_index, page_index, page_offset, anchor_block, anchor_line, anchor_char, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(book_id) DO UPDATE SET
           chapter_index = excluded.chapter_index,
           page_index    = excluded.page_index,
           page_offset   = excluded.page_offset,
           anchor_block  = excluded.anchor_block,
           anchor_line   = excluded.anchor_line,
           anchor_char   = excluded.anchor_char,
           updated_at    = excluded.updated_at''',
      <Object?>[
        progress.bookId,
        progress.chapterIndex,
        progress.pageIndex,
        progress.pageOffset,
        0, // TODO(P2): 由 PaginationResult.anchorFor(pageIndex) 写入真实锚点
        0,
        0,
        progress.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<ReadingProgress?> read(String bookId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'SELECT chapter_index, page_index, page_offset, updated_at FROM progress WHERE book_id = ?',
      <Object?>[bookId],
    );
    if (rows.isEmpty) return null;
    final Map<String, Object?> r = rows.first;
    return ReadingProgress(
      bookId: bookId,
      chapterIndex: (r['chapter_index'] as int?) ?? 0,
      pageIndex: (r['page_index'] as int?) ?? 0,
      pageOffset: (r['page_offset'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch((r['updated_at'] as int?) ?? 0),
    );
  }
}
