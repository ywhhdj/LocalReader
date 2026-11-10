import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/comic/comic_spread.dart';
import 'package:local_reader/core/comic/comic_toc.dart';
import 'package:local_reader/core/platform/render_bridge.dart';
import 'package:local_reader/core/state/app_settings.dart';
import 'package:local_reader/core/state/reader_style.dart';
import 'package:local_reader/features/reader/comic_prefetch.dart';

class _RecordingBridge extends UnimplementedRenderBridge {
  _RecordingBridge() : super('測試平台');

  final List<List<int>> prefetched = <List<int>>[];
  final List<List<int>> evicted = <List<int>>[];

  @override
  Future<void> prefetch(int handle, List<int> upcoming) async =>
      prefetched.add(upcoming);

  @override
  Future<void> evict(int handle, List<int> indices) async =>
      evicted.add(indices);
}

const Size portrait = Size(400, 800);
const Size landscape = Size(800, 400);

ComicSpreadLayout build({
  int pages = 6,
  ComicSpreadMode mode = ComicSpreadMode.double,
  ComicReadingDirection dir = ComicReadingDirection.ltr,
  Size size = portrait,
}) =>
    ComicSpreadResolver.build(
      pageCount: pages,
      mode: mode,
      direction: dir,
      pageSize: size,
    );

