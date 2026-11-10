import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/model/comic/comic_spread.dart';
import '../../core/model/comic/comic_toc.dart';
import '../../core/model/book_document.dart';
import '../../assembly/app_scope.dart';
import '../../core/model/reader_style.dart';
import '../../core/common/design_tokens.dart';
import '../../core/ui/components/glass.dart';
import 'comic_prefetch.dart';
import 'page_turn_view.dart';
import '../../l10n/lr_localizations.dart';

/// 从阅读器外部发跳转指令，不改变页面栈。
/// 用 ValueNotifier 而不是 GlobalKey<State>，页面重建也不会丢指令。
/// 指令始终是**页索引**，跨页换算由视图内部完成——话集目录零改动。
class ComicReaderController {
  final ValueNotifier<int?> jumpRequest = ValueNotifier<int?>(null);

  void jumpToPage(int page) => jumpRequest.value = page;

  void dispose() => jumpRequest.dispose();
}

/// 漫画阅读视图：竖向连续滚动 / 横向跨页翻页（单页、双页、自动；左→右、右→左）。
///
/// **静态边界**：页像素由 BookRenderBridge 提供（❄️ 冻结），这里只做
/// 「页序 → 跨页 → 视觉槽位 → 占位高度 → 当前话」的编排，不解码图片、
/// 不返回空白页假装能读。补白槽显式标注「补白槽 · 非缺页」。
/// 预取窗口只在**当前页变化**时批量 prefetch/evict，不在滚动回调里逐帧跨 channel。
class ComicReaderView extends StatefulWidget {
  const ComicReaderView({
    super.key,
    required this.document,
    required this.style,
    required this.prefetch,
    required this.pageSize,
    required this.controller,
    this.aspectRatios,
    this.onVisiblePage,
  });

  final BookDocument document;
  final ReaderStyle style;
  final ComicPrefetchWindow prefetch;
  final Size pageSize;
  final ComicReaderController controller;

  /// 真实实现来自 PageInfo.aspectRatio；静态阶段用确定性占位值。
  final List<double>? aspectRatios;
  final ValueChanged<int>? onVisiblePage;

  @override
  State<ComicReaderView> createState() => _ComicReaderViewState();
}

class _ComicReaderViewState extends State<ComicReaderView> {
  final ScrollController _vertical = ScrollController();
  late PageController _paged;

  late ComicLayoutMetrics _metrics;
  late ComicLayoutMetrics _halfMetrics;
  late List<ComicPageItem> _items;
  late List<double> _prefix;
  late ComicSpreadLayout _layout;
  int _currentPage = 0;

  ComicToc get _toc => widget.document.comicToc!;
  bool get _verticalMode =>
      widget.style.comicReadMode == ComicReadMode.vertical;

  /// 第二十一轮：状态栏显示当前渐暗档位与深浅底模式。
  /// 数值仍由 `ComicSpreadGutter.resolveShade` 裁决，这里只做展示，
  /// 不写第二套强度规则；单页 / 竖向模式没有书脊，返回空串。
  String get _spineShadeLabel {
    if (!_layout.doublePage || _verticalMode) return '';
    final double lum =
        ReaderStyle.relativeLuminance(widget.style.backgroundColor);
    final ComicSpineShadeSpec spec = ComicSpreadGutter.resolveShade(
      slotWidth: _halfMetrics.pageWidth,
      backgroundLuminance: lum,
    );
    final String level = <ComicSpineShadeStrength, String>{
      ComicSpineShadeStrength.subtle: lrText('uiWeak'),
      ComicSpineShadeStrength.normal: lrText('uiMedium'),
      ComicSpineShadeStrength.strong: lrText('uiStrong'),
    }[spec.strength]!;
    return lrTextArgs('uiShade', <Object?>[
      level,
      spec.onDarkBackground
          ? lrText('uiLightInnerHighlight')
          : lrText('uiBlackShadow')
    ]);
  }

  @override
  void initState() {
    super.initState();
    _rebuildVerticalMetrics();
    _rebuildSpreadLayout();
    // RTL 的初始视觉索引不是 0：第 0 跨（封面）放在最后一格。
    _paged = PageController(initialPage: _layout.initialViewIndex);
    // 静态阶段没有真实 handle：attach 只登记页数，prefetch/evict 在
    // UnimplementedRenderBridge 上是空操作，不会抛未处理异常。
    widget.prefetch.attach(0, _toc.pageCount);
    widget.controller.jumpRequest.addListener(_onJumpRequest);
    _vertical.addListener(_onVerticalScroll);
    // initState 里只初始化预取窗口；进度回调交给首帧后的滚动 / 跳转触发，
    // 避免在父页 build 期间回写状态（会触发 markNeedsBuild during build）。
    _syncPrefetch();
  }

