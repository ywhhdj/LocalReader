import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/state/app_settings.dart';
import 'package:local_reader/core/state/reader_style.dart';

/// 规格单测（静态交付模式下不运行）：锁定「背景亮度反推文字色、
/// 分页缓存键边界、设置归一化」三条容易出错的契约。
void main() {
  group('背景亮度反推文字色', () {
    test('纸白 / 米黄 / 护眼取深色字', () {
      for (final ReaderBackground bg in <ReaderBackground>[
        ReaderBackground.paper,
        ReaderBackground.cream,
        ReaderBackground.eyeCare,
      ]) {
        final Color on = ReaderStyle.onColor(ReaderStyle.backgroundColors[bg]!);
        expect(ReaderStyle.relativeLuminance(on), lessThan(0.2), reason: '$bg 应取深色字');
      }
    });

    test('夜间取浅色字', () {
      final Color on = ReaderStyle.onColor(ReaderStyle.backgroundColors[ReaderBackground.night]!);
      expect(ReaderStyle.relativeLuminance(on), greaterThan(0.6));
    });

    test('四档背景都满足 WCAG AA 正文对比度 4.5', () {
      for (final ReaderBackground bg in ReaderBackground.values) {
        final ReaderStyle s = ReaderStyle(background: bg);
        expect(s.bodyContrast, greaterThanOrEqualTo(4.5), reason: '${s.backgroundLabel} 对比度不足');
      }
    });

    test('相对亮度：黑接近 0、白接近 1', () {
      expect(ReaderStyle.relativeLuminance(const Color(0xFF000000)), closeTo(0, 0.001));
      expect(ReaderStyle.relativeLuminance(const Color(0xFFFFFFFF)), closeTo(1, 0.001));
    });

    test('contrastRatio 对称且黑白为 21:1', () {
      const Color black = Color(0xFF000000);
      const Color white = Color(0xFFFFFFFF);
      expect(ReaderStyle.contrastRatio(black, white), closeTo(21, 0.01));
      expect(ReaderStyle.contrastRatio(white, black), closeTo(21, 0.01));
    });
  });

  group('分页缓存键边界', () {
    const ReaderStyle base = ReaderStyle();

    test('字号变化触发重排', () {
      expect(base.copyWith(fontSize: 22).layoutKey, isNot(base.layoutKey));
    });

    test('行高 / 缩进 / 段距 / 孤儿行变化触发重排', () {
      expect(base.copyWith(lineHeight: 2.0).layoutKey, isNot(base.layoutKey));
      expect(base.copyWith(firstLineIndentEm: 0).layoutKey, isNot(base.layoutKey));
      expect(base.copyWith(paragraphSpacing: 1.0).layoutKey, isNot(base.layoutKey));
      expect(base.copyWith(orphanLines: 3).layoutKey, isNot(base.layoutKey));
    });

    test('换背景 / 换翻页动效 / 改语速都不触发重排', () {
      expect(base.copyWith(background: ReaderBackground.night).layoutKey, base.layoutKey);
      expect(base.copyWith(pageTurn: ReaderPageTurn.simulation).layoutKey, base.layoutKey);
      expect(base.copyWith(ttsRate: 1.8).layoutKey, base.layoutKey);
      expect(base.copyWith(keepScreenOn: true).layoutKey, base.layoutKey);
    });
  });

  group('toPaginationConfig 字段映射', () {
    test('字号、行高、缩进、段距、孤儿行逐项写入', () {
      const ReaderStyle s = ReaderStyle(
        fontSize: 21,
        lineHeight: 2.0,
        firstLineIndentEm: 3,
        paragraphSpacing: 0.8,
        orphanLines: 3,
        widowLines: 3,
      );
      final config = s.toPaginationConfig(const Size(320, 520), const TextStyle());
      expect(config.fontSize, 21);
      expect(config.linePx, 42);
      expect(config.indentPx, 63);
      expect(config.paragraphGapPx, closeTo(42 * 0.8, 0.001));
      expect(config.orphanLines, 3);
      expect(config.widowLines, 3);
      expect(config.contentWidth, 320);
    });

    test('文字色由背景反推注入，页面层不必自己拼色', () {
      const ReaderStyle s = ReaderStyle(background: ReaderBackground.night);
      final config = s.toPaginationConfig(const Size(320, 520), const TextStyle(color: Colors.red));
      expect(config.textStyle.color, s.textColor);
    });
  });

  group('AppSettings 归一化', () {
    test('关闭界面动效时翻页动效被锁为 none', () {
      const AppSettings s = AppSettings(
        motion: false,
        reader: ReaderStyle(pageTurn: ReaderPageTurn.simulation),
      );
      expect(s.normalized().reader.pageTurn, ReaderPageTurn.none);
    });

    test('纯本地模式清零联网项，但保留阅读排版', () {
      const AppSettings s = AppSettings(
        pureLocal: true,
        onlineDirectory: true,
        webdav: true,
        reader: ReaderStyle(fontSize: 23, background: ReaderBackground.cream),
      );
      final AppSettings n = s.normalized();
      expect(n.onlineDirectory, isFalse);
      expect(n.webdav, isFalse);
      expect(n.networkingAllowed, isFalse);
      expect(n.reader.fontSize, 23);
      expect(n.reader.background, ReaderBackground.cream);
    });

    test('两条归一化规则可叠加生效', () {
      const AppSettings s = AppSettings(
        pureLocal: true,
        onlineDirectory: true,
        motion: false,
        reader: ReaderStyle(pageTurn: ReaderPageTurn.slide),
      );
      final AppSettings n = s.normalized();
      expect(n.onlineDirectory, isFalse);
      expect(n.reader.pageTurn, ReaderPageTurn.none);
    });

    test('值相等：同值不触发 AppState 无意义重建', () {
      const AppSettings a = AppSettings(reader: ReaderStyle(fontSize: 20));
      final AppSettings b = a.copyWith(motion: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const AppSettings(reader: ReaderStyle(fontSize: 21))));
    });
  });

  group('ReaderStyle 序列化与不可变性', () {
    test('toMap / fromMap 往返一致', () {
      const ReaderStyle s = ReaderStyle(
        fontSize: 22,
        lineHeight: 1.9,
        background: ReaderBackground.night,
        pageTurn: ReaderPageTurn.simulation,
        ttsRate: 1.5,
        ttsPitch: 0.8,
        keepScreenOn: true,
        volumeKeyTurnPage: true,
      );
      expect(ReaderStyle.fromMap(s.toMap()), s);
    });

    test('缺失字段与未知枚举回退默认，不抛异常', () {
      final ReaderStyle s = ReaderStyle.fromMap(<dynamic, dynamic>{
        'fontSize': 19,
        'background': 'not_a_background',
        'pageTurn': 'slide',
      });
      expect(s.fontSize, 19);
      expect(s.background, ReaderBackground.paper);
      expect(s.pageTurn, ReaderPageTurn.slide);
      expect(s.lineHeight, 1.75);
    });

    test('AppSettings.fromMap 能还原嵌套 reader', () {
      const AppSettings original = AppSettings(
        reader: ReaderStyle(fontSize: 24, background: ReaderBackground.eyeCare),
      );
      final AppSettings back = AppSettings.fromMap(original.toMap());
      expect(back.reader.fontSize, 24);
      expect(back.reader.background, ReaderBackground.eyeCare);
      expect(back.pureLocal, isTrue);
    });

    test('copyWith 不修改原对象', () {
      const ReaderStyle a = ReaderStyle();
      final ReaderStyle b = a.copyWith(fontSize: 26);
      expect(a.fontSize, 17);
      expect(b.fontSize, 26);
      expect(a.layoutKey, isNot(b.layoutKey));
    });
  });
}
