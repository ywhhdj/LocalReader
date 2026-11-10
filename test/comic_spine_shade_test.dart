import 'dart:ui' show Color, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/comic/comic_spread.dart';
import 'package:local_reader/core/state/reader_style.dart';

const Size portrait = Size(400, 800);

ComicSpreadLayout layout({int pages = 6}) => ComicSpreadResolver.build(
      pageCount: pages,
      mode: ComicSpreadMode.double,
      direction: ComicReadingDirection.ltr,
      pageSize: portrait,
    );

void main() {
  group('strengthFor：按槽宽自动选档', () {
    test('非正 / 窄槽 → subtle', () {
      expect(ComicSpreadGutter.strengthFor(0), ComicSpineShadeStrength.subtle);
      expect(ComicSpreadGutter.strengthFor(-1), ComicSpineShadeStrength.subtle);
      expect(
          ComicSpreadGutter.strengthFor(299), ComicSpineShadeStrength.subtle);
    });

    test('中间槽宽 → normal', () {
      expect(
          ComicSpreadGutter.strengthFor(300), ComicSpineShadeStrength.normal);
      expect(
          ComicSpreadGutter.strengthFor(400), ComicSpineShadeStrength.normal);
      expect(
          ComicSpreadGutter.strengthFor(699), ComicSpineShadeStrength.normal);
    });

    test('宽屏 → strong', () {
      expect(
          ComicSpreadGutter.strengthFor(700), ComicSpineShadeStrength.strong);
      expect(
          ComicSpreadGutter.strengthFor(1200), ComicSpineShadeStrength.strong);
    });

    test('阈值与 width() 上下限是独立常量，不混用', () {
      expect(ComicSpreadGutter.minWidthPx, 8.0);
      expect(ComicSpreadGutter.maxWidthPx, 28.0);
      expect(ComicSpreadResolver.wideThreshold, 1.45);
    });
  });

  group('档位映射表完整性', () {
    test('三档都有 opacity 与 widthScale', () {
      for (final ComicSpineShadeStrength s in ComicSpineShadeStrength.values) {
        expect(ComicSpreadGutter.shadeOpacity[s], isNotNull);
        expect(ComicSpreadGutter.shadeWidthScale[s], isNotNull);
      }
      expect(ComicSpreadGutter.shadeOpacity.length, 3);
      expect(ComicSpreadGutter.shadeWidthScale.length, 3);
    });

    test('opacity / widthScale 随档位单调递增，且都在合法区间', () {
      final List<double> op = <double>[
        for (final ComicSpineShadeStrength s in ComicSpineShadeStrength.values)
          ComicSpreadGutter.shadeOpacity[s]!,
      ];
      final List<double> ws = <double>[
        for (final ComicSpineShadeStrength s in ComicSpineShadeStrength.values)
          ComicSpreadGutter.shadeWidthScale[s]!,
      ];
      for (int i = 1; i < op.length; i++) {
        expect(op[i], greaterThan(op[i - 1]));
        expect(ws[i], greaterThan(ws[i - 1]));
      }
      for (final double v in op) {
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThanOrEqualTo(1));
      }
    });
  });

  group('resolveShade：按背景亮度反推（本轮修的真实缺陷）', () {
    const double lightBg = 0.90;
    const double darkBg = 0.02;

    test('浅底用黑色阴影', () {
      final ComicSpineShadeSpec s = ComicSpreadGutter.resolveShade(
        slotWidth: 400,
        backgroundLuminance: lightBg,
        strength: ComicSpineShadeStrength.normal,
      );
      expect(s.onDarkBackground, isFalse);
      expect(s.color, const Color(0xFF000000));
      expect(s.opacity,
          ComicSpreadGutter.shadeOpacity[ComicSpineShadeStrength.normal]);
      expect(s.visible, isTrue);
    });

    test('深底改成白色内高光并折减强度，避免夜间黑叠黑', () {
      final ComicSpineShadeSpec s = ComicSpreadGutter.resolveShade(
        slotWidth: 400,
        backgroundLuminance: darkBg,
        strength: ComicSpineShadeStrength.normal,
      );
      expect(s.onDarkBackground, isTrue);
      expect(s.color, const Color(0xFFFFFFFF));
      expect(
        s.opacity,
        closeTo(
          ComicSpreadGutter.shadeOpacity[ComicSpineShadeStrength.normal]! *
              ComicSpreadGutter.darkShadeFactor,
          0.0001,
        ),
      );
      expect(
          s.opacity,
          lessThan(
              ComicSpreadGutter.shadeOpacity[ComicSpineShadeStrength.normal]!));
    });

    test('阈值边界：等于阈值也按深底处理', () {
      expect(
        ComicSpreadGutter.resolveShade(
          slotWidth: 400,
          backgroundLuminance: ComicSpreadGutter.darkBackgroundThreshold,
          strength: ComicSpineShadeStrength.normal,
        ).onDarkBackground,
        isTrue,
      );
      expect(
        ComicSpreadGutter.resolveShade(
          slotWidth: 400,
          backgroundLuminance:
              ComicSpreadGutter.darkBackgroundThreshold + 0.001,
          strength: ComicSpineShadeStrength.normal,
        ).onDarkBackground,
        isFalse,
      );
    });

    test('ReaderStyle 四档背景亮度都能解析，夜间确实落在深底', () {
      for (final ReaderBackground b in ReaderBackground.values) {
        final double lum =
            ReaderStyle.relativeLuminance(ReaderStyle.backgroundColors[b]!);
        expect(lum, greaterThanOrEqualTo(0));
        expect(lum, lessThanOrEqualTo(1));
      }
      final double night = ReaderStyle.relativeLuminance(
        ReaderStyle.backgroundColors[ReaderBackground.night]!,
      );
      final double paper = ReaderStyle.relativeLuminance(
        ReaderStyle.backgroundColors[ReaderBackground.paper]!,
      );
      expect(night, lessThan(ComicSpreadGutter.darkBackgroundThreshold));
      expect(paper, greaterThan(ComicSpreadGutter.darkBackgroundThreshold));
    });
  });

  group('resolveShade：宽度与强度联动', () {
    test('强档渐暗更宽、弱档更窄，且都不超过槽宽一半', () {
      final double base = ComicSpreadGutter.innerShadeWidth(400);
      final ComicSpineShadeSpec weak = ComicSpreadGutter.resolveShade(
        slotWidth: 400,
        backgroundLuminance: 0.9,
        strength: ComicSpineShadeStrength.subtle,
      );
      final ComicSpineShadeSpec strong = ComicSpreadGutter.resolveShade(
        slotWidth: 400,
        backgroundLuminance: 0.9,
        strength: ComicSpineShadeStrength.strong,
      );
      expect(weak.width, lessThan(base));
      expect(strong.width, greaterThan(base));
      for (final ComicSpineShadeSpec s in <ComicSpineShadeSpec>[weak, strong]) {
        expect(s.width, lessThanOrEqualTo(200.0));
        expect(s.width, greaterThan(0));
      }
    });

    test('零 / 负槽宽不渲染（visible=false）', () {
      for (final double w in <double>[0, -10]) {
        final ComicSpineShadeSpec s = ComicSpreadGutter.resolveShade(
          slotWidth: w,
          backgroundLuminance: 0.9,
        );
        expect(s.width, 0);
        expect(s.visible, isFalse);
      }
    });

    test('不显式传档位时按槽宽自动选', () {
      expect(
        ComicSpreadGutter.resolveShade(slotWidth: 200, backgroundLuminance: 0.9)
            .strength,
        ComicSpineShadeStrength.subtle,
      );
      expect(
        ComicSpreadGutter.resolveShade(slotWidth: 400, backgroundLuminance: 0.9)
            .strength,
        ComicSpineShadeStrength.normal,
      );
      expect(
        ComicSpreadGutter.resolveShade(slotWidth: 900, backgroundLuminance: 0.9)
            .strength,
        ComicSpineShadeStrength.strong,
      );
    });

    test('opacity 永远夹在 0..1', () {
      for (final double lum in <double>[-5, 0, 0.18, 0.5, 1, 99]) {
        for (final ComicSpineShadeStrength s
            in ComicSpineShadeStrength.values) {
          final ComicSpineShadeSpec spec = ComicSpreadGutter.resolveShade(
            slotWidth: 400,
            backgroundLuminance: lum,
            strength: s,
          );
          expect(spec.opacity, greaterThanOrEqualTo(0));
          expect(spec.opacity, lessThanOrEqualTo(1));
        }
      }
    });
  });

  group('ComicSpineShadeSpec 值语义', () {
    test('== / hashCode', () {
      const ComicSpineShadeSpec a = ComicSpineShadeSpec(
        color: Color(0xFF000000),
        opacity: 0.2,
        width: 12,
        strength: ComicSpineShadeStrength.normal,
        onDarkBackground: false,
      );
      const ComicSpineShadeSpec b = ComicSpineShadeSpec(
        color: Color(0xFF000000),
        opacity: 0.2,
        width: 12,
        strength: ComicSpineShadeStrength.normal,
        onDarkBackground: false,
      );
      const ComicSpineShadeSpec c = ComicSpineShadeSpec(
        color: Color(0xFFFFFFFF),
        opacity: 0.2,
        width: 12,
        strength: ComicSpineShadeStrength.normal,
        onDarkBackground: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('书脊编排与渐暗模型不互相干扰', () {
    test('只有两页跨有书脊，模型不改变页序', () {
      final ComicSpreadLayout l = layout();
      expect(ComicSpreadGutter.spineCount(l), 2);
      expect(<int>[for (final ComicSpread s in l.spreads) ...s.pages],
          <int>[0, 1, 2, 3, 4, 5]);
      for (final ComicSpread s in l.spreads) {
        if (ComicSpreadGutter.hasSpine(s)) {
          final ComicSpineShadeSpec spec = ComicSpreadGutter.resolveShade(
            slotWidth: 200,
            backgroundLuminance: 0.9,
          );
          expect(spec.visible, isTrue);
        }
      }
    });

    test('单页模式 spineCount=0，不产生可见渐暗', () {
      final ComicSpreadLayout l = ComicSpreadResolver.build(
        pageCount: 6,
        mode: ComicSpreadMode.single,
        direction: ComicReadingDirection.ltr,
        pageSize: portrait,
      );
      expect(ComicSpreadGutter.spineCount(l), 0);
      expect(l.spreads.every((ComicSpread s) => !ComicSpreadGutter.hasSpine(s)),
          isTrue);
    });
  });
}