  @override
  void didUpdateWidget(covariant ComicReaderView old) {
    super.didUpdateWidget(old);
    final bool metricsChanged = old.pageSize != widget.pageSize ||
        old.aspectRatios != widget.aspectRatios;
    final bool layoutChanged = metricsChanged ||
        old.style.comicReadMode != widget.style.comicReadMode ||
        old.style.comicSpreadMode != widget.style.comicSpreadMode ||
        old.style.comicDirection != widget.style.comicDirection ||
        old.style.widePageSolo != widget.style.widePageSolo;
    if (metricsChanged) _rebuildVerticalMetrics();
    if (layoutChanged) {
      _rebuildSpreadLayout();
      // 换跨页布局后把新视图对齐到同一页，避免「切到双页又回到封面」；
      // 同时按新跨页重算预取窗口（双页要一次覆盖两页）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_verticalMode) {
          if (_vertical.hasClients) _vertical.jumpTo(_prefix[_currentPage]);
        } else {
          final int view = _layout.viewIndexForPage(_currentPage);
          if (_paged.hasClients) _paged.jumpToPage(view);
        }
        _syncPrefetch(force: true);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.jumpRequest.removeListener(_onJumpRequest);
    _vertical.removeListener(_onVerticalScroll);
    _vertical.dispose();
    _paged.dispose();
    super.dispose();
  }

  void _rebuildVerticalMetrics() {
    _metrics = ComicLayoutMetrics(pageWidth: widget.pageSize.width);
    _halfMetrics = ComicLayoutMetrics(pageWidth: widget.pageSize.width / 2);
    _items = ComicLayoutMetrics.buildItems(
      _toc,
      aspectRatios: widget.aspectRatios,
    );
    _prefix = _metrics.prefixOffsets(_items);
  }

  void _rebuildSpreadLayout() {
    // 竖向连续没有左右概念：即便外部传了脏组合也锁回单页 / 左→右，
    // 与 AppSettings.normalized() 的第三条归一化保持同一口径。
    _layout = ComicSpreadResolver.build(
      pageCount: _toc.pageCount,
      mode:
          _verticalMode ? ComicSpreadMode.single : widget.style.comicSpreadMode,
      direction: _verticalMode
          ? ComicReadingDirection.ltr
          : widget.style.comicDirection,
      pageSize: widget.pageSize,
      // 第十九轮：宽幅页（横幅 / 跨页彩图）独占一跨。占位宽高比来自
      // 确定性演示值，真实值来自 PageInfo.aspectRatio（❄️ 冻结）。
      aspectRatios: widget.aspectRatios,
      respectWidePages: widget.style.widePageSolo,
    );
  }

  void _onJumpRequest() {
    final int? page = widget.controller.jumpRequest.value;
    if (page == null) return;
    widget.controller.jumpRequest.value = null;
    _applyJump(page.clamp(0, _toc.pageCount - 1).toInt());
  }