void main() {
  group('标签与横屏判定', () {
    test('三档跨页模式、两种方向都有标签与提示', () {
      expect(ComicSpreadLabels.mode.length, ComicSpreadMode.values.length);
      expect(ComicSpreadLabels.modeHint.length, ComicSpreadMode.values.length);
      expect(ComicSpreadLabels.direction.length, ComicReadingDirection.values.length);
      expect(ComicSpreadLabels.directionHint.length, ComicReadingDirection.values.length);
      for (final ComicSpreadMode m in ComicSpreadMode.values) {
        expect(ComicSpreadLabels.mode[m], isNotEmpty);
        expect(ComicSpreadLabels.modeHint[m], isNotEmpty);
      }
    });

    test('横屏阈值 1.15：竖屏 / 正方形都不算横屏', () {
      expect(ComicSpreadResolver.isLandscape(portrait), isFalse);
      expect(ComicSpreadResolver.isLandscape(const Size(500, 500)), isFalse);
      expect(ComicSpreadResolver.isLandscape(landscape), isTrue);
      expect(ComicSpreadResolver.isLandscape(const Size(460, 400)), isTrue);
      expect(ComicSpreadResolver.isLandscape(const Size(459, 400)), isFalse);
    });

    test('零 / 负尺寸不抛异常且不算横屏', () {
      expect(ComicSpreadResolver.isLandscape(Size.zero), isFalse);
      expect(ComicSpreadResolver.isLandscape(const Size(0, -1)), isFalse);
    });

    test('resolveDoublePage 三档口径', () {
      expect(ComicSpreadResolver.resolveDoublePage(ComicSpreadMode.single, landscape), isFalse);
      expect(ComicSpreadResolver.resolveDoublePage(ComicSpreadMode.double, portrait), isTrue);
      expect(ComicSpreadResolver.resolveDoublePage(ComicSpreadMode.auto, portrait), isFalse);
      expect(ComicSpreadResolver.resolveDoublePage(ComicSpreadMode.auto, landscape), isTrue);
    });
  });

  group('单页模式', () {
    test('6 页 → 6 跨，每跨一页且无补白槽', () {
      final ComicSpreadLayout l = build(mode: ComicSpreadMode.single);
      expect(l.spreadCount, 6);
      expect(l.doublePage, isFalse);
      for (int i = 0; i < 6; i++) {
        expect(l.at(i).pages, <int>[i]);
        expect(l.at(i).visualSlots, <int?>[i]);
        expect(l.at(i).isBlankSlot, isFalse);
      }
    });

    test('单页模式 RTL 也只有一个槽，不会白占半屏', () {
      final ComicSpreadLayout l =
          build(mode: ComicSpreadMode.single, dir: ComicReadingDirection.rtl);
      expect(l.at(2).visualSlots, <int?>[2]);
      expect(l.at(2).blankOnLeft, isFalse);
      expect(l.at(2).blankOnRight, isFalse);
    });
  });

  group('双页跨页分组', () {
    test('6 页 → 封面 + 3 跨，页不重不漏', () {
      final ComicSpreadLayout l = build(pages: 6);
      expect(l.doublePage, isTrue);
      expect(l.spreadCount, 4);
      expect(l.hasCoverSpread, isTrue);
      expect(l.at(0).pages, <int>[0]);
      expect(l.at(0).isCover, isTrue);
      expect(l.at(1).pages, <int>[1, 2]);
      expect(l.at(2).pages, <int>[3, 4]);
      expect(l.at(3).pages, <int>[5]);
      final List<int> flat = <int>[
        for (final ComicSpread s in l.spreads) ...s.pages,
      ];
      expect(flat, <int>[0, 1, 2, 3, 4, 5]);
      expect(flat.toSet().length, 6);
    });

    test('封面永远独占一跨，绝不与第 2 页并排', () {
      for (int n = 2; n <= 9; n++) {
        final ComicSpreadLayout l = build(pages: n);
        expect(l.at(0).pages, <int>[0], reason: '$n 页时封面被并排了');
        expect(l.at(0).isCover, isTrue);
      }
    });

    test('奇数末页产生补白槽，且明示不是缺页', () {
      final ComicSpreadLayout l = build(pages: 4);
      expect(l.spreadCount, 3);
      expect(l.at(2).pages, <int>[3]);
      expect(l.at(2).isBlankSlot, isTrue);
      expect(l.at(2).blankOnRight, isTrue);
      expect(l.at(2).blankOnLeft, isFalse);
      expect(l.at(2).visualSlots, <int?>[3, null]);
    });

    test('偶数末页正好两页，不产生补白槽', () {
      final ComicSpreadLayout l = build(pages: 5);
      expect(l.spreadCount, 3);
      expect(l.at(2).pages, <int>[3, 4]);
      expect(l.at(2).isBlankSlot, isFalse);
    });

    test('只有 1 页时不崩溃，只有封面一跨', () {
      final ComicSpreadLayout l = build(pages: 1);
      expect(l.spreadCount, 1);
      expect(l.at(0).pages, <int>[0]);
      expect(l.at(0).isCover, isTrue);
      expect(l.spreadForPage(99), 0);
    });

    test('空漫画返回空布局，所有换算都不崩', () {
      final ComicSpreadLayout l = build(pages: 0);
      expect(l.isEmpty, isTrue);
      expect(l.spreadCount, 0);
      expect(l.spreadForPage(3), 0);
      expect(l.viewIndexForSpread(3), 0);
      expect(l.initialViewIndex, 0);
      expect(l.prefetchPagesFor(0), isEmpty);
    });

    test('pageLabel 单页 / 双页两种写法', () {
      expect(build().at(0).pageLabel, 'P1');
      expect(build().at(1).pageLabel, 'P2–P3');
      expect(build().at(3).pageLabel, 'P6');
    });
  });

  group('RTL 视觉槽位', () {
    test('LTR 两页跨：早页在左', () {
      final ComicSpreadLayout l = build();
      expect(l.at(1).visualSlots, <int?>[1, 2]);
    });

    test('RTL 两页跨：早页在右（靠书脊）', () {
      final ComicSpreadLayout l = build(dir: ComicReadingDirection.rtl);
      expect(l.at(1).visualSlots, <int?>[2, 1]);
      expect(l.at(1).pages, <int>[1, 2], reason: '阅读顺序不因 RTL 改变');
      expect(l.at(1).primaryPage, 1);
    });

    test('RTL 封面与奇数末页：真实页在右，补白在左', () {
      final ComicSpreadLayout l =
          build(pages: 4, dir: ComicReadingDirection.rtl);
      expect(l.at(0).visualSlots, <int?>[null, 0]);
      expect(l.at(0).blankOnLeft, isTrue);
      expect(l.at(2).visualSlots, <int?>[null, 3]);
      expect(l.at(2).blankOnLeft, isTrue);
      expect(l.at(2).blankOnRight, isFalse);
    });

    test('LTR 封面与奇数末页：真实页在左，补白在右', () {
      final ComicSpreadLayout l = build(pages: 4);
      expect(l.at(0).visualSlots, <int?>[0, null]);
      expect(l.at(2).visualSlots, <int?>[3, null]);
    });
  });

  group('页 ↔ 跨 ↔ 视觉索引', () {
    test('spreadForPage 双页映射正确且覆盖全部页', () {
      final ComicSpreadLayout l = build(pages: 6);
      expect(l.spreadForPage(0), 0);
      expect(l.spreadForPage(1), 1);
      expect(l.spreadForPage(2), 1);
      expect(l.spreadForPage(3), 2);
      expect(l.spreadForPage(4), 2);
      expect(l.spreadForPage(5), 3);
      for (int p = 0; p < 6; p++) {
        expect(l.at(l.spreadForPage(p)).pages.contains(p), isTrue, reason: 'P$p 落错跨');
      }
    });

    test('spreadForPage 越界夹住，不抛 RangeError', () {
      final ComicSpreadLayout l = build(pages: 6);
      expect(l.spreadForPage(-5), 0);
      expect(l.spreadForPage(99), 3);
    });

    test('LTR 视觉索引恒等，初始为 0，前进 +1', () {
      final ComicSpreadLayout l = build();
      expect(l.isRtl, isFalse);
      expect(l.initialViewIndex, 0);
      expect(l.forwardStep, 1);
      expect(l.advanceOnTapLeft, isFalse);
      expect(l.viewIndexForSpread(2), 2);
      expect(l.spreadForViewIndex(2), 2);
    });

    test('RTL 视觉索引反转，初始为最后一格，前进 -1', () {
      final ComicSpreadLayout l = build(dir: ComicReadingDirection.rtl);
      expect(l.isRtl, isTrue);
      expect(l.initialViewIndex, l.spreadCount - 1);
      expect(l.forwardStep, -1);
      expect(l.advanceOnTapLeft, isTrue);
      expect(l.viewIndexForSpread(0), l.spreadCount - 1);
      expect(l.spreadForViewIndex(l.spreadCount - 1), 0);
    });

    test('viewIndex ↔ spreadIndex 双向可逆', () {
      for (final ComicReadingDirection d in ComicReadingDirection.values) {
        final ComicSpreadLayout l = build(dir: d);
        for (int s = 0; s < l.spreadCount; s++) {
          expect(l.spreadForViewIndex(l.viewIndexForSpread(s)), s);
        }
      }
    });

    test('viewIndexForPage 与 spreadAtViewIndex 一致（目录 pageStart 可直达）', () {
      for (final ComicReadingDirection d in ComicReadingDirection.values) {
        final ComicSpreadLayout l = build(pages: 6, dir: d);
        for (int p = 0; p < 6; p++) {
          final int view = l.viewIndexForPage(p);
          expect(l.spreadAtViewIndex(view).pages.contains(p), isTrue,
              reason: '$d / P$p 目录跳转错位');
        }
      }
    });

    test('下一跨的视觉索引变化方向与 forwardStep 一致', () {
      final ComicSpreadLayout l = build(dir: ComicReadingDirection.rtl);
      for (int s = 0; s < l.spreadCount - 1; s++) {
        expect(l.viewIndexForSpread(s + 1) - l.viewIndexForSpread(s),
            l.forwardStep);
      }
    });

    test('prefetchPagesFor 覆盖当前跨及相邻跨，双页不漏', () {
      final ComicSpreadLayout l = build(pages: 8);
      final List<int> pages = l.prefetchPagesFor(3);
      expect(pages, <int>[1, 2, 3, 4, 5, 6]);
      expect(pages.contains(3) && pages.contains(4), isTrue,
          reason: '同一跨的两页必须一起预取');
    });

    test('prefetchPagesFor 在首尾跨自动收缩，不越界', () {
      final ComicSpreadLayout l = build(pages: 6);
      expect(l.prefetchPagesFor(0), <int>[0, 1, 2]);
      expect(l.prefetchPagesFor(5).last, 5);
      expect(l.prefetchPagesFor(5).any((int p) => p > 5), isFalse);
    });
  });

  group('auto 随页面尺寸变化', () {
    test('竖屏单页、横屏双页，跨数随尺寸改变', () {
      final ComicSpreadLayout v =
          build(pages: 6, mode: ComicSpreadMode.auto, size: portrait);
      final ComicSpreadLayout h =
          build(pages: 6, mode: ComicSpreadMode.auto, size: landscape);
      expect(v.doublePage, isFalse);
      expect(v.spreadCount, 6);
      expect(h.doublePage, isTrue);
      expect(h.spreadCount, 4);
    });

    test('auto 不改变页序，只改变分跨方式', () {
      List<int> flat(ComicSpreadLayout l) => <int>[
            for (final ComicSpread s in l.spreads) ...s.pages,
          ];
      expect(
        flat(build(pages: 6, mode: ComicSpreadMode.auto, size: landscape)),
        flat(build(pages: 6, mode: ComicSpreadMode.single)),
      );
    });
  });

  group('ComicSpread 值语义', () {
    test('pages 不同则不相等，逐字段 hashCode 一致', () {
      final ComicSpread a = build().at(1);
      final ComicSpread b = build().at(2);
      expect(a, isNot(b));
      expect(a, build().at(1));
      expect(a.hashCode, build().at(1).hashCode);
    });

    test('方向不同则不相等（视觉槽位会变）', () {
      expect(
        build().at(1),
        isNot(build(dir: ComicReadingDirection.rtl).at(1)),
      );
    });
  });

  group('ReaderStyle 新偏好', () {
    test('默认单页 + 左→右，且不影响小说分页缓存键', () {
      const ReaderStyle a = ReaderStyle();
      expect(a.comicSpreadMode, ComicSpreadMode.single);
      expect(a.comicDirection, ComicReadingDirection.ltr);
      final ReaderStyle b = a.copyWith(
        comicReadMode: ComicReadMode.paged,
        comicSpreadMode: ComicSpreadMode.double,
        comicDirection: ComicReadingDirection.rtl,
      );
      expect(b.layoutKey, a.layoutKey,
          reason: '换双页 / RTL 不该触发小说章节重新分页');
    });

    test('toMap / fromMap 往返，未知枚举回退默认', () {
      final ReaderStyle s = const ReaderStyle().copyWith(
        comicSpreadMode: ComicSpreadMode.auto,
        comicDirection: ComicReadingDirection.rtl,
      );
      expect(ReaderStyle.fromMap(s.toMap()), s);
      final ReaderStyle fallback = ReaderStyle.fromMap(<String, Object>{
        'comicSpreadMode': 'unknown',
        'comicDirection': 'unknown',
      });
      expect(fallback.comicSpreadMode, ComicSpreadMode.single);
      expect(fallback.comicDirection, ComicReadingDirection.ltr);
    });

    test('值相等包含跨页模式与方向', () {
      expect(const ReaderStyle(), const ReaderStyle().copyWith());
      expect(
        const ReaderStyle(),
        isNot(const ReaderStyle().copyWith(comicSpreadMode: ComicSpreadMode.double)),
      );
      expect(
        const ReaderStyle(),
        isNot(const ReaderStyle().copyWith(comicDirection: ComicReadingDirection.rtl)),
      );
    });

    test('ComicModeLabels 两种模式都有标签与提示', () {
      expect(ComicModeLabels.labels.length, ComicReadMode.values.length);
      expect(ComicModeLabels.hints.length, ComicReadMode.values.length);
      expect(ComicModeLabels.hints[ComicReadMode.paged], contains('双页'));
    });
  });

  group('AppSettings 第三条归一化', () {
    test('竖向连续锁回单页 + 左→右，不留「设了没反应」的偏好', () {
      final AppSettings s = const AppSettings(
        reader: ReaderStyle(
          comicReadMode: ComicReadMode.vertical,
          comicSpreadMode: ComicSpreadMode.double,
          comicDirection: ComicReadingDirection.rtl,
        ),
      ).normalized();
      expect(s.reader.comicSpreadMode, ComicSpreadMode.single);
      expect(s.reader.comicDirection, ComicReadingDirection.ltr);
      expect(s.reader.comicReadMode, ComicReadMode.vertical);
    });

    test('横向跨页模式保留双页 + RTL', () {
      final AppSettings s = const AppSettings(
        reader: ReaderStyle(
          comicReadMode: ComicReadMode.paged,
          comicSpreadMode: ComicSpreadMode.double,
          comicDirection: ComicReadingDirection.rtl,
        ),
      ).normalized();
      expect(s.reader.comicSpreadMode, ComicSpreadMode.double);
      expect(s.reader.comicDirection, ComicReadingDirection.rtl);
    });

    test('与纯本地 / 动效归一化共存，互不清掉对方的裁决', () {
      final AppSettings s = const AppSettings(
        pureLocal: true,
        onlineDirectory: true,
        motion: false,
        reader: ReaderStyle(
          pageTurn: ReaderPageTurn.simulation,
          comicReadMode: ComicReadMode.paged,
          comicSpreadMode: ComicSpreadMode.auto,
          comicDirection: ComicReadingDirection.rtl,
        ),
      ).normalized();
      expect(s.onlineDirectory, isFalse);
      expect(s.reader.pageTurn, ReaderPageTurn.none);
      expect(s.reader.comicSpreadMode, ComicSpreadMode.auto);
      expect(s.reader.comicDirection, ComicReadingDirection.rtl);
    });

    test('归一化幂等', () {
      final AppSettings once = const AppSettings(
        reader: ReaderStyle(
          comicReadMode: ComicReadMode.vertical,
          comicSpreadMode: ComicSpreadMode.double,
          comicDirection: ComicReadingDirection.rtl,
        ),
      ).normalized();
      expect(once.normalized(), once);
    });
  });

  group('预取窗口覆盖双页', () {
    test('moveToPages 一次覆盖当前跨两页，且只在差集变化时批量调用', () {
      final _RecordingBridge bridge = _RecordingBridge();
      final ComicPrefetchWindow w = ComicPrefetchWindow(
        bridge: bridge, back: 1, ahead: 1,
      )..attach(0, 8);
      final ComicSpreadLayout l = build(pages: 8);
      w.moveToPages(l.prefetchPagesFor(3));
      expect(w.activeWindow.containsAll(<int>[3, 4]), isTrue);
      expect(bridge.prefetched.length, 1);
      // 同一组页再调一次不应重复跨 channel。
      w.moveToPages(l.prefetchPagesFor(3));
      expect(bridge.prefetched.length, 1);
      // invalidate 后重算，仍按差集 evict / prefetch，不逐帧刷新。
      w.invalidate();
      w.moveToPages(<int>[7]);
      expect(w.activeWindow.contains(7), isTrue);
    });

    test('moveTo 仍委托 moveToPages，旧口径不破', () {
      final _RecordingBridge bridge = _RecordingBridge();
      final ComicPrefetchWindow w = ComicPrefetchWindow(
        bridge: bridge, back: 1, ahead: 1,
      )..attach(0, 8);
      w.moveTo(2);
      expect(w.activeWindow, <int>{1, 2, 3});
    });
  });
}
