import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/comic/comic_spread.dart';
import 'package:local_reader/core/state/reader_style.dart';

const Size portrait = Size(400, 800);
const Size landscape = Size(800, 400);

ComicSpreadLayout build({
  int pages = 6,
  ComicSpreadMode mode = ComicSpreadMode.double,
  ComicReadingDirection dir = ComicReadingDirection.ltr,
  Size size = portrait,
  List<double>? ratios,
  bool respect = true,
  double wideThreshold = ComicSpreadResolver.wideThreshold,
}) =>
    ComicSpreadResolver.build(
      pageCount: pages,
      mode: mode,
      direction: dir,
      pageSize: size,
      aspectRatios: ratios,
      respectWidePages: respect,
      wideThresholdValue: wideThreshold,
    );

List<List<int>> pagesOf(ComicSpreadLayout l) =>
    l.spreads.map<List<int>>((ComicSpread s) => s.pages).toList();

void main() {
  group('isWidePage 判定', () {
    test('默认阈值 1.45，边界含等号', () {
      expect(ComicSpreadResolver.wideThreshold, 1.45);
      expect(ComicSpreadResolver.isWidePage(0, <double>[1.45]), isTrue);
      expect(ComicSpreadResolver.isWidePage(0, <double>[1.44]), isFalse);
    });

    test('null / 越界 / 非法值一律不算宽幅', () {
      expect(ComicSpreadResolver.isWidePage(0, null), isFalse);
      expect(ComicSpreadResolver.isWidePage(-1, <double>[2.0]), isFalse);
      expect(ComicSpreadResolver.isWidePage(3, <double>[2.0]), isFalse);
      expect(ComicSpreadResolver.isWidePage(0, <double>[double.nan]), isFalse);
      expect(ComicSpreadResolver.isWidePage(0, <double>[double.infinity]),
          isFalse);
    });

    test('自定义阈值', () {
      expect(
        ComicSpreadResolver.isWidePage(0, <double>[1.2], threshold: 1.1),
        isTrue,
      );
    });
  });

  group('无宽幅页时与第十五轮行为完全一致（回归）', () {
    test('6 页双页 → 封面独占 + 两两成跨 + 末页补白', () {
      final ComicSpreadLayout l = build();
      expect(pagesOf(l), <List<int>>[
        <int>[0],
        <int>[1, 2],
        <int>[3, 4],
        <int>[5],
      ]);
      expect(l.wideSpreadCount, 0);
      expect(l.hasCoverSpread, isTrue);
    });

    test('respectWidePages=false 时即使给了宽高比也恢复旧编排', () {
      final ComicSpreadLayout l = build(
        ratios: const <double>[0.7, 0.7, 2.0, 0.7, 0.7, 0.7],
        respect: false,
      );
      expect(pagesOf(l), <List<int>>[
        <int>[0],
        <int>[1, 2],
        <int>[3, 4],
        <int>[5],
      ]);
      expect(l.wideSpreadCount, 0);
    });
  });

  group('宽幅页独占一跨', () {
    /// 第 3 页（index 2）是横幅彩图。
    const List<double> ratios = <double>[0.7, 0.7, 2.0, 0.7, 0.7, 0.7];

    test('宽幅页不与任何邻页并排，前后页各自补白', () {
      final ComicSpreadLayout l = build(ratios: ratios);
      expect(pagesOf(l), <List<int>>[
        <int>[0], // 封面
        <int>[1], // 下一页是宽幅，P2 独占位
        <int>[2], // 宽幅页独占
        <int>[3, 4], // 之后恢复两两成跨
        <int>[5], // 奇数末页补白
      ]);
      expect(l.wideSpreadCount, 1);
      expect(l.spreads[2].isWide, isTrue);
      expect(l.spreads[2].soloReason, '宽幅页独占一跨');
      expect(l.spreads[0].soloReason, '封面独占一跨');
      expect(l.spreads[4].soloReason, '奇数末页补白 · 非缺页');
    });

    test('一页不丢：所有真实页恰好升序覆盖 0..5', () {
      final ComicSpreadLayout l = build(ratios: ratios);
      final List<int> flat = <int>[
        for (final ComicSpread s in l.spreads) ...s.pages,
      ];
      expect(flat, <int>[0, 1, 2, 3, 4, 5]);
      expect(l.pageCount, 6);
      for (final ComicSpread s in l.spreads) {
        expect(s.pages.length, inInclusiveRange(1, 2));
      }
    });

    test('连续两张宽幅页：各自独占，中间不插入配对', () {
      final ComicSpreadLayout l = build(
        ratios: const <double>[0.7, 0.7, 2.0, 2.2, 0.7, 0.7],
      );
      expect(pagesOf(l), <List<int>>[
        <int>[0],
        <int>[1],
        <int>[2],
        <int>[3],
        <int>[4, 5],
      ]);
      expect(l.wideSpreadCount, 2);
    });

    test('首张非封面的宽幅页也独占', () {
      final ComicSpreadLayout l = build(
        ratios: const <double>[0.7, 2.0, 0.7, 0.7, 0.7, 0.7],
      );
      expect(pagesOf(l), <List<int>>[
        <int>[0],
        <int>[1],
        <int>[2, 3],
        <int>[4, 5],
      ]);
      expect(l.wideSpreadCount, 1);
      expect(l.spreads[1].isWide, isTrue);
    });

    test('RTL 下宽幅独占跨的真实页仍在视觉右侧', () {
      final ComicSpreadLayout l = build(
        ratios: ratios,
        dir: ComicReadingDirection.rtl,
      );
      final ComicSpread wide = l.spreads[2];
      expect(wide.visualSlots, <int?>[null, 2]);
      expect(wide.blankOnLeft, isTrue);
      expect(wide.blankOnRight, isFalse);
      expect(l.viewIndexForSpread(2), l.spreadCount - 1 - 2);
    });

    test('LTR 下宽幅独占跨的真实页在视觉左侧', () {
      final ComicSpreadLayout l = build(ratios: ratios);
      expect(l.spreads[2].visualSlots, <int?>[2, null]);
      expect(l.spreads[2].blankOnRight, isTrue);
    });

    test('预取窗口覆盖整跨，不因宽幅页漏页', () {
      final ComicSpreadLayout l = build(ratios: ratios);
      final List<int> pages = l.prefetchPagesFor(2);
      expect(pages, contains(1));
      expect(pages, contains(2));
      expect(pages, contains(3));
      expect(pages, contains(4));
    });

    test('pageLabel 不把补白槽写成缺页', () {
      final ComicSpreadLayout l = build(ratios: ratios);
      expect(l.spreads[2].pageLabel, 'P3');
      expect(l.spreads[2].isBlankSlot, isTrue);
      expect(l.spreads[2].isSolo, isTrue);
    });
  });

  group('单页 / 竖向模式', () {
    test('单页模式每页一跨，wideSpreadCount 恒为 0', () {
      final ComicSpreadLayout l = build(
        mode: ComicSpreadMode.single,
        ratios: const <double>[0.7, 2.0, 2.1, 0.7, 0.7, 0.7],
      );
      expect(l.spreadCount, 6);
      expect(l.wideSpreadCount, 0);
      expect(l.spreads.every((ComicSpread s) => s.pages.length == 1), isTrue);
    });

    test('auto + 横屏仍会启用双页，从而应用宽幅规则', () {
      final ComicSpreadLayout l = build(
        mode: ComicSpreadMode.auto,
        size: landscape,
        ratios: const <double>[0.7, 0.7, 2.0, 0.7, 0.7, 0.7],
      );
      expect(l.doublePage, isTrue);
      expect(l.wideSpreadCount, 1);
    });
  });

  group('ComicSpread 值语义', () {
    test('isWide 参与 == / hashCode', () {
      const ComicSpread a = ComicSpread(
        index: 1,
        pages: <int>[2],
        direction: ComicReadingDirection.ltr,
        doublePage: true,
        isWide: true,
      );
      const ComicSpread b = ComicSpread(
        index: 1,
        pages: <int>[2],
        direction: ComicReadingDirection.ltr,
        doublePage: true,
        isWide: false,
      );
      expect(a, isNot(b));
      expect(
          a,
          ComicSpread(
            index: 1,
            pages: const <int>[2],
            direction: ComicReadingDirection.ltr,
            doublePage: true,
            isWide: true,
          ));
    });
  });

  group('ReaderStyle.widePageSolo 全链路', () {
    test('默认 true，copyWith 可关闭', () {
      const ReaderStyle s = ReaderStyle();
      expect(s.widePageSolo, isTrue);
      expect(s.copyWith(widePageSolo: false).widePageSolo, isFalse);
    });

    test('刻意不进 layoutKey：换偏好不重排整章小说', () {
      const ReaderStyle a = ReaderStyle();
      final ReaderStyle b = a.copyWith(widePageSolo: false);
      expect(b.layoutKey, a.layoutKey);
    });

    test('toMap / fromMap 往返保留，旧配置缺字段回落 true', () {
      final ReaderStyle s = const ReaderStyle().copyWith(widePageSolo: false);
      expect(s.toMap()['widePageSolo'], isFalse);
      expect(ReaderStyle.fromMap(s.toMap()), s);
      expect(ReaderStyle.fromMap(<String, Object>{}).widePageSolo, isTrue);
    });

    test('值语义包含新字段', () {
      const ReaderStyle a = ReaderStyle();
      final ReaderStyle b = a.copyWith(widePageSolo: false);
      expect(a, isNot(b));
      expect(a, const ReaderStyle());
    });
  });
}
