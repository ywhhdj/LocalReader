import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/comic/comic_spread.dart';

const Size portrait = Size(400, 800);
const Size landscape = Size(800, 400);

ComicSpreadLayout layout({
  int pages = 6,
  ComicSpreadMode mode = ComicSpreadMode.double,
  ComicReadingDirection dir = ComicReadingDirection.ltr,
  List<double>? ratios,
}) =>
    ComicSpreadResolver.build(
      pageCount: pages,
      mode: mode,
      direction: dir,
      pageSize: portrait,
      aspectRatios: ratios,
    );

void main() {
  group('hasSpine：只有两页真实页并排', () {
    test('两页跨 → 有书脊；封面 / 奇数末页补白 → 没有', () {
      final ComicSpreadLayout l = layout();
      expect(ComicSpreadGutter.hasSpine(l.spreads[0]), isFalse); // 封面
      expect(ComicSpreadGutter.hasSpine(l.spreads[1]), isTrue); // P2,P3
      expect(ComicSpreadGutter.hasSpine(l.spreads[2]), isTrue); // P4,P5
      expect(ComicSpreadGutter.hasSpine(l.spreads[3]), isFalse); // P6 补白
      expect(ComicSpreadGutter.spineCount(l), 2);
    });

    test('宽幅页独占跨不画书脊（补白槽不是装订）', () {
      final ComicSpreadLayout l = layout(
        ratios: const <double>[0.7, 0.7, 2.0, 0.7, 0.7, 0.7],
      );
      final ComicSpread wide =
          l.spreads.firstWhere((ComicSpread s) => s.isWide);
      expect(ComicSpreadGutter.hasSpine(wide), isFalse);
    });

    test('单页模式每页一跨，书脊数为 0', () {
      final ComicSpreadLayout l = layout(mode: ComicSpreadMode.single);
      expect(ComicSpreadGutter.spineCount(l), 0);
      for (final ComicSpread s in l.spreads) {
        expect(ComicSpreadGutter.hasSpine(s), isFalse);
      }
    });

    test('RTL 不改变书脊数量与位置（视觉槽位另管左右）', () {
      final ComicSpreadLayout l = layout(dir: ComicReadingDirection.rtl);
      expect(ComicSpreadGutter.spineCount(l), 2);
      final ComicSpread s = l.spreads[1];
      expect(s.visualSlots, <int?>[2, 1]);
      expect(ComicSpreadGutter.hasSpine(s), isTrue);
    });
  });

  group('width：按槽宽比例并夹在上下限', () {
    test('零 / 负宽度回落下限', () {
      expect(ComicSpreadGutter.width(0), ComicSpreadGutter.minWidthPx);
      expect(ComicSpreadGutter.width(-10), ComicSpreadGutter.minWidthPx);
    });

    test('窄槽夹到下限，宽槽夹到上限', () {
      expect(ComicSpreadGutter.width(100), ComicSpreadGutter.minWidthPx);
      expect(ComicSpreadGutter.width(4000), ComicSpreadGutter.maxWidthPx);
    });

    test('中间区间按 0.035 比例', () {
      expect(ComicSpreadGutter.width(400),
          closeTo(400 * ComicSpreadGutter.widthRatio, 0.001));
    });

    test('书脊比例与横屏阈值是两个独立常量，不混用', () {
      expect(ComicSpreadGutter.widthRatio, 0.035);
      expect(ComicSpreadResolver.landscapeThreshold, 1.15);
      expect(ComicSpreadResolver.wideThreshold, 1.45);
    });
  });

  group('gapFor：书脊跨用计算宽度，其余用固定间距', () {
    test('两页跨取 width()', () {
      final ComicSpread s = layout().spreads[1];
      expect(ComicSpreadGutter.gapFor(s, 400), ComicSpreadGutter.width(400));
    });

    test('封面 / 补白跨取 fallback，不受槽宽影响', () {
      final ComicSpread cover = layout().spreads[0];
      expect(ComicSpreadGutter.gapFor(cover, 400),
          ComicSpreadGutter.fallbackGapPx);
      expect(ComicSpreadGutter.gapFor(cover, 4000),
          ComicSpreadGutter.fallbackGapPx);
    });
  });

  group('innerShadeWidth：内侧渐暗宽度', () {
    test('零 / 负槽宽不叠渐暗', () {
      expect(ComicSpreadGutter.innerShadeWidth(0), 0);
      expect(ComicSpreadGutter.innerShadeWidth(-1), 0);
    });

    test('不超过槽宽一半，也不超过书脊宽的 1.5 倍', () {
      for (final double w in <double>[200, 400, 800, 4000]) {
        final double shade = ComicSpreadGutter.innerShadeWidth(w);
        expect(shade, greaterThanOrEqualTo(0));
        expect(shade, lessThanOrEqualTo(w / 2 + 0.001));
        expect(
            shade, lessThanOrEqualTo(ComicSpreadGutter.width(w) * 1.5 + 0.001));
      }
    });

    test('正常槽宽下渐暗大于 0', () {
      expect(ComicSpreadGutter.innerShadeWidth(400), greaterThan(0));
    });
  });

  group('outerPadding：跨间留白按整页宽比例并夹住', () {
    test('零 / 负回落下限', () {
      expect(ComicSpreadGutter.outerPadding(0), ComicSpreadGutter.minOuterPx);
      expect(ComicSpreadGutter.outerPadding(-5), ComicSpreadGutter.minOuterPx);
    });

    test('上下限', () {
      expect(ComicSpreadGutter.outerPadding(100), ComicSpreadGutter.minOuterPx);
      expect(
          ComicSpreadGutter.outerPadding(5000), ComicSpreadGutter.maxOuterPx);
    });

    test('400 宽按 0.024 比例', () {
      expect(ComicSpreadGutter.outerPadding(400),
          closeTo(400 * ComicSpreadGutter.outerRatio, 0.001));
    });

    test('auto + 横屏仍双页，书脊照常生效', () {
      final ComicSpreadLayout l = ComicSpreadResolver.build(
        pageCount: 6,
        mode: ComicSpreadMode.auto,
        direction: ComicReadingDirection.ltr,
        pageSize: landscape,
      );
      expect(l.doublePage, isTrue);
      expect(ComicSpreadGutter.spineCount(l), greaterThan(0));
    });
  });

  group('静态边界口径', () {
    test('书脊不改变跨页编排本身（页序仍完整升序）', () {
      final ComicSpreadLayout l = layout();
      final List<int> flat = <int>[
        for (final ComicSpread s in l.spreads) ...s.pages,
      ];
      expect(flat, <int>[0, 1, 2, 3, 4, 5]);
      expect(ComicSpreadGutter.spineCount(l), 2);
      expect(l.spreads[1].isDouble, isTrue);
      expect(l.spreads[1].isSolo, isFalse);
    });

    test('一页不丢：含宽幅页时书脊只落在真正两页的跨上', () {
      final ComicSpreadLayout l = layout(
        ratios: const <double>[0.7, 0.7, 2.0, 0.7, 0.7, 0.7],
      );
      final List<int> flat = <int>[
        for (final ComicSpread s in l.spreads) ...s.pages,
      ];
      expect(flat, <int>[0, 1, 2, 3, 4, 5]);
      for (final ComicSpread s in l.spreads) {
        if (ComicSpreadGutter.hasSpine(s)) {
          expect(s.pages.length, 2);
          expect(s.isWide, isFalse);
          expect(s.isCover, isFalse);
        }
      }
    });
  });
}
