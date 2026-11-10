import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/state/font_catalog.dart';
import 'package:local_reader/core/state/reader_motion.dart';
import 'package:local_reader/core/state/reader_style.dart';
import 'package:local_reader/core/theme/color_source.dart';

void main() {
  group('字体目录', () {
    test('内置字体不可移除，按需包默认未安装', () {
      expect(FontCatalog.initial.byId('builtin-serif')!.isRemovable, isFalse);
      expect(FontCatalog.initial.byId('dl-serif-sc')!.state,
          FontInstallState.notInstalled);
      expect(FontCatalog.initial.remove('builtin-serif'),
          same(FontCatalog.initial));
    });

    test('导入只登记元数据、不预装；TTF/OTF 可扩展名', () {
      final FontCatalog c = FontCatalog.initial
          .addImported('思源黑体', const <String>['ttf', 'otf']);
      final FontResource f = c.fonts.last;
      expect(f.origin, FontOrigin.imported);
      expect(f.isTtfOrOtf, isTrue);
      expect(f.state, FontInstallState.notInstalled);
    });

    test('移除正在使用的字体时回落内置，不留悬空 id', () {
      FontCatalog c = FontCatalog.initial
          .addImported('我的字体', const <String>['otf']);
      final String id = c.fonts.last.id;
      c = c.withState(id, FontInstallState.installed)
          .withSelection(const FontSelection().withRole(FontRole.reader, id));
      final FontCatalog removed = c.remove(id);
      expect(removed.byId(id), isNull);
      expect(removed.selection.readerFontId, 'builtin-serif');
    });

    test('应用字体与阅读器字体分别选，互不影响', () {
      final FontSelection s = const FontSelection()
          .withRole(FontRole.app, 'a')
          .withRole(FontRole.reader, 'r');
      expect(s.forRole(FontRole.app), 'a');
      expect(s.forRole(FontRole.reader), 'r');
    });
  });

  group('配色来源', () {
    test('三种来源各自裁决，系统动态色可注入平台 seed', () {
      const ColorSource sys = ColorSource();
      const Color accent = Color(0xFF123456);
      const Color cover = Color(0xFF654321);
      expect(sys.seedFor(platformDynamicSeed: accent), accent);
      expect(sys.seedFor(), const Color(0xFF6E8CA8));
      expect(sys.copyWith(kind: ColorSourceKind.customAccent, accent: accent)
          .seedFor(), accent);
      expect(sys.copyWith(kind: ColorSourceKind.fromCover, coverSeed: cover)
          .seedFor(), cover);
    });

    test('阅读器配色复用 ReaderStyle 的亮度反推，四档达 AA', () {
      for (final Color bg in ReaderStyle.backgroundColors.values) {
        final ReaderColorScheme s = ReaderColorScheme.derive(bg);
        expect(s.textColor, ReaderStyle.onColor(bg));
        expect(s.contrast, greaterThanOrEqualTo(4.5));
        expect(s.meetsMinimum, isTrue);
      }
    });

    test('不透明度夹在 0.5~1.0', () {
      expect(ReaderColorScheme.derive(const Color(0xFFFFFFFF), opacity: 0.1).opacity,
          0.5);
      expect(ReaderColorScheme.derive(const Color(0xFFFFFFFF), opacity: 2).opacity,
          1.0);
    });
  });

  group('动效归一化', () {
    test('关整体动效时锁为无动画、速度 1、停止自动阅读', () {
      const ReaderMotion m = ReaderMotion(
          transition: ReaderTransition.cover,
          turnSpeed: 1.8,
          autoRead: true,
          continuousChapter: true);
      final ReaderMotion n = m.normalized().copyWith(globalMotion: false).normalized();
      expect(n.transition, ReaderTransition.none);
      expect(n.turnSpeed, 1.0);
      expect(n.autoRead, isFalse);
      expect(n.isAutoReading, isFalse);
    });

    test('速度与自动阅读间隔都被夹在合法区间', () {
      final ReaderMotion n = const ReaderMotion(
          turnSpeed: 99, autoReadIntervalMs: 1).normalized();
      expect(n.turnSpeed, 2.0);
      expect(n.autoReadIntervalMs, 1500);
    });

    test('四种翻页词表与枚举一一对应', () {
      expect(ReaderMotion.labels.length, ReaderTransition.values.length);
      for (final ReaderTransition t in ReaderTransition.values) {
        expect(ReaderMotion.labels[t], isNotNull);
      }
    });
  });
}
