import 'dart:typed_data';

import '../../data/parser/book_parser.dart';
import '../../data/parser/charset_bridge.dart';
import '../../data/storage/sqlite_progress_store.dart';
import '../../domain/usecases/import_session.dart';
import 'real_bridges.dart';

/// 一次真实扫描的结果：根目录 + 实际文件路径列表。
class ImportScanResult {
  const ImportScanResult({required this.root, required this.paths});

  final String root;
  final List<String> paths;

  bool get isEmpty => paths.isEmpty;
}

/// 第三十二轮：替换 ImportDemoPaths / 静态演示授权。
/// 「选择目录 → 授权持久化 → 递归扫描 → 按扩展名过滤 → 读文件头 → 落库」
/// 全部走真实平台通道；平台不可用（如桌面/单测）时抛 [PlatformUnavailable]，
/// 由导入向导显示明确提示并可回退到演示数据，绝不静默显示假结果。
class ImportService {
  const ImportService({
    required this.saf,
    required this.files,
    required this.database,
    this.parser,
  });

  final PlatformSafBridge saf;
  final PlatformFileAccess files;
  final SqlExecutor database;

  /// 解析器默认注入「纯 Dart 文本 + 原生字符集回退」。
  final BookParser? parser;

  BookParser get _parser => parser ??
      ParserRouter(
        charset: PureDartCharsetBridge(
          nativeFallback: const PlatformCharsetFallback().decode,
        ),
      );

  /// 优先复用持久化授权；没有就拉起系统目录选择器。
  Future<ImportScanResult> scan({bool forcePick = false}) async {
    String? root;
    if (!forcePick && await saf.hasPersistedGrant()) {
      final List<String> granted = await saf.rescanPersisted();
      if (granted.isNotEmpty) root = granted.first;
    }
    final bool fresh = root == null;
    root ??= await saf.pickDirectory();
    if (root == null || root.isEmpty) {
      throw const PlatformUnavailable('目录授权', '未选择目录或用户取消');
    }
    if (fresh) await saf.persistGrant(root);

    final List<String> paths = await files.list(
      root,
      extensions: PlatformFileAccess.bookExtensions,
    );
    return ImportScanResult(root: root, paths: paths);
  }

  /// 按字节签名做 RAR5 / 加密包快检，与 ParserRouter 口径一致。
  Future<List<String>> filterSupported(List<String> paths) async {
    final List<String> out = <String>[];
    for (final String path in paths) {
      try {
        final Uint8List head = await files.readBytes(path);
        if (_isRar5(head) || _isEncryptedZip(head, path)) continue;
        out.add(path);
      } catch (_) {
        // 单个文件读失败不影响整批扫描，仍交给 ImportScanner 按扩展名裁决。
        out.add(path);
      }
    }
    return out;
  }

  /// 解析单个文件（供书籍详情 / 阅读器按需取正文）。
  Future<dynamic> parse(String path) async {
    final Uint8List bytes = await files.readBytes(path);
    return _parser.parse(path, bytes);
  }

  /// 导入提交后把新增书目写进 books 表；冲突项仍按 ImportCommit.deferred 处理。
  Future<int> persist(ImportCommit commit) async {
    int written = 0;
    for (final ImportBookDraft draft in commit.added) {
      await database.execute(
        '''INSERT INTO books
             (id, title, author, source_path, source_format, added_at)
           VALUES (?, ?, ?, ?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET
             title = excluded.title,
             source_path = excluded.source_path''',
        <Object?>[
          draft.id,
          draft.title,
          draft.author,
          draft.sourcePath,
          draft.format.toLowerCase(),
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      written++;
    }
    return written;
  }

  bool _isRar5(Uint8List b) =>
      b.length >= 8 &&
      b[0] == 0x52 && b[1] == 0x61 && b[2] == 0x72 && b[3] == 0x21 &&
      b[4] == 0x1A && b[5] == 0x07 && b[6] == 0x01 && b[7] == 0x00;

  bool _isEncryptedZip(Uint8List b, String path) {
    final String ext = ParserRouter.extOf(path);
    if (ext != 'zip' && ext != 'cbz') return false;
    return b.length >= 8 &&
        b[0] == 0x50 && b[1] == 0x4B && b[2] == 0x03 && b[3] == 0x04 &&
        (b[6] & 0x01) == 0x01;
  }
}
