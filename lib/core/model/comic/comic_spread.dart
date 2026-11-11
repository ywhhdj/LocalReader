import 'dart:ui' show Color, Size;

import 'package:flutter/foundation.dart';

/// 双页跨页（spread）与从右到左翻页（RTL）的**纯 Dart 编排模型**。
///
/// 参考仓库 / 原项目 README 里「漫画阅读：预加载窗口、按页宽高比占位、话集目录跳转」
/// 已在前几轮落地；本轮补的是漫画读者最在意的两个偏好：**双页跨页**与**日漫 RTL**。
///
/// **静态边界**（与整包一致）：
/// - 只编排「页序 → 跨页 → 视觉槽位 → PageView 索引」，不解码图片、不读文件字节；
///   页像素仍由 `BookRenderBridge` 提供（❄️ 冻结），页面继续按宽高比占位。
/// - 「空白槽」是**补位**，不是缺页：奇数页时明示，绝不静默吞页或伪造一张图。
/// - `auto` 依据页面宽高比判定横屏，不读 `Platform.is*` / 不查设备方向传感器。
///   平台判断依旧收口在 `core/platform/`。

/// 单页 / 双页 / 自动（横屏自动双页）。
enum ComicSpreadMode { single, double, auto }

/// 翻页方向：左到右（国漫 / 欧美） / 右到左（日漫）。
enum ComicReadingDirection { ltr, rtl }

class ComicSpreadLabels {
  const ComicSpreadLabels._();

  static const Map<ComicSpreadMode, String> mode = <ComicSpreadMode, String>{
    ComicSpreadMode.single: '单页',
    ComicSpreadMode.double: '双页',
    ComicSpreadMode.auto: '自动',
  };

  static const Map<ComicSpreadMode, String> modeHint =
      <ComicSpreadMode, String>{
    ComicSpreadMode.single: '一次一页，不产生补白槽',
    ComicSpreadMode.double: '封面独占一跨，之后每两页一跨；奇数页补白并明示',
    ComicSpreadMode.auto: '横屏自动双页、竖屏自动单页，按页面宽高比判定',
  };

  static const Map<ComicReadingDirection, String> direction =
      <ComicReadingDirection, String>{
    ComicReadingDirection.ltr: '左 → 右',
    ComicReadingDirection.rtl: '右 → 左',
  };

  static const Map<ComicReadingDirection, String> directionHint =
      <ComicReadingDirection, String>{
    ComicReadingDirection.ltr: '点屏幕右半区 / 从右往左滑前进，较早页显示在左侧',
    ComicReadingDirection.rtl: '点屏幕左半区 / 从左往右滑前进，较早页显示在右侧',
  };
}

/// 一个跨页：`pages` 始终是**阅读顺序**的真实页索引（升序，长度 1 或 2）。
/// 视觉左右由 `visualSlots` 单独给出，模型层不混进 Widget 方向判断。
@immutable
class ComicSpread {
  const ComicSpread({
    required this.index,
    required this.pages,
    required this.direction,
    required this.doublePage,
    this.isCover = false,
    this.isWide = false,
  }) : assert(pages.length == 1 || pages.length == 2, '一跨只能有 1 或 2 页');

  final int index;
  final List<int> pages;
  final ComicReadingDirection direction;
  final bool doublePage;
  final bool isCover;

  /// 宽幅页（横幅 / 跨页彩图）独占的一跨。仍按双页模式补白槽，
  /// 但 UI 会写「宽幅页独占一跨 · 非缺页」，不把补白误读成丢页。
  final bool isWide;

  bool get isDouble => pages.length == 2;
  bool get isBlankSlot => doublePage && pages.length == 1;
  bool get isSolo => pages.length == 1;

  /// 进度锚点取阅读顺序第一页（RTL 下它在视觉右侧）。
  int get primaryPage => pages.first;
  int get lastPage => pages.last;

  /// 视觉上「从左到右」的槽位；null = 补白槽。
  /// - 单页模式：只有一个槽，不补白（否则会白占半屏）。
  /// - 双页模式两页：LTR [早, 晚]，RTL [晚, 早]（早页靠书脊在右）。
  /// - 双页模式单页（封面或奇数末页）：另一半补白，且 RTL 时真实页在右。
  List<int?> get visualSlots {
    if (!doublePage) return List<int?>.unmodifiable(<int?>[pages.first]);
    if (pages.length == 2) {
      return List<int?>.unmodifiable(
        direction == ComicReadingDirection.rtl
            ? <int?>[pages[1], pages[0]]
            : <int?>[pages[0], pages[1]],
      );
    }
    return List<int?>.unmodifiable(
      direction == ComicReadingDirection.rtl
          ? <int?>[null, pages[0]]
          : <int?>[pages[0], null],
    );
  }

