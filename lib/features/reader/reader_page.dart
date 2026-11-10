import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/book_repository.dart';
import '../../core/data/demo_document.dart';
import '../../core/layout/page_layout.dart';
import '../../core/models/book_document.dart';
import '../../core/platform/render_bridge.dart';
import '../../core/platform/tts_queue.dart';
import '../../core/router/route_args.dart';
import '../../core/state/app_scope.dart';
import '../../core/state/reader_style.dart';
import '../../core/stats/excerpt_capture.dart';
import '../../core/stats/line_anchor_resolver.dart';
import '../../core/stats/reading_stats.dart';
import '../../core/storage/progress_sampler.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/glass.dart';
import 'comic_prefetch.dart';
import 'comic_toc_sheet.dart';
import 'vertical_comic_view.dart';
import 'excerpt_capture_sheet.dart';
import 'native_page_view.dart';
import 'page_turn_view.dart';
import 'reader_style_sheet.dart';
import '../../core/content/lr_localizations.dart';

/// 阅读器：可重排文本走纯 Dart 分页自绘；固定版式走 BookRenderBridge 原生页。
/// 分界线判据是「内容能不能重排」，不是文件格式。
///
/// 章节切换不新增页面栈：目录页 pop 出章节序号后在这里换章并重排，
/// 与详情页「从目录新建阅读器」走的是同一份 BookDocument。
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
  final BookRenderBridge _renderBridge = UnimplementedRenderBridge(lrText('uiDemoPlatform'));
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

  /// 当前页的按行选区。翻页 / 换章时重建，避免锚点串页。
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
    _sampler = ProgressSampler(store: InMemoryProgressStore());
    _prefetch = ComicPrefetchWindow(bridge: _renderBridge);
  }

  @override
  void dispose() {
    // 退出前兜底写一次，对应原项目要求。
    unawaited(_sampler.flush());
    unawaited(_prefetch.release());
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _comicController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
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

    return Scaffold(
      // 阅读背景独立于 Material 明暗主题：夜间档在系统浅色模式下依然是深色底。
      backgroundColor: style.backgroundColor,
      appBar: AppBar(
        backgroundColor: style.backgroundColor,
        foregroundColor: style.textColor,
        elevation: 0,
        leading: const BackButton(),
        title: Text(book.title),
        actions: <Widget>[
          IconButton(
            tooltip: state.isFavorite(book.id) ? context.t('uiRemoveFavorite') : context.t('uiFavoriteThisBook'),
            onPressed: () {
              final bool added = state.toggleFavorite(book.id);
              _showHint(added ? context.t('uiAddedToFavorites') : context.t('uiRemovedFromFavorites'));
            },
            icon: Icon(state.isFavorite(book.id) ? Icons.star : Icons.star_border),
          ),
          IconButton(
            tooltip: context.t('uiCaptureSelectedLines'),
            onPressed: _openExcerptCapture,
            icon: Icon(
              _selection.isNotEmpty ? Icons.bookmark_add : Icons.bookmark_add_outlined,
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
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size pageSize = Size(
            constraints.maxWidth - LrSpacing.l * 2,
            constraints.maxHeight - 180,
          );
          if (_document.requiresNativeRender) {
            return _buildNativeBody(context, pageSize, style);
          }
          final PaginationResult result = _ensureLayout(context, pageSize, style);
          return _buildTextBody(context, result, style);
        },
      ),
    );
  }

  /// 缓存键必须包含章节序号与排版字段：换章复用上一章页码会错位，
  /// 改字号/行高却复用旧分页结果会让「设置不生效」。
  /// 背景、翻页动效、语速不在 layoutKey 里，改它们只换外观、不重排。
  PaginationResult _ensureLayout(BuildContext context, Size pageSize, ReaderStyle style) {
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

  Widget _buildTextBody(BuildContext context, PaginationResult result, ReaderStyle style) {
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
            key: ValueKey<String>('$_chapterIndex|$_pageIndex|${_selection.signature()}'),
            controller: _pageController,
            itemCount: result.pages.length,
            onPageChanged: (int i) {
              setState(() {
                _pageIndex = i;
                // 一行锚点只在当前页有效，翻页必须丢弃选区。
                _selection = _selection.switchTo(chapterIndex: _chapterIndex, pageIndex: i);
              });
              _recordProgress(i);
            },
            itemBuilder: (BuildContext context, int i) =>
                _buildTextPage(context, result, i, anchors),
            turn: style.pageTurn,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: LrSpacing.m, vertical: LrSpacing.s),
            child: Row(
              children: <Widget>[
                IconButton(
                  color: style.textColor,
                  tooltip: context.t('uiPreviousChapter'),
                  onPressed: _chapterIndex > 0 ? () => _switchChapter(_chapterIndex - 1) : null,
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
                        style: text.labelLarge?.copyWith(color: style.textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tArgs('uiChapter', <Object?>[_pageIndex + 1, result.pages.length, _chapterIndex + 1, _document.chapters.length]),
                        style: text.labelSmall?.copyWith(color: style.subtleTextColor),
                      ),
                      if (_selection.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            context.tArgs('uiLinesSaveexcerpts', <Object?>[_selection.count]),
                            style: text.labelSmall?.copyWith(color: HighlightPalette.spine(HighlightColor.amber)),
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
      padding: const EdgeInsets.symmetric(horizontal: LrSpacing.l, vertical: LrSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ...page.lines.map<Widget>((LaidOutLine line) {
            if (line.isImage) {
              // TODO(静态冻结): 插图走原生解码或已导入资源，占位高度由 PageInfo 决定
              return SizedBox(
                height: line.height,
                child: GlassPanel(child: Center(child: Text(lrText('uiIllustrationPlaceholder')))),
              );
            }

            final LineRef ref = LineRef(
              bookId: _document.id,
              chapterIndex: _chapterIndex,
              pageIndex: index,
              blockIndex: line.blockIndex,
              lineInBlock: line.lineInBlock,
              text: line.text,
            );
            final bool selected = _selection.lines.any((SelectedLine l) => l.ref == ref);

            // 已保存的摘录：位置精确 / 位置一致文字已变 / 重排后按文本唯一还原
            // 三级置信度由模型裁决；多处相同文本返回 ambiguous，不自动高亮。
            final LineAnchorMatch? match = anchors.resolve(ref);
            final HighlightColor? savedColor =
                (match != null && match.shouldHighlight) ? match.highlight : null;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selection = _selection.toggle(ref)),
              child: Container(
                height: config.linePx,
                decoration: BoxDecoration(
                  color: selected
                      ? HighlightPalette.lineTint(HighlightColor.amber)
                      : (savedColor == null ? null : HighlightPalette.lineTint(savedColor)),
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
      // 漫画页没有可重排文本行，按行点选不适用；
      // 区域 / 字符级摘录 ❄️ 冻结，不弹一个空面板。
      _showHint(lrText('uiPagesLinesexcerptsEpisodeListContents'));
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

  /// 固定版式分支：只负责页描述与目标尺寸，像素交给原生。
  Widget _buildNativeBody(BuildContext context, Size pageSize, ReaderStyle style) {
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
    // PDF / 图片型 EPUB：由 ParserRouter 打开文档取得 handle 与 pageCount（❄️ 冻结）。
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.t('uiFixedLayoutPage'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: style.textColor),
          ),
          const SizedBox(height: LrSpacing.m),
          Text(
            context.t('uiPdfEpubViaBookrenderbridge') +
            context.t('uiRenderHandleIndexTargetsizePages4k') +
            context.t('uiPagesTextureidTextureTextureid') +
            context.t('uiPagesImageMemory') +
            context.t('uiComicprefetchwindowPrefetchEvictSpreadsChannel'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: style.textColor),
          ),
          const SizedBox(height: LrSpacing.m),
          Text(context.tArgs('uiSize', <Object?>[pageSize.width.round(), pageSize.height.round()]),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: style.subtleTextColor)),
          const SizedBox(height: LrSpacing.m),
          // 未接三端原生实现时显式提示，不返回空白页。
          SizedBox(
            height: 120,
            child: NativePageView(
              bridge: _renderBridge,
              handle: 0,
              pageIndex: 0,
              targetSize: Size(pageSize.width, 120),
            ),
          ),
        ],
      ),
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
    if (open == null) {
      _showHint(lrText('uiTocNavigationIsNotWiredIntoThisPage'));
      return;
    }
    final BookSummary book = AppScope.of(context).effective(widget.book);
    final int? picked = await open(book, _chapterIndex);
    if (picked == null || !mounted) return;
    _switchChapter(picked);
  }

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

  void _onTts() {
    if (_document.isComic || _document.chapters.isEmpty) {
      _showHint(lrText('uiComicsFixedLayoutsHaveNoReflowableTextReadAlou'));
      return;
    }
    final List<ContentBlock> blocks = _document.requiresNativeRender
        ? const <ContentBlock>[]
        : _chapter.blocks;
    final List<String> sentences = SentenceQueue.splitBlocks(blocks);
    // 静态演示里用语速反比调节每句间隔，让设置项可见地生效；
    // 接 TtsController 后改为 setRate / setPitch 三端下发。
    final double rate = AppScope.of(context).settings.reader.ttsRate;
    final int pace = (120 / rate).round().clamp(30, 400).toInt();

    final SentenceQueue queue = _ttsQueue ??= SentenceQueue(
      // TODO(静态冻结): 换成 TtsBridge.enqueueSentences / pause / resumeAtSentence。
      onSpeak: (String sentence, int chapter, int index) async {
        await Future<void>.delayed(Duration(milliseconds: pace));
      },
      onChapterEnd: (int finished) => _onChapterFinished(finished),
    );
    if (queue.length == 0) queue.loadChapter(_chapterIndex, blocks);

    if (_ttsPlaying) {
      queue.pause();
      setState(() => _ttsPlaying = false);
      _showHint(lrTextArgs('uiSentencesSentences', <Object?>[queue.cursor + 1, queue.length]));
      return;
    }

    setState(() {
      _sentenceCount = sentences.length;
      _ttsPlaying = true;
    });
    unawaited(queue.resume());
    _showHint(lrTextArgs('uiSentences', <Object?>[_chapter.title, queue.cursor + 1, _sentenceCount, rate.toStringAsFixed(2)]));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
