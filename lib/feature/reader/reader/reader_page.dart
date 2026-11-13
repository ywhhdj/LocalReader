import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../domain/repositories/book_repository.dart';
import '../../../core/model/fixtures/demo_document.dart';
import '../../../core/model/pagination/page_layout.dart';
import '../../../core/model/book_document.dart';
import '../../../domain/repositories/render_bridge.dart';
import '../../../data/platform/platform_bridges.dart'
    show PlatformRenderBridge;
import '../../../data/platform/sqlite_runtime.dart' show SqliteRuntime;
import '../../../data/storage/sqlite_progress_store.dart'
    show SqliteProgressStore;
import '../../../data/platform/real_bridges.dart'
    show PlatformTtsBridge, PlatformUnavailable;
import '../../../domain/usecases/tts_queue.dart';
import '../../../assembly/route_args.dart';
import '../../../assembly/app_scope.dart';
import '../../../core/model/reader_style.dart';
import '../../../core/model/stats/excerpt_capture.dart';
import '../../../core/model/stats/line_anchor_resolver.dart';
import '../../../core/model/stats/reading_stats.dart';
import '../../../domain/usecases/progress_sampler.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/components/glass/Nav.dart';
import '../comic/comic_prefetch.dart';
import '../comic/comic_toc_sheet.dart';
import '../vertical_comic_view.dart';
import '../excerpt_capture_sheet.dart';
import '../native_page_view.dart';
import '../fixed_layout_view.dart';
import 'page_turn_view.dart';
import 'reader_style_sheet.dart';
import '../../../l10n/lr_localizations.dart';
import '../../../assembly/app_services.dart';
import '../../../core/ui/motion/immersive_mode.dart';
import '../../../core/model/performance_prefs.dart';
import '../../../core/model/tts_prefs.dart';
import '../../../core/ui/components/book/reader_tap_zones.dart';
import 'tts_orb.dart';
import 'tts_settings_sheet.dart';
import '../../../core/ui/theme/performance_scope.dart';