  bool get blankOnLeft => isBlankSlot && direction == ComicReadingDirection.rtl;
  bool get blankOnRight =>
      isBlankSlot && direction == ComicReadingDirection.ltr;

  /// 页码标签，如「P1」「P2–P3」；补白槽不写进页码，避免被误读成缺页。
  String get pageLabel => pages.length == 1
      ? 'P${pages.first + 1}'
      : 'P${pages.first + 1}–P${pages.last + 1}';

  /// 供 UI 说明用的一句话口径，页面不自己拼 isCover / isWide 判断。
  String get soloReason {
    if (isCover) return '封面独占一跨';
    if (isWide) return '宽幅页独占一跨';
    if (isBlankSlot) return '奇数末页补白 · 非缺页';
    return '单页';
  }

  @override
  bool operator ==(Object other) =>
      other is ComicSpread &&
      other.index == index &&
      other.direction == direction &&
      other.doublePage == doublePage &&
      other.isCover == isCover &&
      other.isWide == isWide &&
      _samePages(other.pages, pages);

  @override
  int get hashCode => Object.hash(
        index,
        Object.hashAll(pages),
        direction,
        doublePage,
        isCover,
        isWide,
      );

  static bool _samePages(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 整本漫画的跨页编排。跨序列**恒按阅读顺序**排列（第 0 跨是封面）；
/// RTL 只通过 `viewIndexForSpread` 把 PageView 的视觉索引反转，不改阅读顺序。
@immutable
class ComicSpreadLayout {
  const ComicSpreadLayout({
    required this.spreads,
    required this.direction,
    required this.doublePage,
    required this.pageCount,
  });

  final List<ComicSpread> spreads;
  final ComicReadingDirection direction;
  final bool doublePage;
  final int pageCount;

  int get spreadCount => spreads.length;
  bool get isEmpty => spreads.isEmpty;
  bool get isRtl => direction == ComicReadingDirection.rtl;

  /// 封面独占一跨时，其后才是两两成跨；用于 UI 说明，不参与计算。
  bool get hasCoverSpread =>
      spreads.isNotEmpty && spreads.first.isCover && doublePage;

  /// 宽幅独占跨数量，供阅读器状态栏说明。
  int get wideSpreadCount => spreads.where((ComicSpread s) => s.isWide).length;

  ComicSpread at(int spreadIndex) {
    if (isEmpty) {
      throw StateError('空漫画布局没有跨页；调用方应先检查 isEmpty');
    }
    return spreads[spreadIndex.clamp(0, spreadCount - 1).toInt()];
  }

  /// 页 → 跨：跨按页升序排列，二分反查；越界夹住，绝不抛 RangeError。
  int spreadForPage(int page) {
    if (isEmpty) return 0;
    final int target = page.clamp(0, pageCount - 1).toInt();
    int lo = 0;
    int hi = spreadCount - 1;
    while (lo < hi) {
      final int mid = (lo + hi) >> 1;
      if (spreads[mid].lastPage < target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// 视觉 PageView 索引 ↔ 跨索引。
  /// LTR 恒等；RTL 反转，使「下一跨」对应 viewIndex - 1（手指从左往右滑）。
  int viewIndexForSpread(int spreadIndex) {
    if (isEmpty) return 0;
    final int s = spreadIndex.clamp(0, spreadCount - 1).toInt();
    return isRtl ? spreadCount - 1 - s : s;
  }

  int spreadForViewIndex(int viewIndex) {
    if (isEmpty) return 0;
    final int v = viewIndex.clamp(0, spreadCount - 1).toInt();
    return isRtl ? spreadCount - 1 - v : v;
  }

  int viewIndexForPage(int page) => viewIndexForSpread(spreadForPage(page));

  /// 初始视觉索引：RTL 从最后一格起（那里放的是第 0 跨 = 封面）。
  int get initialViewIndex => isRtl ? spreadCount - 1 : 0;

  ComicSpread spreadAtViewIndex(int viewIndex) =>
      at(spreadForViewIndex(viewIndex));

  /// 「前进到下一跨」在 PageView 索引上的步进：RTL 为 -1。
  int get forwardStep => isRtl ? -1 : 1;

  /// 点按前进落在哪半屏：RTL 是左半屏。
  bool get advanceOnTapLeft => isRtl;

  /// 预取窗口应覆盖的全部真实页（当前跨 + 相邻一跨），供批量 prefetch 用。
  List<int> prefetchPagesFor(int page, {int neighborSpreads = 1}) {
    if (isEmpty) return const <int>[];
    final int center = spreadForPage(page);
    final Set<int> out = <int>{};
    for (int i = center - neighborSpreads; i <= center + neighborSpreads; i++) {
      if (i < 0 || i >= spreadCount) continue;
      out.addAll(spreads[i].pages);
    }
    final List<int> sorted = out.toList()..sort();
    return List<int>.unmodifiable(sorted);
  }

  static ComicSpreadLayout get empty => const ComicSpreadLayout(
        spreads: <ComicSpread>[],
        direction: ComicReadingDirection.ltr,
        doublePage: false,
        pageCount: 0,
      );
}

/// 双页跨页的**书脊留白**度量（第二十轮）。
///
/// 第十五轮把两页并排时，中间只有一条固定的 `SizedBox(width: LrSpacing.xs)`，
/// 既没有装订感，宽屏上又显得过窄。本层把「留白宽度 / 内侧渐暗 / 跨间留白」
/// 收口成纯 Dart 计算，视图只取数值，不自己写 magic number。
///
/// **三条口径**：
/// 1. **只有两页真实页并排才画书脊**（`spread.isDouble`）。封面独占位、
///    宽幅页独占、奇数末页补白都只有一个真实页，中间是「补白槽」不是书脊，
///    画渐暗会让人误以为那里缺了半张图。
/// 2. **RTL 不改变书脊位置**：书脊永远在视觉中间；早页 / 晚页的左右关系已由
///    `visualSlots` 处理，这里只按「左视觉槽 / 右视觉槽」叠内侧渐暗。
/// 3. 所有数值按槽宽比例计算并夹在上下限内，避免折叠屏 / 平板宽度抖动。
///
/// **静态边界**：只算布局数值，不解码图片、不读文件字节、不查设备方向。
class ComicSpreadGutter {
  const ComicSpreadGutter._();

  /// 书脊宽度占单个槽宽的比例。
  static const double widthRatio = 0.035;
  static const double minWidthPx = 8.0;
  static const double maxWidthPx = 28.0;

  /// 非书脊跨（封面 / 宽幅 / 补白 / 单页模式）两个槽之间的默认间距。
  static const double fallbackGapPx = 8.0;

  /// 内侧渐暗占槽宽的比例，且不超过书脊宽度的 1.5 倍。
  static const double innerShadeRatio = 0.16;
  static const double innerShadeToGutterRatio = 1.5;
  static const double innerShadeOpacity = 0.20;

  /// 跨间留白（每跨外层的 padding），按整页宽比例计算并夹住。
  static const double outerRatio = 0.024;
  static const double minOuterPx = 8.0;
  static const double maxOuterPx = 20.0;

  /// 只有两页真实页并排时才有书脊。
  static bool hasSpine(ComicSpread spread) => spread.isDouble;

  static double width(double slotWidth) {
    if (slotWidth <= 0) return minWidthPx;
    return (slotWidth * widthRatio).clamp(minWidthPx, maxWidthPx).toDouble();
  }

  /// 两个视觉槽之间应留的间距：书脊跨用计算宽度，其余用固定值。
  static double gapFor(ComicSpread spread, double slotWidth) =>
      hasSpine(spread) ? width(slotWidth) : fallbackGapPx;

  static double innerShadeWidth(double slotWidth) {
    if (slotWidth <= 0) return 0;
    final double bySlot = slotWidth * innerShadeRatio;
    final double byGutter = width(slotWidth) * innerShadeToGutterRatio;
    return (bySlot < byGutter ? bySlot : byGutter)
        .clamp(0, slotWidth / 2)
        .toDouble();
  }

  static double outerPadding(double fullPageWidth) {
    if (fullPageWidth <= 0) return minOuterPx;
    return (fullPageWidth * outerRatio)
        .clamp(minOuterPx, maxOuterPx)
        .toDouble();
  }

  /// 供状态栏说明：当前布局里有多少跨会有书脊。
  static int spineCount(ComicSpreadLayout layout) =>
      layout.spreads.where((ComicSpread s) => hasSpine(s)).length;

  // ---- 第二十一轮：渐暗强度模型化 ----
  //
  // 第二十轮把 opacity 写死成 0.20 的黑渐暗，两处真实缺陷：
  // 1. 夜间 / 深色季节下占位卡是深玻璃，黑叠黑几乎看不见；
  // 2. 宽屏书脊宽到 28px，渐暗却仍是同一个固定比例与强度，毫无自适应。
  //
  // 本轮把「强度档位 → 不透明度 / 渐暗宽度」做成可计算的纯 Dart 模型，
  // 并按**槽宽自动选档**、按**背景亮度反推目标色**。仍然是固定视觉规则：
  // 不进 ReaderStyle、不做用户可调偏好、不涉及 layoutKey（决策 110 不变）。
  // 静态阶段只做模型，不接真机调参。

  /// 深底判据：WCAG 相对亮度 ≤ 0.18 时改用浅色内高光，避免黑叠黑。
  static const double darkBackgroundThreshold = 0.18;

  /// 深底高光的强度折减系数（高光比阴影更含蓄，别把书脊画成一条白线）。
  static const double darkShadeFactor = 0.55;

  static const Map<ComicSpineShadeStrength, double> shadeOpacity =
      <ComicSpineShadeStrength, double>{
    ComicSpineShadeStrength.subtle: 0.10,
    ComicSpineShadeStrength.normal: 0.20,
    ComicSpineShadeStrength.strong: 0.32,
  };

  static const Map<ComicSpineShadeStrength, double> shadeWidthScale =
      <ComicSpineShadeStrength, double>{
    ComicSpineShadeStrength.subtle: 0.70,
    ComicSpineShadeStrength.normal: 1.0,
    ComicSpineShadeStrength.strong: 1.30,
  };

  /// 按槽宽自动选档：窄屏（手机单页半宽）含蓄、宽屏（平板 / 折叠屏）加强。
  /// 阈值随 `width()` 的上下限走，不另造一套 magic number。
  static ComicSpineShadeStrength strengthFor(double slotWidth) {
    if (slotWidth <= 0 || slotWidth < 300)
      return ComicSpineShadeStrength.subtle;
    if (slotWidth >= 700) return ComicSpineShadeStrength.strong;
    return ComicSpineShadeStrength.normal;
  }

  /// 唯一出口：由「槽宽 + 背景亮度」反推这一跨的渐暗规格。
  ///
  /// `backgroundLuminance` 由视图用 `ReaderStyle.relativeLuminance()` 传入，
  /// 亮度算法只有一个出口，core/comic 不反向依赖 core/state。
  /// `strength` 传 null 时按槽宽自动选档；显式传值便于单测逐档验证。
  static ComicSpineShadeSpec resolveShade({
    required double slotWidth,
    required double backgroundLuminance,
    ComicSpineShadeStrength? strength,
  }) {
    final ComicSpineShadeStrength level = strength ?? strengthFor(slotWidth);
    final double baseWidth = innerShadeWidth(slotWidth);
    final double widthPx = (baseWidth * shadeWidthScale[level]!)
        .clamp(0, slotWidth <= 0 ? 0 : slotWidth / 2)
        .toDouble();
    final bool dark = backgroundLuminance <= darkBackgroundThreshold;
    final double baseOpacity = shadeOpacity[level]!;
    return ComicSpineShadeSpec(
      // 浅底用黑色阴影；深底改成白色内高光并折减强度。
      color: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      opacity: (dark ? baseOpacity * darkShadeFactor : baseOpacity)
          .clamp(0.0, 1.0)
          .toDouble(),
      width: widthPx,
      strength: level,
      onDarkBackground: dark,
    );
  }
}

/// 模型层档位。**不是用户设置**：按槽宽自动选，或由规格单测显式指定。
enum ComicSpineShadeStrength { subtle, normal, strong }

/// 一跨的渐暗规格。视图只取这三个数值，不自己算强度、不自己挑颜色。
@immutable
class ComicSpineShadeSpec {
  const ComicSpineShadeSpec({
    required this.color,
    required this.opacity,
    required this.width,
    required this.strength,
    required this.onDarkBackground,
  });

  final Color color;
  final double opacity;
  final double width;
  final ComicSpineShadeStrength strength;
  final bool onDarkBackground;

  /// 单槽 / 补白跨（width=0）或零强度时不渲染渐暗层。
  bool get visible => opacity > 0 && width > 0;

  @override
  bool operator ==(Object other) =>
      other is ComicSpineShadeSpec &&
      other.color == color &&
      other.opacity == opacity &&
      other.width == width &&
      other.strength == strength &&
      other.onDarkBackground == onDarkBackground;

  @override
  int get hashCode =>
      Object.hash(color, opacity, width, strength, onDarkBackground);
}

/// 把「偏好 + 页面尺寸 + 页数」解析成跨页编排的唯一出口。
class ComicSpreadResolver {
  const ComicSpreadResolver._();

  /// 宽高比阈值：宽 >= 高 × 1.15 视为横屏。留出余量，避免折叠屏近似正方时抖动。
  static const double landscapeThreshold = 1.15;

  static bool isLandscape(Size pageSize,
      {double threshold = landscapeThreshold}) {
    if (pageSize.height <= 0 || pageSize.width <= 0) return false;
    return pageSize.width >= pageSize.height * threshold;
  }

  static bool resolveDoublePage(
    ComicSpreadMode mode,
    Size pageSize, {
    double threshold = landscapeThreshold,
  }) {
    switch (mode) {
      case ComicSpreadMode.single:
        return false;
      case ComicSpreadMode.double:
        return true;
      case ComicSpreadMode.auto:
        return isLandscape(pageSize, threshold: threshold);
    }
  }

  /// 宽幅判定阈值：宽 >= 高 × 1.45。比横屏阈值 1.15 更严，
  /// 只把「明显横向铺开的彩图 / 跨页大图」挑出来，普通横屏页仍参与双页配对。
  static const double wideThreshold = 1.45;

  /// `aspectRatios[i]` 是第 i 页的 宽/高。静态阶段来自确定性占位值，
  /// 真实实现来自 `PageInfo.aspectRatio`（❄️ 冻结）。缺位或非法值一律不算宽幅。
  static bool isWidePage(
    int pageIndex,
    List<double>? aspectRatios, {
    double threshold = wideThreshold,
  }) {
    if (aspectRatios == null ||
        pageIndex < 0 ||
        pageIndex >= aspectRatios.length) {
      return false;
    }
    final double r = aspectRatios[pageIndex];
    return r.isFinite && r >= threshold;
  }

  static ComicSpreadLayout build({
    required int pageCount,
    required ComicSpreadMode mode,
    required ComicReadingDirection direction,
    required Size pageSize,
    double threshold = landscapeThreshold,
    List<double>? aspectRatios,
    double wideThresholdValue = wideThreshold,
    bool respectWidePages = true,
  }) {
    if (pageCount <= 0) return ComicSpreadLayout.empty;

    final bool doublePage =
        resolveDoublePage(mode, pageSize, threshold: threshold);
    final List<ComicSpread> spreads = <ComicSpread>[];

    void add(List<int> pages, {bool isCover = false, bool isWide = false}) {
      spreads.add(ComicSpread(
        index: spreads.length,
        pages: List<int>.unmodifiable(pages),
        direction: direction,
        doublePage: doublePage,
        isCover: isCover,
        isWide: isWide,
      ));
    }

    bool wide(int i) =>
        doublePage &&
        respectWidePages &&
        isWidePage(i, aspectRatios, threshold: wideThresholdValue);

    if (doublePage) {
      // 封面永远独占一跨：把两张不相关的页强行并排是漫画阅读最常见的错误。
      add(<int>[0], isCover: true);
      int cursor = 1;
      while (cursor < pageCount) {
        // ① 当前页是宽幅 → 独占一跨，绝不与下一页并排。
        if (wide(cursor)) {
          add(<int>[cursor], isWide: true);
          cursor += 1;
          continue;
        }
        // ② 下一页是宽幅（或已到末页）→ 当前页也独占一跨。
        //    这里会产生「单页 + 宽幅页」两个连续跨，但语义正确：
        //    宽幅页不与任何邻页并排，宁可多一个补白槽也不拆开一张横幅图。
        final int next = cursor + 1;
        if (next >= pageCount || wide(next)) {
          add(<int>[cursor]);
          cursor += 1;
        } else {
          add(<int>[cursor, next]);
          cursor += 2;
        }
      }
    } else {
      // 单页模式每页本来就独占一跨，宽幅标记不参与编排（避免无意义补白）。
      for (int i = 0; i < pageCount; i++) {
        add(<int>[i], isCover: i == 0);
      }
    }

    return ComicSpreadLayout(
      spreads: List<ComicSpread>.unmodifiable(spreads),
      direction: direction,
      doublePage: doublePage,
      pageCount: pageCount,
    );
  }
}