  /// 目录回传的 pageStart 在这里换算成「跨 → 视觉索引」，目录页不需知道双页/RTL。
  void _applyJump(int page) {
    if (_verticalMode) {
      if (_vertical.hasClients) {
        _vertical.animateTo(
          _prefix[page],
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      if (_paged.hasClients) _paged.jumpToPage(_layout.viewIndexForPage(page));
    }
    _notifyPage(page);
  }

  void _onVerticalScroll() {
    if (!_vertical.hasClients) return;
    final int page = _metrics.pageAtOffset(_prefix, _vertical.offset);
    if (page != _currentPage) _notifyPage(page);
  }

  /// 当前页变化时才通知：预取窗口与进度采样都不逐帧触发。
  void _notifyPage(int page) {
    final int clamped = page.clamp(0, _toc.pageCount - 1).toInt();
    if (clamped == _currentPage && widget.prefetch.activeWindow.isNotEmpty)
      return;
    _currentPage = clamped;
    _syncPrefetch();
    widget.onVisiblePage?.call(clamped);
    if (mounted) setState(() {});
  }

  /// 竖向按单页窗口；横向跨页按「当前跨 + 相邻一跨」批量覆盖，双页不漏预取。
  void _syncPrefetch({bool force = false}) {
    if (force) {
      // 布局刚变化时即便页没变也要重算窗口；保留旧窗口让 moveToPages 做差集 evict。
      widget.prefetch.invalidate();
    }
    final List<int> pages = _verticalMode
        ? <int>[_currentPage]
        : _layout.prefetchPagesFor(_currentPage);
    widget.prefetch.moveToPages(pages);
  }

  @override
  Widget build(BuildContext context) {
    final ComicEpisode? episode = _toc.episodeForPage(_currentPage);
    final int spreadIndex = _layout.spreadForPage(_currentPage);
    final TextTheme text = Theme.of(context).textTheme;
    final String directionLabel =
        ComicSpreadLabels.direction[_layout.direction]!;

    return Column(
      children: <Widget>[
        Expanded(
          child: _verticalMode ? _buildVertical() : _buildPaged(),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: LrSpacing.m, vertical: LrSpacing.s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            episode?.label ?? context.t('uiComics'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge
                                ?.copyWith(color: widget.style.textColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'P${_currentPage + 1} / ${_toc.pageCount} · ' +
                                context.tArgs('uiSpread', <Object?>[
                                  spreadIndex + 1,
                                  _layout.spreadCount
                                ]) +
                                context.tArgs('uiPhrase317', <Object?>[
                                  ComicModeLabels
                                      .labels[widget.style.comicReadMode]
                                ]) +
                                context.tArgs('uiPhrase007', <Object?>[
                                  _verticalMode ? '' : ' · $directionLabel'
                                ]) +
                                context.tArgs('uiPhrase017', <Object?>[
                                  _layout.wideSpreadCount > 0
                                      ? lrTextArgs('uiWideSoloN',
                                          <Object?>[_layout.wideSpreadCount])
                                      : ''
                                ]) +
                                context.tArgs('uiPhrase021', <Object?>[
                                  ComicSpreadGutter.spineCount(_layout) > 0
                                      ? lrTextArgs('uiSpineN', <Object?>[
                                          ComicSpreadGutter.spineCount(_layout)
                                        ])
                                      : ''
                                ]) +
                                context.tArgs('uiPhrase010', <Object?>[
                                  _spineShadeLabel.isEmpty
                                      ? ''
                                      : ' · $_spineShadeLabel'
                                ]),
                            style: text.labelSmall
                                ?.copyWith(color: widget.style.subtleTextColor),
                          ),
                        ],
                      ),
                    ),
                    // 模式切换写回全局排版设置，与「我的」页的面板读同一份。
                    IconButton(
                      tooltip: _verticalMode
                          ? context.t('uiSwitchToHorizontalPaging')
                          : context.t('uiSwitchToVerticalScroll'),
                      color: widget.style.textColor,
                      onPressed: () => _updateStyle(
                        widget.style.copyWith(
                          comicReadMode: _verticalMode
                              ? ComicReadMode.paged
                              : ComicReadMode.vertical,
                        ),
                      ),
                      icon: Icon(
                          _verticalMode ? Icons.swap_horiz : Icons.swap_vert,
                          size: 20),
                    ),
                    if (!_verticalMode) ...<Widget>[
                      // 单页 → 双页 → 自动 循环；只在横向跨页模式出现。
                      IconButton(
                        tooltip: context.tArgs('uiSpreadsPages', <Object?>[
                          ComicSpreadLabels.mode[widget.style.comicSpreadMode]
                        ]),
                        color: widget.style.textColor,
                        onPressed: () => _updateStyle(
                          widget.style.copyWith(
                            comicSpreadMode:
                                _nextSpreadMode(widget.style.comicSpreadMode),
                          ),
                        ),
                        icon: Icon(
                          widget.style.comicSpreadMode == ComicSpreadMode.single
                              ? Icons.looks_one_outlined
                              : (widget.style.comicSpreadMode ==
                                      ComicSpreadMode.double
                                  ? Icons.looks_two_outlined
                                  : Icons.auto_awesome_motion_outlined),
                          size: 20,
                        ),
                      ),
                      // 左→右 / 右→左 切换；视觉索引映射由 ComicSpreadLayout 负责。
                      IconButton(
                        tooltip: context
                            .tArgs('uiPages3', <Object?>[directionLabel]),
                        color: widget.style.textColor,
                        onPressed: () => _updateStyle(
                          widget.style.copyWith(
                            comicDirection: _layout.isRtl
                                ? ComicReadingDirection.ltr
                                : ComicReadingDirection.rtl,
                          ),
                        ),
                        icon: Icon(
                          _layout.isRtl
                              ? Icons.arrow_back_ios_new
                              : Icons.arrow_forward_ios,
                          size: 18,
                        ),
                      ),
                    ],
                  ],
                ),
                if (_verticalMode)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.t('comicVerticalLockNote'),
                      style: text.labelSmall
                          ?.copyWith(color: widget.style.subtleTextColor),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${ComicSpreadLabels.mode[widget.style.comicSpreadMode]} · '
                      '${ComicSpreadLabels.modeHint[widget.style.comicSpreadMode]}\n'
                      '${context.t('comicSpreadStaticNote')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall
                          ?.copyWith(color: widget.style.subtleTextColor),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _updateStyle(ReaderStyle next) {
    if (!mounted) return;
    AppScope.of(context).updateReader(next);
  }

  static ComicSpreadMode _nextSpreadMode(ComicSpreadMode current) {
    final int next = (current.index + 1) % ComicSpreadMode.values.length;
    return ComicSpreadMode.values[next];
  }

  Widget _buildVertical() {
    return ListView.builder(
      controller: _vertical,
      padding: const EdgeInsets.symmetric(
          horizontal: LrSpacing.m, vertical: LrSpacing.s),
      itemCount: _items.length,
      itemBuilder: (BuildContext context, int i) => SizedBox(
        height: _metrics.itemHeight(_items[i]),
        child: _PageSlot(
          item: _items[i],
          pageHeight: _metrics.pageHeight(_items[i]),
          headerHeight: _metrics.headerHeight,
          style: widget.style,
          gap: _metrics.pageGap,
        ),
      ),
    );
  }

  Widget _buildPaged() {
    return PageTurnView(
      controller: _paged,
      itemCount: _layout.spreadCount,
      rtl: _layout.isRtl,
      onPageChanged: (int viewIndex) {
        _notifyPage(_layout.spreadAtViewIndex(viewIndex).primaryPage);
      },
      itemBuilder: (BuildContext context, int viewIndex) => _SpreadSlot(
        spread: _layout.spreadAtViewIndex(viewIndex),
        items: _items,
        fullWidthMetrics: _metrics,
        halfWidthMetrics: _halfMetrics,
        maxHeight: widget.pageSize.height - 2 * LrSpacing.m - 64,
        style: widget.style,
      ),
      turn: widget.style.pageTurn,
    );
  }
}

/// 一个跨页：按 visualSlots 从左到右排 1~2 个槽，null 槽显式标「补白槽 · 非缺页」。
class _SpreadSlot extends StatelessWidget {
  const _SpreadSlot({
    required this.spread,
    required this.items,
    required this.fullWidthMetrics,
    required this.halfWidthMetrics,
    required this.maxHeight,
    required this.style,
  });

  final ComicSpread spread;
  final List<ComicPageItem> items;
  final ComicLayoutMetrics fullWidthMetrics;
  final ComicLayoutMetrics halfWidthMetrics;
  final double maxHeight;
  final ReaderStyle style;

  @override
  Widget build(BuildContext context) {
    final List<int?> slots = spread.visualSlots;
    // 宽幅页 / 封面独占都会产生补白槽，必须写清原因，不把补白误读成缺页。
    final String soloNote = spread.isSolo ? spread.soloReason : '';
    // 单页跨占满整屏宽度，不能拿半宽度量算页高，否则页面会莫名变矮。
    final ComicLayoutMetrics metrics =
        spread.doublePage ? halfWidthMetrics : fullWidthMetrics;
    // 第二十轮：书脊宽度 / 内侧渐暗 / 跨间留白全部由 ComicSpreadGutter 裁决。
    // 只有两页真实页并排才有书脊；RTL 只改槽位顺序，书脊永远在视觉中间。
    // 第二十一轮：渐暗不再写死 0.20 黑，改由「槽宽 + 背景亮度」反推规格——
    // 夜间 / 深色季节下深玻璃卡黑叠黑看不见，模型会自动换成折减的白色内高光。
    // 亮度算法复用 ReaderStyle.relativeLuminance()，core/comic 不反向依赖 state。
    final double slotWidth = metrics.pageWidth;
    final bool spine = ComicSpreadGutter.hasSpine(spread);
    final double gap = ComicSpreadGutter.gapFor(spread, slotWidth);
    final ComicSpineShadeSpec shade = spine
        ? ComicSpreadGutter.resolveShade(
            slotWidth: slotWidth,
            backgroundLuminance:
                ReaderStyle.relativeLuminance(style.backgroundColor),
          )
        : const ComicSpineShadeSpec(
            color: Color(0xFF000000),
            opacity: 0,
            width: 0,
            strength: ComicSpineShadeStrength.subtle,
            onDarkBackground: false,
          );
    final double outer =
        ComicSpreadGutter.outerPadding(fullWidthMetrics.pageWidth);
    return Padding(
      padding: EdgeInsets.all(outer),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < slots.length; i++) ...<Widget>[
            if (slots[i] != null)
              Expanded(
                child: _SpineShadedSlot(
                  // 左视觉槽的右边缘、右视觉槽的左边缘各叠一层渐暗。
                  // 单槽 / 补白跨 spine=false，渐暗宽度 0，组件直接返回 child。
                  shadeRight: spine && i == 0,
                  shadeLeft: spine && i == slots.length - 1,
                  shade: shade,
                  child: _PageSlot(
                    item: items[slots[i]!],
                    pageHeight: metrics
                        .pageHeight(items[slots[i]!])
                        .clamp(0, maxHeight)
                        .toDouble(),
                    headerHeight: metrics.headerHeight,
                    style: style,
                    gap: 0,
                    showHeader: false,
                  ),
                ),
              )
            else
              Expanded(
                child: _BlankSlot(
                  note: soloNote.isEmpty
                      ? context.t('comicBlankSlotNote')
                      : soloNote,
                ),
              ),
            // 只在两个槽之间留缝，末尾不白占宽度；书脊跨用计算宽度。
            if (i < slots.length - 1) SizedBox(width: gap),
          ],
        ],
      ),
    );
  }
}