/// 阅读器：可重排文本走纯 Dart 分页自绘；固定版式走 BookRenderBridge 原生页。
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.book,
    this.chapterIndex = 0,
    this.document,
    this.onOpenToc,
  });

  final BookSummary book;
  final int chapterIndex;

  /// 显式注入文档时可脱离演示数据；未注入时用 DemoDocumentFactory 生成。
  final BookDocument? document;

  /// 由 app 层注入，避免 feature 反向依赖路由表。
  final OpenTocPage? onOpenToc;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  late final BookDocument _document;
  late final ProgressSampler _sampler;
  late final ComicPrefetchWindow _prefetch;
  /// 真实栅格化：PDF / CBZ / 图片型 EPUB 由三端 RenderPlugin 提供页像素。
  /// 通道未注册时由 PlatformRenderBridge 抛出可捕获错误，页面显示占位并提示。
  final BookRenderBridge _renderBridge = const PlatformRenderBridge();
  final PageController _pageController = PageController();

  /// 漫画话集跳转指令：由目录面板选中后发，页面栈不新增阅读器。
  final ComicReaderController _comicController = ComicReaderController();

  late int _chapterIndex;
  PaginationResult? _layoutResult;
  Size? _lastPageSize;
  int? _lastChapter;

  /// 只包含影响排版的字段：换背景 / 换翻页动效不触发重排。
  String? _lastLayoutKey;

  int _pageIndex = 0;
  int _sentenceCount = 0;
  SentenceQueue? _ttsQueue;
  bool _ttsPlaying = false;

  bool _chromeVisible = true;
  bool _immersiveApplied = false;
  TtsPreferences _ttsPrefs = const TtsPreferences();
  final ImmersiveModeController _immersive = const ImmersiveModeController();

  late SelectionDraft _selection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _document = widget.document ?? DemoDocumentFactory.from(widget.book);
    // 漫画文档 chapters 为空，不能拿 length-1 去 clamp。
    _chapterIndex = _document.chapters.isEmpty
        ? 0
        : widget.chapterIndex.clamp(0, _document.chapters.length - 1).toInt();
    _selection = SelectionDraft(
      bookId: _document.id,
      chapterIndex: _chapterIndex,
      pageIndex: 0,
    );
    // 进度写入门控 executor：SQLite 未开启时暂存内存，开启后回放落库，
    // 不再绕过开关直接 new 原生通道。
    _sampler = ProgressSampler(
      store: SqliteProgressStore(SqliteRuntime.instance.executor),
    );
    _prefetch = ComicPrefetchWindow(bridge: _renderBridge);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool enabled =
        AppScope.of(context).settings.performance.immersiveReading;
    if (enabled != _immersiveApplied) {
      _immersiveApplied = enabled;
      // 沉浸模式默认关闭；开启后首帧就收起顶栏，点中间胶囊仍可唤出。
      _chromeVisible = !enabled;
      unawaited(_immersive.apply(enabled));
    }
  }

  @override
  void dispose() {
    // 退出前兜底写一次，对应原项目要求。
    unawaited(_sampler.flush());
    unawaited(_prefetch.release());
    unawaited(_immersive.restore());
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _comicController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_sampler.flush());
    }
  }

  Chapter get _chapter => _document.chapters[_chapterIndex];

  @override
  Widget build(BuildContext context) {
    // 编辑过的书名 / 作者也要同步到顶栏，读同一份 AppState。
    final AppState state = AppScope.of(context);
    final BookSummary book = state.effective(widget.book);
    final ReaderStyle style = state.settings.reader;
    final bool immersive = state.settings.performance.immersiveReading;
    if (immersive != _immersiveApplied) {
      _immersiveApplied = immersive;
      _chromeVisible = !immersive;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_immersive.apply(immersive));
      });
    }

    return Scaffold(
      // 阅读背景独立于 Material 明暗主题：夜间档在系统浅色模式下依然是深色底。
      backgroundColor: style.backgroundColor,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: style.backgroundColor,
              foregroundColor: style.textColor,
              elevation: 0,
              leading: const BackButton(),
              title: Text(book.title),
              actions: <Widget>[
                IconButton(
                  tooltip: state.isFavorite(book.id)
                      ? context.t('uiRemoveFavorite')
                      : context.t('uiFavoriteThisBook'),
                  onPressed: () {
                    final bool added = state.toggleFavorite(book.id);
                    _showHint(added
                        ? context.t('uiAddedToFavorites')
                        : context.t('uiRemovedFromFavorites'));
                  },
                  icon: Icon(state.isFavorite(book.id)
                      ? Icons.star
                      : Icons.star_border),
                ),
                IconButton(
                  tooltip: context.t('uiCaptureSelectedLines'),
                  onPressed: _openExcerptCapture,
                  icon: Icon(
                    _selection.isNotEmpty
                        ? Icons.bookmark_add
                        : Icons.bookmark_add_outlined,
                  ),
                ),
                IconButton(
                  tooltip: context.t('uiTableOfContents'),
                  onPressed: _openToc,
                  icon: const Icon(Icons.list_alt_outlined),
                ),
                IconButton(
                  tooltip: context.t('uiReadAloudSentenceQueue'),
                  onPressed: _onTts,
                  icon: const Icon(Icons.graphic_eq_outlined),
                ),
                IconButton(
                  tooltip: context.t('uiLayoutSettings'),
                  onPressed: _openStyleSheet,
                  icon: const Icon(Icons.text_format_outlined),
                ),
              ],
            )
          : null,
      body: _readerStack(
        context,
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size pageSize = Size(
              constraints.maxWidth - LrSpacing.l * 2,
              constraints.maxHeight - 180,
            );
            if (_document.requiresNativeRender) {
              return _buildNativeBody(context, pageSize, style);
            }
            final PaginationResult result =
                _ensureLayout(context, pageSize, style);
            return _buildTextBody(context, result, style);
          },
        ),
        style,
      ),
    );
  }

  /// 第三十轮：阅读区叠加层。热区只在左下 / 右下角与顶部收起胶囊，
  /// 不铺满正文，不吞掉按行点选；朗读球只在朗读中出现。
  Widget _readerStack(BuildContext context, Widget child, ReaderStyle style) {
    final AppState state = AppScope.of(context);
    final PerformanceBudget budget = PerformanceScope.of(context);
    final bool canTts = state.settings.tts && !_document.isComic;
    final int total = _ttsQueue?.length ?? 0;
    final double progress = total <= 0
        ? 0
        : ((_ttsQueue!.cursor + 1) / total).clamp(0.0, 1.0).toDouble();
    return Stack(
      children: <Widget>[
        child,
        Positioned.fill(
          child: ReaderTapZones(
            chromeVisible: _chromeVisible,
            onToggleChrome: _toggleChrome,
            onPrevious: () => _turnPage(-1),
            onNext: () => _turnPage(1),
            toggleLabel: context.t('readerTapToggle'),
            previousLabel: context.t('readerPrevPage'),
            nextLabel: context.t('readerNextPage'),
          ),
        ),
        if (_ttsPlaying && canTts)
          Positioned.fill(
            child: DraggableTtsProgressOrb(
              title: state.effective(widget.book).title,
              coverPath: null,
              progress: progress,
              playing: _ttsPlaying,
              animationsEnabled: budget.allowInfiniteAnimation,
              snapDuration: budget.snapDuration,
              onTogglePlay: _onTts,
              onClose: _stopTts,
              onOpenSettings: _openTtsSettings,
              pauseLabel: context.t('readerTtsPause'),
              resumeLabel: context.t('readerTtsResume'),
              closeLabel: context.t('readerTtsClose'),
              settingsLabel: context.t('readerTtsSettings'),
              expandLabel: context.t('readerTtsExpand'),
            ),
          ),
        if (!_ttsPlaying && canTts)
          Positioned(
            right: LrSpacing.l,
            bottom: 150,
            child: TtsFab(
              label: context.t('readerTtsStart'),
              onTap: _onTts,
            ),
          ),
      ],
    );
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  void _turnPage(int delta) {
    final PaginationResult? result = _layoutResult;
    if (result == null || result.pages.isEmpty) return;
    final int next =
        (_pageIndex + delta).clamp(0, result.pages.length - 1).toInt();
    if (next == _pageIndex) return;
    if (_pageController.hasClients) {
      _pageController.animateToPage(next,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    } else {
      setState(() => _pageIndex = next);
    }
    _recordProgress(next);
  }

  void _stopTts() {
    _ttsQueue?.pause();
    unawaited(const PlatformTtsBridge().stop());
    setState(() {
      _ttsPlaying = false;
      _ttsQueue = null;
    });
  }

  Future<void> _openTtsSettings() async {
    final AppState state = AppScope.of(context);
    final List<String> voices =
        await AppServices.of(context).device.voiceModels();
    if (!mounted) return;
    await TtsSettingsSheet.open(
      context,
      rate: state.settings.reader.ttsRate,
      pitch: state.settings.reader.ttsPitch,
      timbre: _ttsPrefs.timbre,
      autoNext: _ttsPrefs.autoNext,
      voices: voices,
      voiceName: _ttsPrefs.voiceName,
      onRate: (double v) {
        state.updateSettings(state.settings.copyWith(
          reader: state.settings.reader.copyWith(ttsRate: v),
        ));
        setState(() {});
      },
      onPitch: (double v) {
        state.updateSettings(state.settings.copyWith(
          reader: state.settings.reader.copyWith(ttsPitch: v),
        ));
        setState(() {});
      },
      onTimbre: (TtsTimbre v) =>
          setState(() => _ttsPrefs = _ttsPrefs.copyWith(timbre: v)),
      onAutoNext: (bool v) =>
          setState(() => _ttsPrefs = _ttsPrefs.copyWith(autoNext: v)),
      onVoice: (String v) =>
          setState(() => _ttsPrefs = _ttsPrefs.copyWith(voiceName: v)),
      onOpenSystemTts: () => unawaited(_openSystemTts()),
    );
    if (!mounted) return;
    setState(() => _ttsQueue = null);
  }

  /// 缓存键必须包含章节序号与排版字段：换章复用上一章页码会错位，
  /// 改字号/行高却复用旧分页结果会让「设置不生效」。
  /// 背景、翻页动效、语速不在 layoutKey 里，改它们只换外观、不重排。
  PaginationResult _ensureLayout(
      BuildContext context, Size pageSize, ReaderStyle style) {
    final String key = '${pageSize.width.toStringAsFixed(1)}x'
        '${pageSize.height.toStringAsFixed(1)}|$_chapterIndex|${style.layoutKey}';
    if (_layoutResult != null &&
        _lastPageSize == pageSize &&
        _lastChapter == _chapterIndex &&
        _lastLayoutKey == key) {
      return _layoutResult!;
    }
    _lastPageSize = pageSize;
    _lastChapter = _chapterIndex;
    _lastLayoutKey = key;

    final TextStyle base = Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16, height: 1.75);
    final PaginationConfig config = style.toPaginationConfig(pageSize, base);
    _layoutResult = const PaginationEngine().layout(_chapter, config);
    return _layoutResult!;
  }

  Widget _buildTextBody(
      BuildContext context, PaginationResult result, ReaderStyle style) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<Excerpt> highlights = AppScope.of(context).highlightsFor(
      bookId: _document.id,
      chapterIndex: _chapterIndex,
    );
    // 第十九轮：整章只建一次索引，页面不再手写 O(n·m) 双重循环。
    // 重排漂移 / 文本兜底 / 歧义判定全部收口到 LineAnchorResolver。
    final LineAnchorResolver anchors = LineAnchorResolver.from(highlights);
    return Column(
      children: <Widget>[
        Expanded(
          child: PageTurnView(
            // 选区变化必须让 itemBuilder 重新执行，否则点选后看不到行高亮。
            // 用选区签名做 key，controller 保持不动（页码不会跳回 0）。
            key: ValueKey<String>(
                '$_chapterIndex|$_pageIndex|${_selection.signature()}'),
            controller: _pageController,
            itemCount: result.pages.length,
            onPageChanged: (int i) {
              setState(() {
                _pageIndex = i;
                // 一行锚点只在当前页有效，翻页必须丢弃选区。
                _selection = _selection.switchTo(
                    chapterIndex: _chapterIndex, pageIndex: i);
              });
              _recordProgress(i);
            },
            itemBuilder: (BuildContext context, int i) =>
                _buildTextPage(context, result, i, anchors),
            turn: style.pageTurn,
          ),
        ),
        if (_chromeVisible)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: LrSpacing.m, vertical: LrSpacing.xs),
              child: Row(
                children: <Widget>[
                  IconButton(
                    color: style.textColor,
                    tooltip: context.t('uiPreviousChapter'),
                    onPressed: _chapterIndex > 0
                        ? () => _switchChapter(_chapterIndex - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _chapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              text.labelLarge?.copyWith(color: style.textColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tArgs('uiChapter', <Object?>[
                            _pageIndex + 1,
                            result.pages.length,
                            _chapterIndex + 1,
                            _document.chapters.length
                          ]),
                          style: text.labelSmall
                              ?.copyWith(color: style.subtleTextColor),
                        ),
                        if (_selection.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              context.tArgs('uiLinesSaveexcerpts',
                                  <Object?>[_selection.count]),
                              style: text.labelSmall?.copyWith(
                                  color: HighlightPalette.spine(
                                      HighlightColor.amber)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    color: style.textColor,
                    tooltip: context.t('uiNextChapter'),
                    onPressed: _chapterIndex < _document.chapters.length - 1
                        ? () => _switchChapter(_chapterIndex + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _recordProgress(int pageIndex) {
    _sampler.record(ReadingProgress(
      bookId: _document.id,
      chapterIndex: _chapterIndex,
      pageIndex: pageIndex,
      pageOffset: 0,
      updatedAt: DateTime.now(),
    ));
  }

  void _recordComicProgress(int pageIndex) {
    final int episode = _document.comicToc?.episodeIndexForPage(pageIndex) ?? 0;
    _sampler.record(ReadingProgress(
      bookId: _document.id,
      chapterIndex: episode,
      pageIndex: pageIndex,
      pageOffset: 0,
      updatedAt: DateTime.now(),
    ));
    if (mounted) setState(() => _pageIndex = pageIndex);
  }

  Widget _buildTextPage(
    BuildContext context,
    PaginationResult result,
    int index,
    LineAnchorResolver anchors,
  ) {
    final PaginationConfig config = result.config;
    final LaidOutPage page = result.pages[index];
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: LrSpacing.l, vertical: LrSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ...page.lines.map<Widget>((LaidOutLine line) {
            if (line.isImage) {
              // 真实插图：从文档路径读取字节并交给 Image.memory 解码；
              // 路径缺失 / 原生通道未就绪时才回退到占位卡。
              final String? path = line.imagePath;
              if (path == null || path.isEmpty) {
                return SizedBox(
                  height: line.height,
                  child: GlassPanel(
                      child: Center(
                          child: Text(lrText('uiIllustrationPlaceholder')))),
                );
              }
              return _ImageLine(path: path, height: line.height);
            }

            final LineRef ref = LineRef(
              bookId: _document.id,
              chapterIndex: _chapterIndex,
              pageIndex: index,
              blockIndex: line.blockIndex,
              lineInBlock: line.lineInBlock,
              text: line.text,
            );
            final bool selected =
                _selection.lines.any((SelectedLine l) => l.ref == ref);

            // 已保存的摘录：位置精确 / 位置一致文字已变 / 重排后按文本唯一还原
            // 三级置信度由模型裁决；多处相同文本返回 ambiguous，不自动高亮。
            final LineAnchorMatch? match = anchors.resolve(ref);
            final HighlightColor? savedColor =
                (match != null && match.shouldHighlight)
                    ? match.highlight
                    : null;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selection = _selection.toggle(ref)),
              child: Container(
                height: config.linePx,
                decoration: BoxDecoration(
                  color: selected
                      ? HighlightPalette.lineTint(HighlightColor.amber)
                      : (savedColor == null
                          ? null
                          : HighlightPalette.lineTint(savedColor)),
                  border: Border(
                    left: BorderSide(
                      color: selected
                          ? HighlightPalette.spine(HighlightColor.amber)
                          : (savedColor == null
                              ? Colors.transparent
                              : HighlightPalette.spine(savedColor)),
                      width: selected ? 3 : 2,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(left: line.indent),
                  child: Text(
                    line.text,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: config.textStyle,
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
        ],
      ),
    );
  }

  /// 摘录采集：无选区时给明确引导，不弹一个空面板。
  Future<void> _openExcerptCapture() async {
    if (_document.isComic) {
      // 漫画页没有可重排文本行，按行点选不适用；改为栅格化当前页后
      // 交给原生导出，不再只弹一句「不支持」。
      await _saveComicPage();
      return;
    }
    if (_selection.isEmpty) {
      _showHint(lrText('uiSelectOneOrMoreLinesThenTapTheBookmarkToSaveAn'));
      return;
    }
    final String? invalid = _selection.validationMessage;
    if (invalid != null) {
      _showHint(invalid);
      return;
    }
    final BookSummary book = AppScope.of(context).effective(widget.book);
    final Excerpt? saved = await ExcerptCaptureSheet.open(
      context,
      selection: _selection,
      bookTitle: book.title,
      chapterTitle: _chapter.title,
    );
    if (!mounted) return;
    if (saved == null) {
      _showHint(lrText('uiStatsPages2'));
      return;
    }
    setState(() => _selection = _selection.clear());
    _showHint(lrText('uiSavedToExcerptCardsSeeStats'));
  }

  /// 漫画「摘录」：把当前页栅格化后交给原生导出通道。
  /// 外部纹理（textureId）不能直接拿像素，因此这里主动按目标尺寸请求一次
  /// 编码位图；原生只回纹理时给出明确提示，不让按钮「点了没反应」。
  Future<void> _saveComicPage() async {
    int? handle;
    try {
      final Size size = MediaQuery.of(context).size;
      handle = await _renderBridge.open(_document.id, _document.sourcePath);
      final int count = await _renderBridge.pageCount(handle);
      if (count <= 0) {
        _showHint('原生渲染通道未返回页数，无法保存当前页');
        return;
      }
      final int index = _pageIndex.clamp(0, count - 1).toInt();
      final RenderedPage page = await _renderBridge.render(
        handle,
        index,
        Size(size.width, size.height),
      );
      final Uint8List? bytes = page.imageBytes;
      if (bytes == null) {
        _showHint('当前页只有外部纹理、没有可导出的图片字节');
        return;
      }
      await AppServices.of(context).share.saveImage(
            bytes,
            'comic-${_document.id}-${index + 1}.png',
          );
      _showHint('已保存第 ${index + 1} 页到导出目录');
    } catch (e) {
      _showHint('保存当前页失败：$e');
    } finally {
      if (handle != null) {
        unawaited(_renderBridge.close(handle));
      }
    }
  }

  /// 固定版式分支：只负责页描述与目标尺寸，像素交给原生。
  Widget _buildNativeBody(
      BuildContext context, Size pageSize, ReaderStyle style) {
    if (_document.isComic) {
      return ComicReaderView(
        document: _document,
        style: style,
        prefetch: _prefetch,
        pageSize: pageSize,
        controller: _comicController,
        aspectRatios: DemoComicFactory.aspectRatios(_document.comicPageCount),
        onVisiblePage: _recordComicProgress,
      );
    }
    // PDF / 图片型 EPUB：真实 open() 取句柄与页数，逐页渲染 Texture / 位图。
    return FixedLayoutView(
      bridge: _renderBridge,
      document: _document,
      pageSize: pageSize,
      prefetch: _prefetch,
      onVisiblePage: _recordComicProgress,
    );
  }

  /// 排版面板关闭后清空朗读队列，让新语速 / 音调在下一次朗读时生效。
  Future<void> _openStyleSheet() async {
    await ReaderStyleSheet.open(context);
    if (!mounted) return;
    setState(() => _ttsQueue = null);
  }

  /// 目录页只回一个章节序号，由阅读器原地换章，不往页面栈里再压一个阅读器。
  Future<void> _openToc() async {
    if (_document.isComic) {
      final int? page = await ComicTocSheet.open(
        context,
        toc: _document.comicToc!,
        currentPage: _pageIndex,
      );
      if (page != null && mounted) _comicController.jumpToPage(page);
      return;
    }
    final OpenTocPage? open = widget.onOpenToc;
    // 没有外部目录页时也不能「点了只弹提示」：内置一份章节目录，
    // 选中即切章，行为与外部注入的目录页完全一致。
    final int? picked = open == null
        ? await _showInlineToc(context)
        : await open(
            AppScope.of(context).effective(widget.book), _chapterIndex);
    if (picked == null || !mounted) return;
    _switchChapter(picked);
  }

  Future<int?> _showInlineToc(BuildContext context) =>
      showModalBottomSheet<int>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext ctx) => GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: LrSpacing.m),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _document.chapters.length,
            itemBuilder: (BuildContext c, int i) => ListTile(
              title: Text(_document.chapters[i].title),
              selected: i == _chapterIndex,
              onTap: () => Navigator.of(c).pop(i),
            ),
          ),
        ),
      );

  void _switchChapter(int index, {bool resetTts = true}) {
    if (_document.isComic) {
      _comicController.jumpToPage(_document.comicToc!.pageForEpisode(index));
      return;
    }
    final int last = _document.chapters.length - 1;
    final int next = index.clamp(0, last).toInt();
    if (next == _chapterIndex) return;

    setState(() {
      _chapterIndex = next;
      _pageIndex = 0;
      _layoutResult = null; // 强制按新章节重新分页
      _selection = _selection.switchTo(chapterIndex: next, pageIndex: 0);
      if (resetTts) {
        _ttsQueue = null;
        _ttsPlaying = false;
      }
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    _recordProgress(0);
  }

  /// 朗读设置里的「打开系统 TTS 设置」：真实拉起系统页，不再只弹提示。
  Future<void> _openSystemTts() async {
    try {
      await const PlatformTtsBridge().openSystemSettings();
    } on PlatformUnavailable catch (_) {
      _showHint('当前平台未接入系统 TTS 设置跳转，请在系统设置中搜索「文字转语音」');
    }
  }

  void _onTts() {
    if (_document.isComic || _document.chapters.isEmpty) {
      _showHint(lrText('uiComicsFixedLayoutsHaveNoReflowableTextReadAlou'));
      return;
    }
    final List<ContentBlock> blocks = _document.requiresNativeRender
        ? const <ContentBlock>[]
        : _chapter.blocks;
    final List<String> sentences = SentenceQueue.splitBlocks(blocks);
    final ReaderStyle style = AppScope.of(context).settings.reader;
    final Stream<int>? sentenceDone = AppServices.of(context).sentenceDone;
    bool warned = false;

    final SentenceQueue queue = _ttsQueue ??= SentenceQueue(
      // 每句交给三端 TTS 插件朗读；原生回报 onSentenceDone 才推进 cursor，
      // 语速 / 音调直接下发，不再用 Future.delayed 假装有声音。
      onSpeak: (String sentence, int chapter, int index) async {
        try {
          await const PlatformTtsBridge().speakOne(
            sentence,
            index,
            sentenceDone: sentenceDone,
            rate: style.ttsRate,
            pitch: style.ttsPitch,
          );
        } on PlatformUnavailable catch (e) {
          // 桌面 / 单测 / 未接插件：明确提示一次，再用可见节奏推进队列，
          // 不留下「点了朗读没任何反应」。
          if (!warned) {
            warned = true;
            _showHint('$e；当前以演示节奏推进队列');
          }
          final int pace =
              (120 / style.ttsRate).round().clamp(30, 400).toInt();
          await Future<void>.delayed(Duration(milliseconds: pace));
        }
      },
      onChapterEnd: (int finished) => _onChapterFinished(finished),
    );
    if (queue.length == 0) queue.loadChapter(_chapterIndex, blocks);

    if (_ttsPlaying) {
      queue.pause();
      unawaited(const PlatformTtsBridge().pause());
      setState(() => _ttsPlaying = false);
      _showHint(lrTextArgs(
          'uiSentencesSentences', <Object?>[queue.cursor + 1, queue.length]));
      return;
    }

    setState(() {
      _sentenceCount = sentences.length;
      _ttsPlaying = true;
    });
    unawaited(const PlatformTtsBridge().setRate(style.ttsRate));
    unawaited(const PlatformTtsBridge().setPitch(style.ttsPitch));
    unawaited(queue.resume());
    _showHint(lrTextArgs('uiSentences', <Object?>[
      _chapter.title,
      queue.cursor + 1,
      _sentenceCount,
      style.ttsRate.toStringAsFixed(2)
    ]));
  }

  /// 读完自动进入下一章。用 microtask 等旧队列的 play() 走完 finally，
  /// 否则 resume() 会因 _playing 仍为 true 被吞掉，停在下一章开头。
  void _onChapterFinished(int finished) {
    if (!mounted) return;
    if (finished + 1 >= _document.chapters.length) {
      setState(() => _ttsPlaying = false);
      _showHint(lrText('uiFinishedTheWholeBook'));
      return;
    }
    _switchChapter(finished + 1, resetTts: false);
    Future<void>.microtask(() {
      if (!mounted) return;
      final SentenceQueue? q = _ttsQueue;
      if (q == null) return;
      q.loadChapter(_chapterIndex, _chapter.blocks);
      setState(() => _ttsPlaying = true);
      unawaited(q.resume());
    });
  }

  void _showHint(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 小说页内插图：字节由三端文件通道提供，避免引入 dart:io 的三端差异。
/// Future 只创建一次，滚动重建不会反复读同一张图。
class _ImageLine extends StatefulWidget {
  const _ImageLine({required this.path, required this.height});

  final String path;
  final double height;

  @override
  State<_ImageLine> createState() => _ImageLineState();
}

class _ImageLineState extends State<_ImageLine> {
  late final Future<Uint8List> _bytes =
      AppServices.files.readBytes(widget.path);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snap) {
        if (snap.hasData) {
          return SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Image.memory(
              snap.data!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          );
        }
        return SizedBox(
          height: widget.height,
          child: GlassPanel(
            child: Center(
              child: Text(
                snap.hasError ? '插图读取失败：${widget.path}' : '正在读取插图…',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
