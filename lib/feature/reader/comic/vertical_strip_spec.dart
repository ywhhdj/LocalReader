
enum VerticalStripMode { vertical, horizontal, dualPage }

/// VerticalStrip：所有页按顺序拼进同一条滚动流。
/// 不分页、不跨页、不补白、不插入占位标题；ComicSpread 只服务主动切回的横向模式。
class VerticalStripSpec {
  const VerticalStripSpec({
    required this.pageCount,
    this.gap = 0,
    this.fitWidth = true,
    this.cacheExtent = 800,
  });

  final int pageCount;
  final double gap;
  final bool fitWidth;
  final double cacheExtent;

  /// 静态验收口径：childCount == 页数。
  int get childCount => pageCount;
  bool get usesComicSpread => false;
  bool get usesBlankSlot => false;
  bool get insertsSectionHeaders => false;
  bool get computesSpread => false;

  /// 懒加载靠 cacheExtent 预取，不预取整本。
  bool get lazy => true;
}

/// AppSettings.normalized() 沿用 dev 口径：vertical ⇒ single / ltr，
class ComicLayoutNormalized {
  const ComicLayoutNormalized({
    this.mode = VerticalStripMode.vertical,
    this.singlePage = true,
    this.ltr = true,
    this.pageAnimation = false,
    this.dualPage = false,
  });

  final VerticalStripMode mode;
  final bool singlePage;
  final bool ltr;
  final bool pageAnimation;
  final bool dualPage;

  ComicLayoutNormalized normalized() {
    if (mode != VerticalStripMode.vertical) {
      return ComicLayoutNormalized(
        mode: mode,
        singlePage: mode == VerticalStripMode.horizontal,
        ltr: ltr,
        pageAnimation: pageAnimation,
        dualPage: mode == VerticalStripMode.dualPage,
      );
    }
    return const ComicLayoutNormalized(
      mode: VerticalStripMode.vertical,
      singlePage: true,
      ltr: true,
      pageAnimation: false,
      dualPage: false,
    );
  }
}

/// 用户可在阅读设置里切回横向 / 双页；切换保留当前页锚点，不重建整条流。
class ComicModeSwitch {
  const ComicModeSwitch({required this.from, required this.to, this.anchorPage = 0});

  final VerticalStripMode from;
  final VerticalStripMode to;
  final int anchorPage;

  bool get keepAnchor => true;
  bool get rebuildWholeStrip => false;
}

// ---- 生产 widget 落点（本轮未编译） -------------------------------------
// CustomScrollView(
//   slivers: <Widget>[
//     HeaderNavSliver(spec: HeaderNavSpec(title: '阅读')),
//     SliverList(
//       delegate: SliverChildBuilderDelegate(
//         (BuildContext ctx, int i) => ComicPageSlot(
//           page: i, gap: 0, fitWidth: true, showOriginal: true),
//         childCount: spec.childCount, // 严格等于 document.pages.length
//       ),
//     ),
//   ],
// )
// 禁止出现：ComicSpread / _SpreadSlot / _BlankSlot / 分页动画 / 章节入场动画。