class _BlankSlot extends StatelessWidget {
  const _BlankSlot({required this.note});

  /// 补白槽不是缺页：封面 / 宽幅页 / 奇数末页各有各的原因，由模型层给出。
  final String note;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.s),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.crop_din_outlined,
                size: 24, color: Theme.of(context).disabledColor),
            const SizedBox(height: LrSpacing.s),
            Text(
              note,
              textAlign: TextAlign.center,
              style: text.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageSlot extends StatelessWidget {
  const _PageSlot({
    required this.item,
    required this.pageHeight,
    required this.headerHeight,
    required this.style,
    required this.gap,
    this.showHeader = true,
  });

  final ComicPageItem item;
  final double pageHeight;
  final double headerHeight;
  final ReaderStyle style;
  final double gap;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? header = item.headerLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showHeader && header != null)
          SizedBox(
            // 必须与 ComicLayoutMetrics.headerHeight 一致，否则滚动偏移会漂移。
            height: headerHeight,
            child: Row(
              children: <Widget>[
                Icon(Icons.bookmark_outline,
                    size: 15, color: style.subtleTextColor),
                const SizedBox(width: LrSpacing.s),
                Expanded(
                  child: Text(
                    header,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(color: style.textColor),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: pageHeight,
          // TODO(静态冻结): 换成 BookRenderBridge.render(handle, index, targetPx)
          // 的 Texture / Image.memory；目前只按宽高比占位，不解码图片。
          child: GlassPanel(
            padding: EdgeInsets.zero,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.image_outlined,
                      size: 30, color: style.subtleTextColor),
                  const SizedBox(height: LrSpacing.s),
                  Text(
                    context.tArgs('uiPAspectRatioPlaceholder', <Object?>[
                      item.pageIndex + 1,
                      item.aspectRatio.toStringAsFixed(2)
                    ]),
                    style:
                        text.bodySmall?.copyWith(color: style.subtleTextColor),
                  ),
                  const SizedBox(height: LrSpacing.xs),
                  Text(
                    context.t('comicPlaceholderNote'),
                    style:
                        text.labelSmall?.copyWith(color: style.subtleTextColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (gap > 0) SizedBox(height: gap),
      ],
    );
  }
}

/// 双页书脊的内侧渐暗（第二十轮）。
///
/// 只在 `ComicSpreadGutter.hasSpine()` 为真时生效：左视觉槽右边缘、
/// 右视觉槽左边缘各叠一层透明→暗的渐变，模拟装订阴影。
/// 用 `IgnorePointer` 包住，避免渐变层吞掉翻页点按；不画任何图片像素。
class _SpineShadedSlot extends StatelessWidget {
  const _SpineShadedSlot({
    required this.child,
    required this.shadeRight,
    required this.shadeLeft,
    required this.shade,
  });

  final Widget child;
  final bool shadeRight;
  final bool shadeLeft;

  /// 第二十一轮：颜色 / 不透明度 / 宽度全部来自 `ComicSpineShadeSpec`，
  /// 视图不写死 0.20 的黑色，也不自己按背景挑色。
  final ComicSpineShadeSpec shade;

  @override
  Widget build(BuildContext context) {
    if (!shade.visible || (!shadeRight && !shadeLeft)) return child;
    final Color edge = shade.color.withOpacity(shade.opacity);
    return Stack(
      children: <Widget>[
        child,
        if (shadeRight)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: shade.width,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[Colors.transparent, edge],
                  ),
                ),
              ),
            ),
          ),
        if (shadeLeft)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: shade.width,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[edge, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
