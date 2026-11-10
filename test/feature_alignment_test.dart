import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/backup/webdav_backup.dart';
import 'package:local_reader/core/data/book_repository.dart';
import 'package:local_reader/core/data/shelf_prefs.dart';
import 'package:local_reader/core/import/import_review.dart';
import 'package:local_reader/core/import/import_session.dart';
import 'package:local_reader/core/parser/book_parser.dart';
import 'package:local_reader/core/models/book_document.dart';
import 'package:local_reader/core/platform/android_permissions.dart';
import 'package:local_reader/core/platform/crash_guard.dart';
import 'package:local_reader/core/profile/profile_summary.dart';
import 'package:local_reader/core/reader/bilingual_prefs.dart';
import 'package:local_reader/core/reader/illustration_view.dart';
import 'package:local_reader/core/reader/reading_search.dart';
import 'package:local_reader/core/router/route_args.dart';
import 'package:local_reader/core/stats/excerpt_day_view.dart';
import 'package:local_reader/core/stats/range_calendar_link.dart';
import 'package:local_reader/core/stats/reading_stats.dart';
import 'package:local_reader/core/stats/stats_date.dart';

BookSummary book(String id, {double progress = 0.5, String shelf = '最近阅读'}) =>
    BookSummary(
      id: id,
      title: '书 $id',
      author: '作者',
      spineColor: const Color(0xFF6E8CA8),
      shelf: shelf,
      progress: progress,
    );

