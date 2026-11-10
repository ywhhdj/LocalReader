import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/content/legal_texts.dart';
import 'package:local_reader/core/data/book_repository.dart';
import 'package:local_reader/core/data/library_query.dart';
import 'package:local_reader/core/import/import_session.dart';
import 'package:local_reader/core/parser/book_parser.dart';
import 'package:local_reader/core/parser/charset_bridge.dart';
import 'package:local_reader/core/state/app_scope.dart';
import 'package:local_reader/core/state/app_settings.dart';

List<ExistingBook> demoExisting() => <ExistingBook>[
      for (final BookSummary b in const DemoBookRepository().cached)
        ExistingBook(id: b.id, title: b.title),
    ];

/// intro → permission → 选方式 → 授权 → scan（报告与冲突已算好）
ImportSession scanned({ImportPermissionMode mode = ImportPermissionMode.saf}) {
  final List<ExistingBook> existing = demoExisting();
  ImportSession s = const ImportSession().advance(existing: existing);
  s = s.chooseMode(mode);
  s = s.grant();
  return s.advance(existing: existing);
}

void main() {
  group('格式分界只有一张表', () {
    test('静态 routeForPath 与实例 routeFor 完全一致', () {
      const ParserRouter router = ParserRouter(charset: PureDartCharsetBridge());
      for (final String p in <String>[
        '/a.txt', '/a.epub', '/a.pdf', '/a.cbz', '/a.cbr', '/a.md', '/a.xyz',
      ]) {
        expect(ParserRouter.routeForPath(p).route, router.routeFor(p).route);
        expect(ParserRouter.routeForPath(p).note, router.routeFor(p).note);
      }
    });

    test('extOf 大小写不敏感、无扩展名返回空', () {
      expect(ParserRouter.extOf('/a/BOOK.TXT'), 'txt');
      expect(ParserRouter.extOf('/a/noext'), '');
      expect(ParserRouter.routeForPath('/a/NOEXT').route, RenderRoute.unsupported);
    });
  });

  group('ImportScanner 扫描分类', () {
    test('演示路径总数 / 可导入 / 不支持 / 未登记', () {
      final ScanReport r = ImportScanner.scan(ImportDemoPaths.base);
      expect(r.total, 11);
      expect(r.acceptedCount, 8);
      expect(r.rejectedCount, 2);
      expect(r.unsupportedCount, 1);
      expect(r.byStatus[CandidateStatus.accepted], 8);
    });

    test('可重排文本与原生栅格化都算可导入', () {
      final ScanReport r = ImportScanner.scan(<String>[
        '/a.txt', '/a.epub', '/a.pdf', '/a.cbz', '/a.md',
      ]);
      expect(r.acceptedCount, 5);
      expect(r.accepted.where((ImportCandidate c) => c.route == RenderRoute.dartText).length, 3);
      expect(r.accepted.where((ImportCandidate c) => c.route == RenderRoute.nativeRaster).length, 2);
    });

    test('RAR5 / 加密包明确拒绝并提示转 CBZ/ZIP', () {
      final ScanReport r = ImportScanner.scan(<String>[
        '/x/归档_rar5.cbz', '/x/加密备份.zip', '/x/protected.zip',
      ]);
      expect(r.acceptedCount, 0);
      expect(r.rejected.length, 3);
      // 扫描结果按路径自然排序，不按输入顺序；按路径定位而不是靠下标。
      expect(
        r.rejected.firstWhere((ImportCandidate c) => c.path.contains('rar5')).reason,
        LegalTexts.importRar5Reason,
      );
      expect(
        r.rejected.firstWhere((ImportCandidate c) => c.path.contains('加密')).reason,
        LegalTexts.importEncryptedReason,
      );
      expect(
        r.rejected.every((ImportCandidate c) => c.reason.contains('CBZ/ZIP')),
        isTrue,
      );
    });

    test('未登记格式不会被猜成可导入', () {
      final ScanReport r = ImportScanner.scan(<String>['/x/a.xyz', '/x/b.unknown']);
      expect(r.unsupportedCount, 2);
      expect(r.unsupported.first.reason, LegalTexts.importUnsupportedReason);
      expect(r.unsupported.first.format, 'XYZ');
    });

    test('去重 + 自然排序：001 / 002 / 010 不乱序', () {
      final ScanReport r = ImportScanner.scan(<String>[
        '/a/010.txt', '/a/002.txt', '/a/001.txt', '/a/001.txt',
      ]);
      expect(r.total, 3);
      expect(r.candidates.map((ImportCandidate c) => c.title).toList(),
          <String>['001', '002', '010']);
    });

    test('byFormat 统计与不可变视图', () {
      final ScanReport r = ImportScanner.scan(<String>['/a.txt', '/b.TXT', '/c.pdf']);
      expect(r.byFormat['TXT'], 2);
      expect(r.byFormat['PDF'], 1);
      expect(() => r.byFormat['X'] = 9, throwsUnsupportedError);
      expect(() => r.accepted.add(r.candidates.first), throwsUnsupportedError);
    });

    test('漫画判据复用 BookSummary.comicFormats', () {
      final ScanReport r = ImportScanner.scan(<String>['/a.cbz', '/a.pdf', '/a.txt']);
      expect(r.candidates[0].looksComic, isTrue);
      expect(r.candidates[1].looksComic, isFalse, reason: 'PDF 是栅格化但不是漫画');
      expect(r.candidates[2].looksComic, isFalse);
      expect(BookSummary.comicFormats.contains('CBZ'), isTrue);
    });

    test('draftId 稳定且与路径无关', () {
      final ImportCandidate a = ImportScanner.scan(<String>['/x/同一本书.txt']).candidates.first;
      final ImportCandidate b = ImportScanner.scan(<String>['/y/同一本书.epub']).candidates.first;
      expect(a.draftId, b.draftId);
      expect(a.draftId, startsWith('imp-'));
    });

    test('normalize 去空格 / 大小写 / 常见分隔符', () {
      expect(ImportScanner.normalize('雪国 的旅行者'),
          ImportScanner.normalize('雪国的旅行者'));
      expect(ImportScanner.normalize('Vol_02'), ImportScanner.normalize('vol02'));
    });
  });

  group('冲突检测', () {
    test('演示路径与演示书库产生 5 项同名冲突', () {
      final ScanReport r = ImportScanner.scan(ImportDemoPaths.base);
      final List<ImportConflict> c = ImportScanner.conflicts(r, demoExisting());
      expect(c.length, 5);
      expect(c.every((ImportConflict x) => !x.resolved), isTrue);
      expect(c.map((ImportConflict x) => x.existing.id).toSet(),
          <String>{'b01', 'b03', 'b06', 'b10', 'b11'});
    });

    test('被拒 / 未登记项不占用冲突决策名额', () {
      final ScanReport r = ImportScanner.scan(<String>[
        '/x/雪国的旅行者.txt', '/x/加密备份.zip', '/x/a.xyz',
      ]);
      expect(ImportScanner.conflicts(r, demoExisting()).length, 1);
    });

    test('无同名时返回空列表', () {
      final ScanReport r = ImportScanner.scan(<String>['/x/全新短篇.txt']);
      expect(ImportScanner.conflicts(r, demoExisting()), isEmpty);
    });
  });

  group('ImportDemoPaths 授权方式', () {
    test('三种方式都在 base 基础上扩展', () {
      for (final ImportPermissionMode m in ImportPermissionMode.values) {
        final List<String> p = ImportDemoPaths.forMode(m);
        expect(p.length, greaterThanOrEqualTo(ImportDemoPaths.base.length));
        for (final String b in ImportDemoPaths.base) {
          expect(p.contains(b), isTrue);
        }
      }
    });

    test('文档选择器额外给云盘路径，全文件访问给公共目录', () {
      expect(ImportDemoPaths.forMode(ImportPermissionMode.documentPicker).length,
          ImportDemoPaths.base.length + 2);
      expect(ImportDemoPaths.forMode(ImportPermissionMode.allFiles).last,
          contains('/sdcard/Download'));
    });
  });

  group('ImportSession 步骤状态机', () {
    test('初始 intro，canAdvance 为真', () {
      const ImportSession s = ImportSession();
      expect(s.step, ImportStep.intro);
      expect(s.isFirst, isTrue);
      expect(s.canAdvance, isTrue);
    });

    test('permission 未选方式 / 未授权时不可推进且给可执行提示', () {
      const ImportSession s = ImportSession(step: ImportStep.permission);
      expect(s.canAdvance, isFalse);
      expect(s.blockingHint, LegalTexts.importNoModeHint);
      final ImportSession chosen = s.chooseMode(ImportPermissionMode.saf);
      expect(chosen.canAdvance, isFalse);
      expect(chosen.blockingHint, LegalTexts.importNoGrantHint);
      expect(chosen.grant().canAdvance, isTrue);
    });

    test('换授权方式会清空旧扫描结果与决策', () {
      final ImportSession s = scanned();
      expect(s.report, isNotNull);
      expect(s.conflicts, isNotEmpty);
      final ImportSession changed = s.chooseMode(ImportPermissionMode.allFiles);
      expect(changed.granted, isFalse);
      expect(changed.report, isNull);
      expect(changed.conflicts, isEmpty);
      expect(changed.mode, ImportPermissionMode.allFiles);
    });

    test('advance 各步顺序，授权步一次性生成报告与冲突', () {
      final List<ExistingBook> e = demoExisting();
      ImportSession s = const ImportSession().advance(existing: e);
      expect(s.step, ImportStep.permission);
      s = s.chooseMode(ImportPermissionMode.saf).grant().advance(existing: e);
      expect(s.step, ImportStep.scan);
      expect(s.report!.total, 11);
      expect(s.conflicts.length, 5);
      s = s.advance(existing: e);
      expect(s.step, ImportStep.conflicts);
      expect(s.canAdvance, isFalse, reason: '还有未决策冲突');
      expect(s.blockingHint, contains('5 项冲突'));
    });

    test('空扫描结果不可推进且提示不是「换关键词」', () {
      const ImportSession s = ImportSession(
        step: ImportStep.scan,
        report: ScanReport(<ImportCandidate>[]),
      );
      expect(s.canAdvance, isFalse);
      expect(s.blockingHint, LegalTexts.importScanEmpty);
    });

    test('back 回授权页清空报告，回扫描页保留决策', () {
      final ImportSession s = scanned();
      final ImportSession backFromScan = s.back();
      expect(backFromScan.step, ImportStep.permission);
      expect(backFromScan.report, isNull);
      expect(backFromScan.conflicts, isEmpty);

      final ImportSession resolved = s.resolveAll(ConflictResolution.skip);
      final ImportSession backFromDone = resolved
          .advance(existing: demoExisting()) // scan → conflicts
          .advance(existing: demoExisting()) // conflicts → done
          .back();
      expect(backFromDone.step, ImportStep.conflicts);
      expect(backFromDone.report, isNotNull);
      expect(backFromDone.conflicts.every((ImportConflict c) => c.resolved), isTrue);
    });

    test('done 不能继续 advance', () {
      final ImportSession done = scanned()
          .resolveAll(ConflictResolution.skip)
          .advance(existing: demoExisting())
          .advance(existing: demoExisting());
      expect(done.step, ImportStep.done);
      expect(done.canAdvance, isFalse);
      expect(done.advance(existing: demoExisting()).step, ImportStep.done);
    });

    test('批量决策后仍可单条覆盖', () {
      ImportSession s = scanned().resolveAll(ConflictResolution.skip);
      expect(s.conflicts.every((ImportConflict c) => c.resolution == ConflictResolution.skip), isTrue);
      s = s.resolve(1, ConflictResolution.keepBoth);
      expect(s.conflicts[0].resolution, ConflictResolution.skip);
      expect(s.conflicts[1].resolution, ConflictResolution.keepBoth);
      expect(s.unresolvedCount, 0);
    });

    test('越界 resolve 返回原对象', () {
      final ImportSession s = scanned();
      expect(s.resolve(99, ConflictResolution.skip), same(s));
      expect(s.resolve(-1, ConflictResolution.skip), same(s));
    });

    test('markCommitted 只标记，不改报告', () {
      final ImportSession s = scanned();
      final ImportSession c = s.markCommitted();
      expect(c.committed, isTrue);
      expect(c.report, same(s.report));
    });
  });

  group('ImportCommit 提交摘要', () {
    test('未决策冲突按跳过处理：只新增无同名的 3 册', () {
      final ImportCommit c = scanned().commit();
      expect(c.totalCandidates, 11);
      expect(c.conflictCount, 5);
      expect(c.addedCount, 3);
      expect(c.skipped, 5);
      expect(c.unsupported, 3);
      expect(c.deferredCount, 0);
      expect(c.added.map((ImportBookDraft d) => d.title),
          containsAll(<String>['雨街短篇集', '校勘笔记', '旧刊合辑']));
    });

    test('keepBoth 生成副本 id 与副本标题', () {
      final ImportCommit c = scanned()
          .resolveAll(ConflictResolution.keepBoth)
          .commit();
      expect(c.addedCount, 8);
      expect(c.skipped, 0);
      final List<ImportBookDraft> copies = c.added
          .where((ImportBookDraft d) => d.title.contains('导入副本'))
          .toList();
      expect(copies.length, 5);
      expect(copies.every((ImportBookDraft d) => d.id.endsWith('-copy')), isTrue);
    });

    test('replace / mergeRecords 记为延后，不写演示书库', () {
      final ImportCommit a = scanned()
          .resolveAll(ConflictResolution.replace)
          .commit();
      final ImportCommit b = scanned()
          .resolveAll(ConflictResolution.mergeRecords)
          .commit();
      for (final ImportCommit c in <ImportCommit>[a, b]) {
        expect(c.deferredCount, 5);
        expect(c.addedCount, 3);
        expect(c.skipped, 5);
      }
    });

    test('existingIds 命中时跳过，避免重复导入', () {
      final ImportSession s = scanned().resolveAll(ConflictResolution.keepBoth);
      final String id = s.report!.accepted.first.draftId;
      final ImportCommit c = s.commit(existingIds: <String>{id});
      expect(c.addedCount, 7);
      expect(c.skipped, 1);
    });

    test('无报告时返回空提交，不抛异常', () {
      final ImportCommit c = const ImportSession(step: ImportStep.done).commit();
      expect(c.isEmpty, isTrue);
      expect(c.totalCandidates, 0);
    });

    test('commit 是纯函数：同一 session 多次调用结果一致', () {
      final ImportSession s = scanned().resolveAll(ConflictResolution.keepBoth);
      expect(s.commit().addedCount, s.commit().addedCount);
      expect(s.commit().added.first.id, s.commit().added.first.id);
    });
  });

  group('AppState 写回内存书库', () {
    AppState make() => AppState(
          settingsStore: InMemorySettingsStore(),
          books: const DemoBookRepository(),
        );

    ImportCommit keepBothCommit() =>
        scanned().resolveAll(ConflictResolution.keepBoth).commit();

    test('applyImport 后 library / shelfCounts / emptyKind 都包含新书', () {
      final AppState s = make();
      expect(s.library().length, 11);
      final ImportCommit c = keepBothCommit();
      expect(s.applyImport(c), 8);
      expect(s.library().length, 19);
      expect(s.shelfCounts()['本地书库'], greaterThan(0));
      expect(s.importedCount, 8);
      expect(s.allBooks.length, 19);
      expect(s.emptyKind(matched: 0, query: ''), LibraryEmptyKind.noLibrary,
          reason: '既有口径：有数据却零命中且无关键词，按数据异常处理');
    });

    test('演示仓储保持只读：cached 仍是 11 册', () {
      final AppState s = make();
      s.applyImport(keepBothCommit());
      expect(s.books.cached.length, 11);
      expect(s.books.byId('b01')!.title, '雪国的旅行者');
    });

    test('重复导入幂等，第二次返回 0', () {
      final AppState s = make();
      final ImportCommit c = keepBothCommit();
      expect(s.applyImport(c), 8);
      expect(s.applyImport(c), 0);
      expect(s.importedCount, 8);
    });

    test('resolveBook 能找到导入书，详情页与收藏跳转不会显示「已移除」', () {
      final AppState s = make();
      final ImportCommit c = keepBothCommit();
      s.applyImport(c);
      for (final ImportBookDraft d in c.added) {
        final BookSummary? found = s.resolveBook(d.id);
        expect(found, isNotNull);
        expect(found!.title, d.title);
      }
      expect(s.resolveBook('不存在'), isNull);
    });

    test('导入书参与书库搜索与自然排序', () {
      final AppState s = make();
      s.applyImport(keepBothCommit());
      final List<BookSummary> hits = s.library(query: '雨街');
      expect(hits.any((BookSummary b) => b.title == '雨街短篇集'), isTrue);
      expect(LibraryQuery.naturalCompare('第 2 卷', '第 10 卷'), lessThan(0));
    });

    test('导入书也套用元数据覆盖层', () {
      final AppState s = make();
      final ImportCommit c = keepBothCommit();
      s.applyImport(c);
      final String id = c.added.first.id;
      s.updateBook(id, title: '改过名的导入书');
      expect(s.library().any((BookSummary b) => b.title == '改过名的导入书'), isTrue);
    });

    test('deferred 决策不产生任何写入', () {
      final AppState s = make();
      final ImportCommit c = scanned()
          .resolveAll(ConflictResolution.replace)
          .commit();
      expect(c.deferredCount, 5);
      expect(s.applyImport(c), 3);
      expect(s.importedCount, 3);
    });

    test('导入过程不改变纯本地 master switch', () {
      final AppState s = make();
      s.applyImport(keepBothCommit());
      expect(s.settings.pureLocal, isTrue);
      expect(s.networkingAllowed, isFalse);
    });
  });
}
