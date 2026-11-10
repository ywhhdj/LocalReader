import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/stats/reading_stats.dart';
import 'package:local_reader/core/stats/stats_views.dart';

StatsSnapshot snapshot({
  int today = 40,
  int goal = 60,
  List<ReadingDay>? days,
  List<Excerpt> excerpts = const <Excerpt>[],
  int books = 11,
}) =>
    StatsSnapshot(
      today: today,
      goalMinutes: goal,
      days: days ??
          <ReadingDay>[
            ReadingDay(date: DateTime.utc(2026, 11, 9), minutes: 40, pages: 12),
          ],
      excerpts: excerpts,
      totalBooks: books,
    );

void main() {
  group('八种报告布局', () {
    test('布局数恰好 8，且每种都有字段组合', () {
      expect(ReportLayout.values.length, 8);
      expect(ReportPayload.layoutSections.length, 8);
      for (final ReportLayout l in ReportLayout.values) {
        expect(ReportPayload.layoutSections[l], isNotEmpty);
        expect(ReportPayload.layoutLabels[l], isNotNull);
      }
    });

    test('无数据的字段被省略，页面与导出读同一份 sections', () {
      final ReportPayload p = ReportPayload.build(
        layout: ReportLayout.classic,
        period: const StatsPeriod(),
        snapshot: snapshot(excerpts: const <Excerpt>[], books: 0),
      );
      expect(p.sections, isNot(contains(ReportSection.excerpts)));
      expect(p.sections, isNot(contains(ReportSection.companion)));
      expect(p.render(), isNot(contains('【摘录】')));
    });

    test('预览与导出共用 render()，不拼第二份文本', () {
      final ReportPayload p = ReportPayload.build(
        layout: ReportLayout.journal,
        period: const StatsPeriod(kind: StatsPeriodKind.week),
        snapshot: snapshot(),
      );
      final String a = p.render();
      final String b = p.render();
      expect(a, b);
      expect(a, contains('阅读报告'));
      expect(a, contains('本周'));
    });

    test('五种视图词表一一对应', () {
      expect(ReportPayload.viewLabels.length, StatsViewKind.values.length);
    });
  });

  group('周期归一化', () {
    test('非自定义周期丢弃残留范围', () {
      final StatsPeriod p = const StatsPeriod(
          kind: StatsPeriodKind.week,
          from: '2026-11-01',
          to: '2026-11-09').normalized();
      expect(p.from, isNull);
      expect(p.to, isNull);
    });

    test('起止倒置时自动交换，不产生永远空结果', () {
      final StatsPeriod p = const StatsPeriod(
          kind: StatsPeriodKind.custom,
          from: '2026-11-09',
          to: '2026-11-01').normalized();
      expect(p.from, '2026-11-01');
      expect(p.to, '2026-11-09');
      expect(p.contains('2026-11-05'), isTrue);
      expect(p.contains('2026-10-31'), isFalse);
    });

    test('非法日期回落整月，不把脏 key 塞进筛选', () {
      final StatsPeriod p = const StatsPeriod(
          kind: StatsPeriodKind.custom,
          from: '2026-02-30',
          to: '2026-03-01').normalized();
      expect(p.kind, StatsPeriodKind.month);
      expect(p.from, isNull);
    });
  });

  group('按书视图', () {
    test('从同一个快照聚合，不新造演示数据', () {
      final StatsSnapshot s = snapshot(books: 7);
      final BookStatsSummary b = BookStatsSummary.fromSnapshot(s);
      expect(b.totalBooks, 7);
      expect(b.hasData, isTrue);
    });
  });
}
