import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/parser/book_parser.dart';
import 'package:local_reader/core/parser/charset_bridge.dart';
import 'package:local_reader/core/storage/schema.dart';
import 'package:local_reader/core/storage/sqlite_progress_store.dart';

class FakeExecutor implements SqlExecutor {
  int version = 0;
  final List<String> executed = <String>[];

  @override
  Future<int> userVersion() async => version;
  @override
  Future<void> setUserVersion(int v) async {
    version = v;
    executed.add('PRAGMA user_version = $v');
  }
  @override
  Future<void> execute(String sql, [List<Object?> args = const <Object?>[]]) async => executed.add(sql);
  @override
  Future<List<Map<String, Object?>>> query(String sql, [List<Object?> args = const <Object?>[]]) async => <Map<String, Object?>>[];
  @override
  Future<void> transaction(Future<void> Function() body) async => body();
}

void main() {
  group('ParserRouter 格式分界', () {
    const ParserRouter router = ParserRouter(charset: PureDartCharsetBridge());

    test('可重排文本走 dartText，固定版式走 nativeRaster', () {
      expect(router.routeFor('/books/a.txt').route, RenderRoute.dartText);
      expect(router.routeFor('/books/a.md').route, RenderRoute.dartText);
      expect(router.routeFor('/books/a.epub').route, RenderRoute.dartText);
      expect(router.routeFor('/books/a.pdf').route, RenderRoute.nativeRaster);
      expect(router.routeFor('/books/a.cbz').route, RenderRoute.nativeRaster);
      expect(router.routeFor('/books/a.cbr').route, RenderRoute.nativeRaster);
    });

    test('未登记格式明确拒绝', () async {
      expect(router.routeFor('/books/a.xyz').route, RenderRoute.unsupported);
      await expectLater(
        router.parse('/books/a.xyz', Uint8List(0)),
        throwsA(isA<UnsupportedFormatException>()),
      );
    });

    test('RAR5 明确报错并提示转 CBZ/ZIP', () async {
      final Uint8List rar5 = Uint8List.fromList(<int>[0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]);
      await expectLater(
        router.parse('/books/a.rar', rar5),
        throwsA(isA<UnsupportedFormatException>().having(
          (UnsupportedFormatException e) => e.reason,
          'reason',
          contains('CBZ/ZIP'),
        )),
      );
    });

    test('加密 ZIP 明确报错', () async {
      final Uint8List encryptedZip = Uint8List.fromList(<int>[0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x01, 0x00]);
      await expectLater(
        router.parse('/books/a.cbz', encryptedZip),
        throwsA(isA<UnsupportedFormatException>()),
      );
    });
  });

  group('PureDartCharsetBridge 编码探测', () {
    const PureDartCharsetBridge bridge = PureDartCharsetBridge();

    test('UTF-8 BOM / UTF-16 BOM 识别', () {
      expect(
        bridge.detect(Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, 0xE4, 0xB8, 0xAD])),
        DetectedEncoding.utf8,
      );
      expect(
        bridge.detect(Uint8List.fromList(<int>[0xFF, 0xFE, 0x2D, 0x4E])),
        DetectedEncoding.utf16le,
      );
      expect(
        bridge.detect(Uint8List.fromList(<int>[0xFE, 0xFF, 0x4E, 0x2D])),
        DetectedEncoding.utf16be,
      );
    });

    test('UTF-8 正文解码并去掉 BOM', () async {
      final Uint8List bytes = Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode('中文')]);
      final DecodedText d = await bridge.decode(bytes);
      expect(d.content, '中文');
      expect(d.encoding, DetectedEncoding.utf8);
    });

    test('UTF-16LE surrogate pair 合并', () async {
      // U+1F600 😀 = D83D DE00，little endian: 3D D8 00 DE
      final Uint8List bytes = Uint8List.fromList(<int>[0xFF, 0xFE, 0x3D, 0xD8, 0x00, 0xDE]);
      final DecodedText d = await bridge.decode(bytes);
      expect(d.content, '😀');
    });

    test('未注入原生字符集时显式抛错，不静默乱码', () async {
      await expectLater(
        bridge.decode(Uint8List.fromList(<int>[0xD6, 0xD0, 0xCE, 0xC4]), hint: DetectedEncoding.gbk),
        throwsA(isA<UnsupportedCharsetException>()),
      );
    });
  });

  group('SchemaRegistry 迁移登记', () {
    test('注册表自检通过', () {
      const SchemaRegistry().validate(currentVersion: kSchemaVersion);
    });

    test('从 0 升到 3 的 SQL 序列连续且版本逐级递增', () async {
      final FakeExecutor db = FakeExecutor();
      await migrateDatabase(db);
      expect(db.version, 3);
      expect(db.executed.where((String s) => s.startsWith('PRAGMA')).length, 3);
      expect(db.executed.any((String s) => s.contains('ALTER TABLE progress ADD COLUMN page_offset')), isTrue);
    });

    test('已是最新版本时不重跑建表语句', () async {
      final FakeExecutor db = FakeExecutor()..version = 3;
      await migrateDatabase(db);
      expect(db.executed, isEmpty);
    });

    test('版本断档会被自检拒绝', () {
      const SchemaRegistry bad = SchemaRegistry(<SchemaMigration>[
        SchemaMigration(from: 0, to: 1, description: 'v1', up: <String>['CREATE TABLE a (x INT)']),
        SchemaMigration(from: 2, to: 3, description: 'v3', up: <String>['ALTER TABLE a ADD COLUMN y INT']),
      ]);
      expect(
        () => bad.validate(currentVersion: 3),
        throwsA(isA<SchemaIntegrityException>().having(
          (SchemaIntegrityException e) => e.reason,
          'reason',
          contains('版本断档'),
        )),
      );
    });

    test('登记版本与声明版本不一致会被拒绝', () {
      expect(
        () => const SchemaRegistry().validate(currentVersion: 2),
        throwsA(isA<SchemaIntegrityException>()),
      );
    });

    test('plan 只返回目标区间内的 SQL，且不允许降级', () {
      const SchemaRegistry r = SchemaRegistry();
      expect(r.plan(from: 2, to: 3).length, 4);
      expect(r.plan(from: 3, to: 3), isEmpty);
      expect(() => r.plan(from: 3, to: 2), throwsA(isA<SchemaIntegrityException>()));
    });
  });
}