void main() {
  group('书架视图与筛选', () {
    test('列表模式锁回轮播参数，不留「设了没反应」', () {
      final ShelfPrefs p = const ShelfPrefs(
          inertialSnapping: true, haptics: true, loop: true)
          .copyWith(mode: ShelfViewMode.list)
          .normalized();
      expect(p.mode, ShelfViewMode.list);
      expect(p.inertialSnapping, isFalse);
      expect(p.haptics, isFalse);
      expect(p.loop, isFalse);
    });

    test('按阅读状态 / 来源 / 分类三条件同时生效', () {
      final List<BookSummary> books = <BookSummary>[
        book('local-1', progress: 0),
        book('local-2', progress: 0.4),
        book('cloud-3', progress: 1),
        book('cloud-4', progress: 0.6, shelf: '本地书库'),
      ];
      final ShelfPrefs p = const ShelfPrefs(
        status: ReadingStatusFilter.reading,
        source: BookSourceFilter.cloud,
        category: '本地书库',
      );
      expect(p.apply(books).length, 1);
      expect(p.apply(books).single.id, 'cloud-4');
      expect(p.hasFilters, isTrue);
    });

    test('clearCategory 显式清空，不靠 null 混淆', () {
      final ShelfPrefs p = const ShelfPrefs(category: 'A').copyWith(
        clearCategory: true,
      );
      expect(p.category, '');
      expect(p.hasFilters, isFalse);
    });
  });

  group('导入前审阅', () {
    test('三种来源与三种策略词表齐备', () {
      expect(ImportReview.sourceLabels.length, ImportSourceKind.values.length);
      expect(ImportReview.policyLabels.length, VolumeMergePolicy.values.length);
    });

    test('策略落到既有冲突策略，不新造第四种', () {
      expect(const ImportReview().withPolicy(VolumeMergePolicy.keepSeparate).resolution,
          ConflictResolution.keepBoth);
      expect(const ImportReview().withPolicy(VolumeMergePolicy.mergeBySeries).resolution,
          ConflictResolution.mergeRecords);
      expect(const ImportReview().withPolicy(VolumeMergePolicy.askEach).resolution,
          ConflictResolution.skip);
    });

    test('同系列卷按「第 N 卷」前缀归组，不改书名', () {
      final ImportReview r = ImportReview.fromScan(
        ScanReport(<ImportCandidate>[
          ImportCandidate(path: '/a.txt', title: '雪国 第一卷', format: 'TXT',
              route: RenderRoute.dartText, status: CandidateStatus.accepted),
          ImportCandidate(path: '/b.txt', title: '雪国 第二卷', format: 'TXT',
              route: RenderRoute.dartText, status: CandidateStatus.accepted),
          ImportCandidate(path: '/c.rar5', title: '被拒绝', format: 'RAR5',
              route: RenderRoute.nativeRaster, status: CandidateStatus.rejected),
        ]),
      );
      expect(r.items.length, 2, reason: '被拒项不占审阅名额');
      expect(r.bySeries.length, 1);
      expect(r.selectedCount, 2);
    });
  });

  group('备份状态机', () {
    test('默认关闭，关闭态任何动作都不产生状态迁移', () {
      const BackupSnapshot b = BackupSnapshot();
      expect(b.enabled, isFalse);
      expect(b.state, BackupState.disabled);
      for (final BackupAction a in BackupSnapshot.actions) {
        expect(b.dispatch(a).state, BackupState.disabled);
      }
    });

    test('归一化丢弃关闭态残留的远端列表与结果', () {
      final BackupSnapshot b = const BackupSnapshot(
        enabled: false,
        state: BackupState.ok,
        remoteEntries: <String>['a'],
        lastResult: '残留',
      ).normalized();
      expect(b.remoteEntries, isEmpty);
      expect(b.lastResult, '');
      expect(b.state, BackupState.disabled);
    });

    test('备份清单恰好四项，与 README 一致', () {
      expect(BackupSnapshot.payloadLabels.length, 4);
    });
  });

  group('章内 / 全书搜索', () {
    BookDocument doc() => BookDocument(
          id: 'd',
          title: '演示',
          author: '',
          sourcePath: '/d.txt',
          sourceFormat: SourceFormat.txt,
          chapters: <Chapter>[
            const Chapter(id: 'c0', title: '一', ordinal: 0,
                blocks: <ContentBlock>[
                  ContentBlock(kind: BlockKind.paragraph, text: '雪国的旅行者到了雪国。'),
                ]),
            const Chapter(id: 'c1', title: '二', ordinal: 1,
                blocks: <ContentBlock>[
                  ContentBlock(kind: BlockKind.paragraph, text: '又是雪国，安静的雪国。'),
                ]),
          ],
        );

    test('空词不把整章误报成全命中', () {
      expect(ReadingSearch.search(doc(), '  ').isEmpty, isTrue);
    });

    test('章内只搜当前章，全书搜所有章', () {
      expect(ReadingSearch.search(doc(), '雪国', chapterIndex: 0).byChapter.length, 1);
      final ReadingSearchResult all = ReadingSearch.search(
          doc(), '雪国', scope: ReadingSearchScope.book);
      expect(all.byChapter.length, 2);
      expect(all.count, 4);
    });

    test('命中坐标是章号 + 块号，不硬编码页码', () {
      final ReadingSearchHit h = ReadingSearch.search(doc(), '安静').hits.single;
      expect(h.anchor, 'c1-b0');
      expect(h.snippet, contains('安静'));
    });
  });

  group('双语与插图', () {
    test('没有匹配语音模型的语言直接跳过，不回落别的语言', () {
      final BilingualPrefs b = const BilingualPrefs(
        spokenLanguages: <ReadingLanguage>[
          ReadingLanguage.zhCn, ReadingLanguage.ja,
        ],
        voices: <VoiceAssignment>[
          VoiceAssignment(language: ReadingLanguage.zhCn, voiceId: 'zh-1'),
        ],
      );
      expect(b.speakable(), <ReadingLanguage>[ReadingLanguage.zhCn]);
    });

    test('捏合缩放夹在区间，保存确认成功失败都有文案', () {
      expect(const IllustrationZoom().pinch(99).scale, 4.0);
      expect(const IllustrationZoom().pinch(0).scale, 1.0);
      expect(const IllustrationZoom().pinch(2).reset().isZoomed, isFalse);
      for (final IllustrationSaveState s in IllustrationSaveState.values) {
        final IllustrationSaveResult r = IllustrationSaveResult(s);
        if (s != IllustrationSaveState.idle) {
          expect(r.confirmation, isNotEmpty);
        }
      }
    });
  });

  group('权限分级与连续崩溃保护', () {
    test('13+ 与 12- 媒体权限二选一，且不含已移除的三项', () {
      const AndroidPermissionProfile p33 = AndroidPermissionProfile(33);
      const AndroidPermissionProfile p31 = AndroidPermissionProfile(31);
      expect(p33.requiredPermissions(), contains(AndroidPermissionProfile.readMediaImages));
      expect(p33.requiredPermissions(),
          isNot(contains(AndroidPermissionProfile.readExternalStorage)));
      expect(p31.requiredPermissions(),
          contains(AndroidPermissionProfile.readExternalStorage));
      expect(p31.requestsRemovedPermission(p31.requiredPermissions()), isFalse);
      expect(AndroidPermissionProfile.removed.length, 3);
    });

    test('时间窗内连续三次进安全模式，窗外记录被剔除', () {
      CrashGuard g = const CrashGuard();
      g = g.record(1000).record(2000).record(3000);
      expect(g.recentCount, 3);
      expect(g.shouldEnterSafeMode, isTrue);
      final CrashGuard later = g.record(10 * 60 * 1000);
      expect(later.recentCount, 1);
      expect(later.shouldEnterSafeMode, isFalse);
      expect(CrashGuard.skippedInSafeMode, isNotEmpty);
    });
  });

  group('候选清单收口', () {
    test('按日视图把摘录与当天阅读记录合成一份', () {
      final StatsSnapshot s = StatsSnapshot(
        today: 30,
        goalMinutes: 60,
        days: <ReadingDay>[
          ReadingDay(date: DateTime.utc(2026, 11, 9), minutes: 30, pages: 8),
        ],
        excerpts: const <Excerpt>[],
        totalBooks: 1,
      );
      final ExcerptDayView v = ExcerptDayView.build(
        dateKey: '2026-11-09', allExcerpts: const <Excerpt>[], snapshot: s);
      expect(v.isValid, isTrue);
      expect(v.minutes, 30);
      expect(v.pages, 8);
      expect(v.hasExcerpts, isFalse);
      expect(v.summary, contains('8 页'));
      expect(ExcerptDayView.build(
        dateKey: '2026-02-30', allExcerpts: const <Excerpt>[], snapshot: s).isValid,
        isFalse);
    });

    test('范围反链定位起始月，非法范围回落 null', () {
      final CalendarMonthArgs? a = KeepsakeRangeLink.toCalendar(
          const DateKeyRange(from: '2026-10-20', to: '2026-11-09'));
      expect(a, isNotNull);
      expect(KeepsakeRangeLink.spansMonths(
          const DateKeyRange(from: '2026-10-20', to: '2026-11-09')), isTrue);
      expect(KeepsakeRangeLink.spansMonths(
          const DateKeyRange(from: '2026-11-01', to: '2026-11-09')), isFalse);
      expect(KeepsakeRangeLink.toCalendar(
          const DateKeyRange(from: '2026-02-30', to: '2026-03-01')), isNull);
      expect(KeepsakeRangeLink.toCalendar(null), isNull);
    });

    test('个人页摘要从 StatsSnapshot 聚合，零值字段被省略', () {
      final StatsSnapshot s = StatsSnapshot(
        today: 0,
        goalMinutes: 60,
        days: <ReadingDay>[ReadingDay(date: DateTime.utc(2026, 11, 9))],
        excerpts: const <Excerpt>[],
        totalBooks: 3,
      );
      final ProfileSummary p = ProfileSummary.fromSnapshot(s);
      expect(p.todayMinutes, 0);
      expect(p.visibleFields, isNot(contains(ProfileSummaryField.today)));
      expect(p.visibleFields, contains(ProfileSummaryField.books));
      expect(p.goalProgress, 0);
    });

    test('FeatureMatrixArgs 越界分组夹回 0', () {
      expect(const FeatureMatrixArgs(initialTab: 2).normalizedTab, 2);
      expect(const FeatureMatrixArgs(initialTab: 99).normalizedTab, 0);
      expect(const FeatureMatrixArgs(initialTab: -1).normalizedTab, 0);
    });
  });
}
