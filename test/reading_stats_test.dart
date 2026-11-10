import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/data/book_repository.dart';
import 'package:local_reader/core/state/app_scope.dart';
import 'package:local_reader/core/state/app_settings.dart';
import 'package:local_reader/core/state/reader_style.dart';
import 'package:local_reader/core/stats/reading_stats.dart';
import 'package:local_reader/core/theme/design_tokens.dart';
import 'package:local_reader/core/theme/season_scheme.dart';

void main() {
  group('五种季节手账的明暗对照', () {
    test('每一季都有 light / dark 两套色板', () {
      expect(SeasonSchemes.all.length, 5);
      for (final SeasonStyle s in SeasonSchemes.styles) {
        final SeasonScheme scheme = SeasonSchemes.of(s);
        expect(scheme.light.label, isNotEmpty);
        expect(scheme.dark.label, isNotEmpty);
        expect(scheme.light.shelfWood.length, 2);
        expect(scheme.dark.shelfWood.length, 2);
        expect(scheme.dark.glassTint.length, 2);
      }
    });

    test('深色底比浅色底暗（WCAG 相对亮度）', () {
      for (final SeasonStyle s in SeasonSchemes.styles) {
        final SeasonScheme scheme = SeasonSchemes.of(s);
        expect(
          ReaderStyle.relativeLuminance(scheme.dark.seed),
          lessThan(ReaderStyle.relativeLuminance(scheme.light.seed)),
          reason: '${scheme.light.label} 的深色变体必须真的更暗',
        );
      }
    });

    test('resolve 按 Brightness 取对应色板', () {
      for (final SeasonStyle s in SeasonSchemes.styles) {
        expect(SeasonSchemes.resolve(s, Brightness.light), SeasonSchemes.of(s).light);
        expect(SeasonSchemes.resolve(s, Brightness.dark), SeasonSchemes.of(s).dark);
      }
    });

    test('五种深色各自不同，深色模式下不会丢失辨识度', () {
      final Set<Color> seeds = SeasonSchemes.styles
          .map<Color>((SeasonStyle s) => SeasonSchemes.of(s).dark.seed)
          .toSet();
      final Set<Color> accents = SeasonSchemes.styles
          .map<Color>((SeasonStyle s) => SeasonSchemes.of(s).dark.accent)
          .toSet();
      expect(seeds.length, 5);
      expect(accents.length, 5);
    });

    test('深色 accent 在深色底上对比度 ≥ 3（图形 / 大字元素）', () {
      for (final SeasonStyle s in SeasonSchemes.styles) {
        final SeasonPalette p = SeasonSchemes.of(s).dark;
        expect(
          ReaderStyle.contrastRatio(p.seed, p.accent),
          greaterThanOrEqualTo(3.0),
          reason: '${p.label} 的强调色在深底上看不清',
        );
      }
    });

    test('preview 可强制指定明暗，不跟随系统', () {
      expect(
        SeasonSchemes.preview(SeasonStyle.sakura, brightness: Brightness.dark),
        SeasonSchemes.of(SeasonStyle.sakura).dark,
      );
    });
  });

  group('统计聚合口径', () {
    StatsSnapshot snap() => DemoStatsRepository(today: DateTime.utc(2026, 11, 9)).snapshot();

    test('热力分级边界固定', () {
      expect(StatsSnapshot.heatmapLevel(0), 0);
      expect(StatsSnapshot.heatmapLevel(1), 1);
      expect(StatsSnapshot.heatmapLevel(14), 1);
      expect(StatsSnapshot.heatmapLevel(15), 2);
      expect(StatsSnapshot.heatmapLevel(29), 2);
      expect(StatsSnapshot.heatmapLevel(30), 3);
      expect(StatsSnapshot.heatmapLevel(59), 3);
      expect(StatsSnapshot.heatmapLevel(60), 4);
      expect(StatsSnapshot.heatmapLevel(999), 4);
    });

    test('时长格式化', () {
      expect(StatsSnapshot.formatMinutes(0), '0 分钟');
      expect(StatsSnapshot.formatMinutes(46), '46 分钟');
      expect(StatsSnapshot.formatMinutes(120), '2 小时');
      expect(StatsSnapshot.formatMinutes(200), '3 小时 20 分');
    });

    test('35 天热力、最近 7 天日历、最后一格是基准日', () {
      final StatsSnapshot s = snap();
      expect(s.days.length, 35);
      expect(s.calendarWeek.length, 7);
      expect(s.days.last.date, DateTime.utc(2026, 11, 9));
      expect(s.days.last.key, '2026-11-09');
      expect(s.today, s.days.last.minutes);
    });

    test('连续天数从今天往回数，中断即停', () {
      final StatsSnapshot s = snap();
      expect(s.streakDays, 5, reason: '演示数据最后五天 47/92/26/61/46 分钟，第六天为 0 中断');
    });

    test('本周合计与总页数、目标进度', () {
      final StatsSnapshot s = snap();
      expect(s.weekMinutes, 47 + 92 + 26 + 61 + 46 + 14 + 0);
      expect(s.totalPages, greaterThan(0));
      expect(s.progress, closeTo(46 / 60, 0.0001));
    });

    test('目标为 0 时进度不为 NaN/Infinity', () {
      final StatsSnapshot s = StatsSnapshot(
        today: 10,
        goalMinutes: 0,
        days: <ReadingDay>[ReadingDay(date: DateTime.utc(2026, 11, 9), minutes: 10)],
        excerpts: const <Excerpt>[],
        totalBooks: 0,
      );
      expect(s.progress, 0);
    });

    test('固定基准日让两次快照完全一致（不随真机时间漂移）', () {
      final StatsSnapshot a = snap();
      final StatsSnapshot b = snap();
      expect(a.days.map((ReadingDay d) => d.key).toList(), b.days.map((ReadingDay d) => d.key).toList());
      expect(a.today, b.today);
      expect(a.streakDays, b.streakDays);
    });
  });

  group('摘录卡环形切换', () {
    final List<Excerpt> excerpts = DemoStatsRepository().snapshot().excerpts;

    test('next 到末尾后回到第一条', () {
      ExcerptCycler c = ExcerptCycler(excerpts);
      for (int i = 0; i < excerpts.length; i++) {
        c = c.next();
      }
      expect(c.index, 0);
      expect(c.current!.id, excerpts.first.id);
    });

    test('previous 从 0 回到最后一条', () {
      final ExcerptCycler c = ExcerptCycler(excerpts).previous();
      expect(c.index, excerpts.length - 1);
    });

    test('select 越界被夹住', () {
      expect(ExcerptCycler(excerpts).select(99).index, excerpts.length - 1);
      expect(ExcerptCycler(excerpts).select(-5).index, 0);
    });

    test('空列表不崩溃，current 为 null', () {
      final ExcerptCycler c = ExcerptCycler(const <Excerpt>[]);
      expect(c.isEmpty, isTrue);
      expect(c.hasMultiple, isFalse);
      expect(c.current, isNull);
      expect(c.next().index, 0);
    });
  });

  group('小组件配置', () {
    test('五种内容、三档尺寸都有标签与图标', () {
      expect(WidgetSpecLabels.content.length, WidgetContent.values.length);
      expect(WidgetSpecLabels.size.length, WidgetSize.values.length);
      expect(WidgetSpecLabels.icon.length, WidgetContent.values.length);
    });

    test('copyWith 不修改原对象且值相等可用', () {
      const WidgetSpec a = WidgetSpec(id: 'w1');
      final WidgetSpec b = a.copyWith(content: WidgetContent.heatmap, size: WidgetSize.large);
      expect(a.content, WidgetContent.today);
      expect(b.content, WidgetContent.heatmap);
      expect(b.size, WidgetSize.large);
      expect(a == a.copyWith(), isTrue);
      expect(a, isNot(b));
    });

    test('toMap / fromMap 往返一致，未知枚举回退默认', () {
      const WidgetSpec s = WidgetSpec(
        id: 'w2',
        content: WidgetContent.excerpt,
        size: WidgetSize.medium,
        season: SeasonStyle.autumn,
        showProgress: false,
      );
      expect(WidgetSpec.fromMap(s.toMap()), s);
      final WidgetSpec fallback = WidgetSpec.fromMap(<dynamic, dynamic>{
        'id': 'w3',
        'content': 'unknown',
        'size': 'huge',
      });
      expect(fallback.content, WidgetContent.today);
      expect(fallback.size, WidgetSize.small);
      expect(fallback.season, SeasonStyle.paper);
    });

    test('AppState 支持多个小组件独立配置与增删', () {
      final AppState state = AppState(
        settingsStore: InMemorySettingsStore(),
        books: const DemoBookRepository(),
      );
      expect(state.widgetSpecs.length, 2);
      expect(() => state.widgetSpecs.add(const WidgetSpec(id: 'x')), throwsUnsupportedError,
          reason: '暴露出去的列表必须不可变');

      final WidgetSpec added = state.addWidgetSpec();
      expect(state.widgetSpecs.length, 3);
      expect(state.widgetSpecs.map((WidgetSpec s) => s.id).toSet().length, 3);

      state.updateWidgetSpec(added.copyWith(content: WidgetContent.calendar, season: SeasonStyle.summer));
      expect(state.widgetSpecs.last.content, WidgetContent.calendar);
      expect(state.widgetSpecs.last.season, SeasonStyle.summer);

      state.removeWidgetSpec(added.id);
      expect(state.widgetSpecs.length, 2);
      state.resetWidgetSpecs();
      expect(state.widgetSpecs.length, 2);
      expect(state.widgetSpecs.first.content, WidgetContent.today);
    });
  });
}
