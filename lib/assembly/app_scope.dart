import 'dart:async';
import 'dart:ui' show Locale;

import 'package:Local_reader/l10n/localized_texts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/model/webdav_backup.dart';
import '../core/model/book_identity.dart';
import '../core/model/navigation_spec.dart' show BookKind;
import '../domain/repositories/book_repository.dart';
import '../domain/usecases/library_query.dart';
import '../domain/usecases/cloud_book_projection.dart';
import '../core/model/shelf_prefs.dart';
import '../domain/usecases/favorite_routes.dart';
import '../domain/usecases/import_session.dart';
import '../core/model/profile_summary.dart';
import '../core/model/bilingual_prefs.dart';
import '../core/model/stats/excerpt_capture.dart';
import '../core/model/stats/keepsakes.dart';
import '../core/model/stats/reading_stats.dart';
import '../core/model/stats/stats_views.dart';
import '../core/ui/theme/color_source.dart';
import '../core/common/design_tokens.dart';
import '../data/wenku/demo_wenku8_source.dart';
import '../data/wenku/http_wenku8_source.dart';
import '../core/model/wenku/wenku8_compliance.dart';
import '../core/model/wenku/wenku8_models.dart';
import '../core/model/wenku/wenku8_session.dart';
import '../domain/repositories/wenku8_source.dart';
import '../core/model/app_settings.dart';
import '../core/model/book_overrides.dart';
import '../core/model/font_catalog.dart';
import '../core/model/per_book_style.dart';
import '../core/model/reader_motion.dart';
import '../core/model/reader_style.dart';

/// 全应用共享状态。用 ChangeNotifier + InheritedNotifier 做最小依赖注入，
/// 不引入第三方状态管理包，静态交付阶段保持依赖为零。
class AppState extends ChangeNotifier {
  AppState({
    required this.settingsStore,
    required this.books,
    StatsRepository? statsRepo,
    Wenku8Source? wenku8Source,
    SeasonStyle initialSeason = SeasonStyle.paper,
  })  : stats = statsRepo ?? DemoStatsRepository(),
        wenku8 = wenku8Source ?? const DemoWenku8Source(),
        _settings = const AppSettings().normalized(),
        season = ValueNotifier<SeasonStyle>(initialSeason) {
    season.addListener(notifyListeners);
  }

  final SettingsStore settingsStore;
  final BookRepository books;

  /// 统计数据源：与 BookRepository 一样可替换，静态阶段用固定基准日的演示实现。
  final StatsRepository stats;

  /// Wenku8 在线目录数据源：**唯一可注入点**（第二十二轮）。
  /// 静态阶段是 `DemoWenku8Source`（确定性演示元数据、零请求）；接 SDK 后按同一
  /// `Wenku8Source` 契约换成真实实现，页面 / 合规层 / 状态机都不用改。
  final Wenku8Source wenku8;

  /// 应用内小组件配置。可同时放置多个，每个独立配置内容 / 尺寸 / 季节 / 进度。
  /// 桌面小组件本体需三端原生读取这里序列化后的数据（❄️ 冻结）。
  final List<WidgetSpec> _widgetSpecs = <WidgetSpec>[
    const WidgetSpec(id: 'w-today', content: WidgetContent.today, size: WidgetSize.small),
    const WidgetSpec(id: 'w-excerpt', content: WidgetContent.excerpt, size: WidgetSize.medium, season: SeasonStyle.sakura),
  ];

  List<WidgetSpec> get widgetSpecs => List<WidgetSpec>.unmodifiable(_widgetSpecs);

  void updateWidgetSpec(WidgetSpec next) {
    final int i = _widgetSpecs.indexWhere((WidgetSpec s) => s.id == next.id);
    if (i < 0 || _widgetSpecs[i] == next) return;
    _widgetSpecs[i] = next;
    notifyListeners();
  }

  WidgetSpec addWidgetSpec() {
    int n = _widgetSpecs.length + 1;
    String id = 'w-$n';
    while (_widgetSpecs.any((WidgetSpec s) => s.id == id)) {
      n++;
      id = 'w-$n';
    }
    final WidgetSpec spec = WidgetSpec(id: id);
    _widgetSpecs.add(spec);
    notifyListeners();
    return spec;
  }

  void removeWidgetSpec(String id) {
    if (!_widgetSpecs.any((WidgetSpec s) => s.id == id)) return;
    _widgetSpecs.removeWhere((WidgetSpec s) => s.id == id);
    notifyListeners();
  }

  void resetWidgetSpecs() {
    _widgetSpecs
      ..clear()
      ..addAll(<WidgetSpec>[
        const WidgetSpec(id: 'w-today', content: WidgetContent.today, size: WidgetSize.small),
        const WidgetSpec(id: 'w-excerpt', content: WidgetContent.excerpt, size: WidgetSize.medium, season: SeasonStyle.sakura),
      ]);
    notifyListeners();
  }

  // ---------------------------------------------------------------- 导入结果

  /// 导入向导写入的书籍。演示仓储 `_sample` 是只读 const，
  /// 所以新书只追加到这一层内存列表，不修改演示数据。
  final List<BookSummary> _importedBooks = <BookSummary>[];

  /// 最近观看：打开详情 / 阅读器时写入，书架与搜索的默认排序按它倒序。
  /// 是「显示时优先将最近观看放前面」的唯一数据源，页面不自己维护影子列表。
  final Map<String, DateTime> _lastReadAt = <String, DateTime>{};

  /// 从书架移出的演示书（演示仓储只读，用移除集合表达，不假装有数据库删除）。
  final Set<String> _removedIds = <String>{};

  /// 进度重置等写操作落在覆盖层，演示仓储保持 const 不可变。
  final Map<String, double> _progressOverrides = <String, double>{};

  /// 云端书籍评论：详情页「评论」入口的真实写入目标。
  final Map<String, List<String>> _comments = <String, List<String>>{};

  List<BookSummary> get importedBooks => List<BookSummary>.unmodifiable(_importedBooks);
  int get importedCount => _importedBooks.length;

  // ---------------------------------------------------------------- Wenku8 在线目录

  Wenku8Status _wenku8Status = Wenku8Status.lockedByPureLocal;
  Wenku8Query _wenku8Query = const Wenku8Query();
  Wenku8Listing? _wenku8Listing;
  final Set<String> _wenku8AddedIds = <String>{};

  /// 表单登录会话（第二十五轮）：由 `Wenku8Bootstrap` 装配进真实数据源，
  /// 演示源为 null。页面只读这个 getter，不自己持有会话对象。
  Wenku8Session? get wenku8Session {
    final Wenku8Source s = wenku8;
    return s is HttpWenku8Source ? s.session : null;
  }

  /// 个人书架：需要登录；锁定态提前返回 null，零请求。
  Future<Wenku8Listing?> wenku8Bookcase() async {
    if (!_settings.onlineEnabled) return null;
    final Wenku8Source s = wenku8;
    return s is HttpWenku8Source ? s.bookcase() : null;
  }

  Wenku8Status get wenku8Status => _wenku8Status;
  Wenku8Query get wenku8Query => _wenku8Query;
  Wenku8Listing? get wenku8Listing => _wenku8Listing;
  bool get wenku8Locked => !_settings.onlineEnabled;
  bool isWenku8BookAdded(String bookId) => _wenku8AddedIds.contains(bookId);

  /// 一键解锁在线目录（由云端书架 / 文库页显式调用，不偷偷改默认值）。
  void enableOnlineDirectory() {
    if (_settings.onlineEnabled) return;
    // 开关变化会由 updateSettings 统一触发一次刷新，这里不重复调用。
    updateSettings(_settings.copyWith(
      pureLocal: false,
      onlineDirectory: true,
    ));
  }

  /// 唯一刷新出口。锁定态直接返回 `lockedByPureLocal`，不触碰数据源。
  Future<void> refreshWenku8() async {
    if (!_settings.onlineEnabled) {
      _wenku8Status = Wenku8Status.lockedByPureLocal;
      _wenku8Listing = null;
      notifyListeners();
      return;
    }
    _wenku8Status = Wenku8Status.loading;
    notifyListeners();
    final Wenku8Query q = _wenku8Query.normalized();
    final Wenku8Listing listing = await wenku8.listing(q);
    // 合规层是所有列表出口的必经之路：下架内容一律不展示。
    _wenku8Listing = Wenku8Listing(
      feed: listing.feed,
      books: Wenku8Compliance.withoutWithdrawn(listing.books),
      status: listing.status,
      note: listing.note,
    );
    _wenku8Status = listing.status;
    _wenku8Query = q;
    notifyListeners();
  }

  void setWenku8Feed(Wenku8FeedKind feed) {
    _wenku8Query = Wenku8Query(feed: feed, keyword: '').normalized();
    unawaited(refreshWenku8());
  }

  void setWenku8Keyword(String keyword) {
    _wenku8Query = Wenku8Query(keyword: keyword).normalized();
    unawaited(refreshWenku8());
  }

  Future<Wenku8Detail?> wenku8Detail(String bookId) async {
    if (!_settings.onlineEnabled) return null;
    return wenku8.detail(bookId);
  }

  /// 单章正文是**可选能力**：只有真实数据源实现 `Wenku8ChapterSource`，
  /// 演示源不提供。锁定态提前返回 null，不产生请求。
  Future<Wenku8ChapterText?> wenku8ChapterText(
      String bookId, String chapterId) async {
    if (!_settings.onlineEnabled) return null;
    final Wenku8Source s = wenku8;
    if (s is! Wenku8ChapterSource) return null;
    return (s as Wenku8ChapterSource).chapter(bookId, chapterId);
  }

  /// 把在线书**加入本地书库**：只登记元数据壳，不下载、不缓存小说正文。
  /// 与导入向导共用 `_importedBooks` 出口，所以书架 / 搜索 / 统计 / 收藏
  /// 立刻同步可见（第十二轮口径）。
  bool addWenku8BookToLibrary(Wenku8Book book) {
    if (!book.isAvailable) return false;
    if (_wenku8AddedIds.contains(book.id)) return false;
    if (!Wenku8Compliance.isSupportedSource(Wenku8Compliance.wenku8SourceId)) {
      return false;
    }
    final String id = 'cloud-${book.id}';
    if (_importedBooks.any((BookSummary b) => b.id == id)) return false;
    _importedBooks.add(BookSummary(
      id: id,
      title: book.title,
      author: book.author,
      spineColor: book.coverColor,
      shelf: DemoBookRepository.shelfTitles.first,
      format: 'EPUB',
      encoding: 'UTF-8',
      volumeOrder: 0,
    ));
    _wenku8AddedIds.add(book.id);
    notifyListeners();
    return true;
  }

  static const List<Color> _importPalette = <Color>[
    Color(0xFF4A6180), Color(0xFFB4677C), Color(0xFF3F8079),
    Color(0xFFA96433), Color(0xFF6B7A94), Color(0xFF8A6A4F),
  ];

  /// 书库唯一出口：演示书籍 + 导入书籍，都先套用元数据覆盖层。
  /// 书架 / 搜索 / 统计 / 冲突比对必须走这里，避免「导入完书架还是 11 册」。
  List<BookSummary> _allBooks() => <BookSummary>[
        for (final BookSummary b in books.cached)
          if (!_removedIds.contains(b.id)) effective(b),
        for (final BookSummary b in _importedBooks)
          if (!_removedIds.contains(b.id)) effective(b),
      ];

  /// 对外统一顺序：最近观看优先，没看过的回退卷序。
  List<BookSummary> get allBooks => LibraryQuery.apply(
        books: _allBooks(),
        sort: LibrarySort.recent,
        lastReadAt: _lastReadAt,
      );

  /// 按 id 找书：演示仓储 + 导入书籍。收藏列表用它，导入的书也能跳转。
  BookSummary? resolveBook(String id) {
    if (_removedIds.contains(id)) return null;
    final BookSummary? demo = books.byId(id);
    if (demo != null) return effective(demo);
    for (final BookSummary b in _importedBooks) {
      if (b.id == id) return effective(b);
    }
    // 云端详情可能由展示编号 WK-xxx 打开，补一次内部 id 反查。
    if (BookIdentity.isCloudId(id)) {
      final String raw = BookIdentity.rawId(id);
      for (final BookSummary b in _importedBooks) {
        if (BookIdentity.rawId(b.id) == raw) return effective(b);
      }
    }
    return null;
  }

  /// 导入向导的唯一写入口。返回实际新增册数；重复 id 幂等跳过。
  /// `deferred`（替换 / 合并记录）需要真实数据库能力，静态阶段只记在摘要里。
  int applyImport(ImportCommit commit) {
    final List<BookSummary> added = <BookSummary>[];
    for (final ImportBookDraft d in commit.added) {
      if (books.byId(d.id) != null ||
          _importedBooks.any((BookSummary b) => b.id == d.id)) {
        continue;
      }
      added.add(BookSummary(
        id: d.id,
        title: d.title,
        author: d.author,
        spineColor: _importPalette[d.id.hashCode.abs() % _importPalette.length],
        shelf: d.shelf,
        format: d.format,
      ));
    }
    if (added.isEmpty) return 0;
    _importedBooks.addAll(added);
    notifyListeners();
    return added.length;
  }

  // ---------------------------------------------------------------- 收藏

  /// 收藏条目：静态交付模式下只存内存，重启恢复演示收藏。
  /// `bookId` 是唯一身份（同书重复收藏不产生两条），target 决定点它跳去哪。
  final List<FavoriteEntry> _favorites = <FavoriteEntry>[
    FavoriteEntry(
      bookId: 'b01',
      target: FavoriteTarget.detail,
      addedAt: DateTime.utc(2026, 11, 8),
    ),
    FavoriteEntry(
      bookId: 'b04',
      target: FavoriteTarget.reader,
      addedAt: DateTime.utc(2026, 11, 5),
    ),
  ];

  Set<String> get favoriteIds =>
      _favorites.map<String>((FavoriteEntry e) => e.bookId).toSet();

  int get favoriteCount => _favorites.length;

  /// 最近添加的在前；对外不可变，页面不许顺手改全局收藏。
  List<FavoriteEntry> get favorites {
    final List<FavoriteEntry> out = List<FavoriteEntry>.of(_favorites);
    out.sort((FavoriteEntry a, FavoriteEntry b) => b.addedAt.compareTo(a.addedAt));
    return List<FavoriteEntry>.unmodifiable(out);
  }

  bool isFavorite(String bookId) => favoriteIds.contains(bookId);

  FavoriteTarget? targetFor(String bookId) {
    for (final FavoriteEntry e in _favorites) {
      if (e.bookId == bookId) return e.target;
    }
    return null;
  }

  /// 已收藏则取消；未收藏则按 target 加入。返回操作后的状态，便于页面提示。
  bool toggleFavorite(String bookId, {FavoriteTarget target = FavoriteTarget.detail}) {
    final int i = _favorites.indexWhere((FavoriteEntry e) => e.bookId == bookId);
    if (i >= 0) {
      _favorites.removeAt(i);
      notifyListeners();
      return false;
    }
    _favorites.add(FavoriteEntry(bookId: bookId, target: target, addedAt: DateTime.now()));
    notifyListeners();
    return true;
  }

  bool addFavorite(String bookId, {FavoriteTarget target = FavoriteTarget.detail}) {
    if (isFavorite(bookId)) return false;
    _favorites.add(FavoriteEntry(bookId: bookId, target: target, addedAt: DateTime.now()));
    notifyListeners();
    return true;
  }

  bool removeFavorite(String bookId) {
    final int before = _favorites.length;
    _favorites.removeWhere((FavoriteEntry e) => e.bookId == bookId);
    if (_favorites.length == before) return false;
    notifyListeners();
    return true;
  }

  void setFavoriteTarget(String bookId, FavoriteTarget target) {
    final int i = _favorites.indexWhere((FavoriteEntry e) => e.bookId == bookId);
    if (i < 0 || _favorites[i].target == target) return;
    _favorites[i] = _favorites[i].copyWith(target: target);
    notifyListeners();
  }

  // ---------------------------------------------------------------- 摘录采集

  /// 用户从阅读器采集的摘录。静态交付模式下只存内存，重启恢复演示数据；
  /// `Excerpt` 已带全部锚点与元数据字段，接数据库时在这里落库即可，页面零改动。
  final List<Excerpt> _userExcerpts = <Excerpt>[];
  int _excerptSeq = 0;

  /// 演示摘录只在首次访问时取一次，不随统计快照每次重建。
  late final List<Excerpt> _seedExcerpts = stats.snapshot().excerpts;

  /// 统计页 / 小组件配置读的**唯一摘录出口**：用户摘录在前（新→旧），演示在后。
  /// 这样阅读器保存后统计页同一次 build 就能看到，不需要重启页面。
  List<Excerpt> get excerpts => List<Excerpt>.unmodifiable(<Excerpt>[
        ..._userExcerpts.reversed,
        ..._seedExcerpts,
      ]);

  List<Excerpt> get userExcerpts => List<Excerpt>.unmodifiable(_userExcerpts);

  // ---------------------------------------------------------------- 纪念物

  /// 纪念物**每次读取都重算**：阅读器新增摘录、季节换肤、统计快照变化都能即时反映。
  /// 绝不缓存成字段——第九轮在统计页踩过「缓存旧摘录列表，新数据要重启才出现」的坑。
  /// 生成规则全在 KeepsakeCatalog，页面不手写演示纪念物。
  List<Keepsake> get keepsakes => KeepsakeCatalog.build(
        snapshot: stats.snapshot(),
        excerpts: excerpts,
        season: season.value,
      );

  int get keepsakeCount => keepsakes.length;

  /// 纪念物按月份归档，供统计页与月度日历页共用同一份分组口径。
  Map<String, List<Keepsake>> get keepsakesByMonth =>
      KeepsakeCatalog.byMonth(keepsakes);

  /// 给阅读器渲染当前章节的已有划线：只取带锚点的用户摘录 + 同书演示摘录。
  List<Excerpt> highlightsFor({required String bookId, required int chapterIndex}) =>
      List<Excerpt>.unmodifiable(
        excerpts.where(
          (Excerpt e) => e.origin != null && e.bookId == bookId && e.chapterIndex == chapterIndex,
        ),
      );

  /// 写入一条摘录。同一本书同章、归一化后相同的句子只存一次（signature 去重），
  /// 重复时返回 null 让阅读器提示「这段已经摘过了」，不制造两条一样的卡片。
  Excerpt? addExcerpt(
    ExcerptDraft draft, {
    required String bookTitle,
    required String chapterTitle,
    DateTime? capturedAt,
  }) {
    if (draft.text.trim().isEmpty) return null;
    final bool duplicated = _userExcerpts.any((Excerpt e) => e.signature == draft.signature);
    if (duplicated) return null;

    _excerptSeq++;
    final Excerpt excerpt = Excerpt(
      id: 'u-$_excerptSeq',
      bookId: draft.bookId,
      bookTitle: bookTitle,
      chapterTitle: chapterTitle,
      text: draft.text,
      capturedAt: capturedAt ?? DateTime.now(),
      chapterIndex: draft.chapterIndex,
      pageIndex: draft.pageIndex,
      highlight: draft.highlight,
      note: draft.note,
      isUserAdded: true,
      origin: draft.origin,
      crossParagraph: draft.crossParagraph,
      signature: draft.signature,
    );
    _userExcerpts.add(excerpt);
    notifyListeners();
    return excerpt;
  }

  /// 编辑批注 / 划线色。**只允许改用户自己采集的条目**，演示种子只读；
  /// signature 与正文保持不变，所以改批注不会让去重口径失效。
  /// `note` 传空字符串表示清空批注；传 null 表示「这一项不改」。
  bool updateExcerpt(
    String id, {
    String? note,
    HighlightColor? highlight,
  }) {
    final int i = _userExcerpts.indexWhere(
      (Excerpt e) => e.isUserAdded && e.id == id,
    );
    if (i < 0) return false;
    final Excerpt next = _userExcerpts[i].copyWith(note: note, highlight: highlight);
    if (next == _userExcerpts[i]) return false;
    _userExcerpts[i] = next;
    notifyListeners();
    return true;
  }

  /// 只允许删除用户自己采集的摘录；演示数据是只读种子。
  bool removeExcerpt(String id) {
    final int before = _userExcerpts.length;
    _userExcerpts.removeWhere((Excerpt e) => e.isUserAdded && e.id == id);
    if (_userExcerpts.length == before) return false;
    notifyListeners();
    return true;
  }

  bool hasSignature(String signature) =>
      _userExcerpts.any((Excerpt e) => e.signature == signature);

  AppSettings _settings;
  AppSettings get settings => _settings;

  /// 第二十六轮：MaterialApp.locale 的唯一来源。null = 跟随系统，
  /// 由官方 supportedLocales 解析；非 null = 用户显式指定。
  Locale? get appLocale => _settings.appLanguage?.locale;

  void setAppLanguage(AppLanguage? value) => updateSettings(
        _settings.copyWith(
          appLanguage: value,
          clearAppLanguage: value == null,
        ),
      );

  /// 元数据编辑覆盖层：只读演示仓储 + 可写覆盖，避免「编辑一本书改到全库」。
  /// 静态交付模式下仅存内存；未来接数据库时在这里落库即可，页面零改动。
  final Map<String, BookOverride> _overrides = <String, BookOverride>{};

  /// 页面统一用这个方法取展示数据，保证书架 / 详情 / 目录 / 阅读器看到同一份编辑结果。
  BookSummary effective(BookSummary book) {
    final BookOverride? o = _overrides[book.id];
    final double? progress = _progressOverrides[book.id];
    if (o == null && progress == null) return book;
    return book.copyWith(
      title: o?.title,
      author: o?.author,
      spineColor: o?.spineColor,
      volumeOrder: o?.volumeOrder,
      progress: progress,
    );
  }

  BookOverride? overrideFor(String bookId) => _overrides[bookId];

  /// 书库查询的唯一出口：先套用元数据覆盖层，再做搜索与排序。
  /// 所以在详情页把某本书改成「第 3 卷」后，书架与搜索结果会立刻按新卷序重排，
  /// 四 tab 不需要各自维护一份排序逻辑。
  List<BookSummary> library({
    String query = '',
    String? shelf,
    LibrarySort sort = LibrarySort.recent,
    bool favoritesOnly = false,
  }) =>
      LibraryQuery.apply(
        books: _allBooks(),
        query: query,
        shelf: shelf,
        sort: sort,
        favoritesOnly: favoritesOnly,
        favoriteIds: favoriteIds,
        lastReadAt: _lastReadAt,
      );

  // ---------------------------------------------------------------- 最近观看 / 书籍操作

  /// 打开详情 / 阅读器时调用：下一次 build 书架就把它排到最前。
  /// 同一次会话里重复打开同一本只刷新时间，不产生额外条目。
  void markAsRead(String bookId) {
    if (bookId.isEmpty || _removedIds.contains(bookId)) return;
    _lastReadAt[bookId] = DateTime.now();
    notifyListeners();
  }

  DateTime? lastReadAt(String bookId) => _lastReadAt[bookId];

  /// 详情页「移出书架」：导入 / 云端书直接删，演示书登记移除集合。
  /// 同步清掉收藏与最近观看，避免卡片消失后收藏页还留着幽灵入口。
  bool removeBook(String bookId) {
    bool changed = false;
    final int before = _importedBooks.length;
    _importedBooks.removeWhere((BookSummary b) => b.id == bookId);
    changed = _importedBooks.length != before;
    if (!changed) changed = _removedIds.add(bookId);
    if (!changed) return false;
    _favorites.removeWhere((FavoriteEntry e) => e.bookId == bookId);
    _lastReadAt.remove(bookId);
    _progressOverrides.remove(bookId);
    _comments.remove(bookId);
    notifyListeners();
    return true;
  }

  /// 详情页「重置进度」：写覆盖层，不修改 const 演示数据。
  void resetProgress(String bookId) {
    if (bookId.isEmpty) return;
    _progressOverrides[bookId] = 0;
    notifyListeners();
  }

  /// 详情页「加入书架 / 缓存到本地」：云端书复用既有合规校验，
  /// 只登记元数据壳，不下载正文；本地书则切换收藏。
  bool addCloudBookToLibrary(BookSummary book) {
    if (!BookIdentity.isCloudId(book.id)) return toggleFavorite(book.id);
    return addWenku8BookToLibrary(cloudBookOf(book));
  }

  List<String> commentsFor(String bookId) =>
      List<String>.unmodifiable(_comments[bookId] ?? const <String>[]);

  bool addComment(String bookId, String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    _comments.putIfAbsent(bookId, () => <String>[]).add(trimmed);
    notifyListeners();
    return true;
  }

  Map<String, int> shelfCounts() => LibraryQuery.shelfCounts(_allBooks());

  LibraryEmptyKind emptyKind({
    required int matched,
    required String query,
    bool favoritesOnly = false,
  }) =>
      LibraryQuery.emptyKind(
        total: _allBooks().length,
        matched: matched,
        query: query,
        favoritesOnly: favoritesOnly,
        favoriteCount: favoriteCount,
      );

  void updateBook(
    String bookId, {
    String? title,
    String? author,
    Color? spineColor,
    int? volumeOrder,
  }) {
    final BookOverride next = BookOverride(
      title: title,
      author: author,
      spineColor: spineColor,
      volumeOrder: volumeOrder,
    );
    final BookOverride? previous = _overrides[bookId];
    final BookOverride merged = previous == null ? next : previous.merge(next);
    // 同值不刷新整棵 widget 树：编辑面板可能连续提交相同的书名 / 卷序。
    if (merged == previous) return;
    _overrides[bookId] = merged;
    notifyListeners();
  }

  /// 季节主题提升到全局：MaterialApp 的 theme 随它重建，
  /// 四个 tab 都通过 Theme.extension<LrSeasonTheme>() 拿到同一套色板。
  final ValueNotifier<SeasonStyle> season;

  // ---- 第二十四轮：README 功能对齐收口，全部挂在全局单一状态源 ----
  // 纪律同前几轮：页面不持有这些对象的影子副本，只从这里读写；
  // 「归一化」仍在各自的模型里，AppState 只负责转发与通知。
  final Map<String, PerBookStyle> _perBookStyles = <String, PerBookStyle>{};
  FontCatalog _fontCatalog = FontCatalog.initial;
  ColorSource _colorSource = const ColorSource();
  ReaderMotion _readerMotion = const ReaderMotion();
  ShelfPrefs _shelfPrefs = const ShelfPrefs();
  BackupSnapshot _backup = const BackupSnapshot();
  BilingualPrefs _bilingual = const BilingualPrefs();
  StatsViewKind _statsView = StatsViewKind.overview;
  /// 收藏页「小说 / 漫画」切换是真实状态，不再点完没反应。
  BookKind _favoritesKind = BookKind.novel;
  StatsPeriod _statsPeriod = const StatsPeriod();
  ReportLayout _reportLayout = ReportLayout.classic;

  Map<String, PerBookStyle> get perBookStyles =>
      Map<String, PerBookStyle>.unmodifiable(_perBookStyles);
  FontCatalog get fontCatalog => _fontCatalog;
  ColorSource get colorSource => _colorSource;
  ReaderMotion get readerMotion => _readerMotion;
  ShelfPrefs get shelfPrefs => _shelfPrefs;
  BackupSnapshot get backup => _backup;
  BilingualPrefs get bilingual => _bilingual;
  StatsViewKind get statsView => _statsView;
  BookKind get favoritesKind => _favoritesKind;
  StatsPeriod get statsPeriod => _statsPeriod;
  ReportLayout get reportLayout => _reportLayout;

  /// 每本书排版覆盖的**唯一裁决点**：把全局设置与书级覆盖一起交给
  /// `EffectiveReaderStyle.resolve()`，页面不自己拼 TextStyle。
  EffectiveReaderStyle effectiveReaderStyleFor(String bookId) =>
      EffectiveReaderStyle.resolve(_settings.reader, _perBookStyles, bookId);

  void updatePerBookStyle(String bookId, PerBookStyle style) {
    if (style.isEmpty) {
      if (_perBookStyles.remove(bookId) == null) return;
    } else {
      if (_perBookStyles[bookId] == style) return;
      _perBookStyles[bookId] = style;
    }
    notifyListeners();
  }

  void clearPerBookStyle(String bookId) {
    if (_perBookStyles.remove(bookId) == null) return;
    notifyListeners();
  }

  void updateFontCatalog(FontCatalog next) {
    if (next == _fontCatalog) return;
    _fontCatalog = next;
    notifyListeners();
  }

  void updateColorSource(ColorSource next) {
    if (next == _colorSource) return;
    _colorSource = next;
    notifyListeners();
  }

  void updateReaderMotion(ReaderMotion next) {
    final ReaderMotion n = next.normalized();
    if (n == _readerMotion) return;
    _readerMotion = n;
    notifyListeners();
  }

  void updateShelfPrefs(ShelfPrefs next) {
    final ShelfPrefs n = next.normalized();
    if (n == _shelfPrefs) return;
    _shelfPrefs = n;
    notifyListeners();
  }

  void updateBackup(BackupSnapshot next) {
    final BackupSnapshot n = next.normalized();
    if (n.enabled == _backup.enabled && n.state == _backup.state) return;
    _backup = n;
    notifyListeners();
  }

  void updateBilingual(BilingualPrefs next) {
    if (next == _bilingual) return;
    _bilingual = next;
    notifyListeners();
  }

  void updateStatsView(StatsViewKind next) {
    if (next == _statsView) return;
    _statsView = next;
    notifyListeners();
  }

  void setFavoritesKind(BookKind next) {
    if (next == _favoritesKind) return;
    _favoritesKind = next;
    notifyListeners();
  }

  void updateStatsPeriod(StatsPeriod next) {
    final StatsPeriod n = next.normalized();
    if (n == _statsPeriod) return;
    _statsPeriod = n;
    notifyListeners();
  }

  void updateReportLayout(ReportLayout next) {
    if (next == _reportLayout) return;
    _reportLayout = next;
    notifyListeners();
  }

  /// 个人页摘要**每次读都重新聚合**，不缓存成字段：统计页、纪念物册、
  /// 小组件预览都用同一份 `stats.snapshot()`，新增摘录后同一次刷新即可见。
  ProfileSummary get profileSummary =>
      ProfileSummary.fromSnapshot(stats.snapshot());

  /// 报告预览与导出共用同一个 payload，避免两处拼装分裂。
  ReportPayload get reportPayload => ReportPayload.build(
        layout: _reportLayout,
        period: _statsPeriod,
        snapshot: stats.snapshot(),
      );

  bool get onlineEnabled => _settings.onlineEnabled;
  bool get networkingAllowed => _settings.networkingAllowed;
  bool get motionEnabled => _settings.motion;
  bool get ttsEnabled => _settings.tts;

  /// 启动时读持久化设置；仍走 normalized()，防止旧数据里存着「纯本地 + 在线开」的脏组合。
  Future<void> bootstrap() async {
    _settings = (await settingsStore.load()).normalized();
    notifyListeners();
  }

  void updateSettings(AppSettings next) {
    final AppSettings normalized = next.normalized();
    if (normalized == _settings) return;
    final bool wasOnline = _settings.onlineEnabled;
    _settings = normalized;
    final bool nowOnline = normalized.onlineEnabled;
    // 第二十二轮：在线开关与目录状态不能各说各话。打开后自动刷新一次，
    // 关闭后立刻回到锁定态并丢弃列表，避免「关了在线却还显示上一批目录」。
    if (nowOnline && !wasOnline) {
      unawaited(refreshWenku8());
    } else if (!nowOnline && wasOnline) {
      _wenku8Status = Wenku8Status.lockedByPureLocal;
      _wenku8Listing = null;
    }
    notifyListeners();
    unawaited(settingsStore.save(normalized));
  }

  void setPureLocal(bool value) {
    // 打开纯本地时，master switch 会自动清零在线目录与 WebDAV。
    updateSettings(_settings.copyWith(pureLocal: value));
  }

  void setOnlineDirectory(bool value) {
    // 纯本地模式下不允许直接开启：先引导用户关 master switch。
    if (_settings.pureLocal && value) return;
    updateSettings(_settings.copyWith(onlineDirectory: value));
  }

  void setWebdav(bool value) {
    if (_settings.pureLocal && value) return;
    updateSettings(_settings.copyWith(webdav: value));
  }


  void enableWebdav() => updateSettings(
        _settings.copyWith(pureLocal: false, webdav: true),
      );

  // ---------------------------------------------------------------- WebDAV 备份载荷

  /// README 四项：书库元数据 / 阅读进度 / 分组 / 阅读会话。
  /// 额外带上收藏、摘录与小组件配置，恢复后各页面零改动即可重建。
  Map<String, Object?> backupPayload() => <String, Object?>{
        'schema': 1,
        'settings': _settings.toMap(),
        'books': <Object?>[
          for (final BookSummary b in _importedBooks) _bookToMap(b),
        ],
        'lastReadAt': <Object?>[
          for (final MapEntry<String, DateTime> e in _lastReadAt.entries)
            <String, Object?>{
              'id': e.key,
              'at': e.value.millisecondsSinceEpoch,
            },
        ],
        'progressOverrides': <Object?>[
          for (final MapEntry<String, double> e in _progressOverrides.entries)
            <String, Object?>{'id': e.key, 'progress': e.value},
        ],
        'favorites': <Object?>[
          for (final FavoriteEntry f in _favorites) f.toMap(),
        ],
        'excerpts': <Object?>[
          for (final Excerpt e in _userExcerpts) _excerptToMap(e),
        ],
        'widgetSpecs': <Object?>[
          for (final WidgetSpec s in _widgetSpecs) _widgetToMap(s),
        ],
        'groups': <Object?>[],
        'sessions': <Object?>[],
      };

  /// 从远端 / 本地备份恢复。未知字段一律忽略，坏数据不会让应用崩溃。
  void restoreFromBackup(Map<String, Object?> m) {
    final Object? rawSettings = m['settings'];
    if (rawSettings is Map) {
      updateSettings(AppSettings.fromMap(Map<String, Object?>.from(rawSettings)));
    }

    final Object? rawBooks = m['books'];
    if (rawBooks is List) {
      _importedBooks.clear();
      for (final Object? item in rawBooks) {
        if (item is Map) {
          final BookSummary? b = _bookFromMap(Map<String, Object?>.from(item));
          if (b != null) _importedBooks.add(b);
        }
      }
    }

    final Object? rawLast = m['lastReadAt'];
    if (rawLast is List) {
      _lastReadAt.clear();
      for (final Object? item in rawLast) {
        if (item is Map) {
          final String id = (item['id'] as String?) ?? '';
          final int ms = (item['at'] as num?)?.toInt() ?? 0;
          if (id.isNotEmpty) {
            _lastReadAt[id] = DateTime.fromMillisecondsSinceEpoch(ms);
          }
        }
      }
    }

    final Object? rawProgress = m['progressOverrides'];
    if (rawProgress is List) {
      _progressOverrides.clear();
      for (final Object? item in rawProgress) {
        if (item is Map) {
          final String id = (item['id'] as String?) ?? '';
          final double p = (item['progress'] as num?)?.toDouble() ?? 0;
          if (id.isNotEmpty) _progressOverrides[id] = p;
        }
      }
    }

    final Object? rawFavorites = m['favorites'];
    if (rawFavorites is List) {
      _favorites.clear();
      for (final Object? item in rawFavorites) {
        if (item is Map) {
          final FavoriteEntry f =
              FavoriteEntry.fromMap(Map<String, Object?>.from(item));
          if (f.bookId.isNotEmpty) _favorites.add(f);
        }
      }
    }

    final Object? rawExcerpts = m['excerpts'];
    if (rawExcerpts is List) {
      _userExcerpts.clear();
      _excerptSeq = 0;
      for (final Object? item in rawExcerpts) {
        if (item is Map) {
          final Excerpt? e = _excerptFromMap(Map<String, Object?>.from(item));
          if (e != null) {
            _userExcerpts.add(e);
            _excerptSeq++;
          }
        }
      }
    }

    final Object? rawWidgets = m['widgetSpecs'];
    if (rawWidgets is List) {
      for (final Object? item in rawWidgets) {
        if (item is Map) {
          final Map<String, Object?> w = Map<String, Object?>.from(item);
          final String id = (w['id'] as String?) ?? '';
          if (id.isEmpty) continue;
          updateWidgetSpec(WidgetSpec(
            id: id,
            content: _enumByName(
                WidgetContent.values, w['content'], WidgetContent.today),
            size: _enumByName(WidgetSize.values, w['size'], WidgetSize.small),
            season: season.value,
            showProgress: (w['showProgress'] as bool?) ?? true,
          ));
        }
      }
    }

    notifyListeners();
    unawaited(settingsStore.save(_settings));
  }

  T _enumByName<T>(List<T> values, Object? name, T fallback) {
    if (name is! String) return fallback;
    for (final T v in values) {
      if ((v as dynamic).name == name) return v;
    }
    return fallback;
  }

  Map<String, Object?> _bookToMap(BookSummary b) => <String, Object?>{
        'id': b.id,
        'title': b.title,
        'author': b.author,
        'shelf': b.shelf,
        'format': b.format,
        'encoding': b.encoding,
        'progress': b.progress,
        'color': b.spineColor.toARGB32(),
        'volumeOrder': b.volumeOrder,
      };

  BookSummary? _bookFromMap(Map<String, Object?> m) {
    final String id = (m['id'] as String?) ?? '';
    if (id.isEmpty) return null;
    return BookSummary(
      id: id,
      title: (m['title'] as String?) ?? id,
      author: (m['author'] as String?) ?? '',
      shelf: (m['shelf'] as String?) ?? '本地书库',
      format: (m['format'] as String?) ?? 'TXT',
      encoding: (m['encoding'] as String?) ?? 'UTF-8',
      progress: (m['progress'] as num?)?.toDouble() ?? 0,
      spineColor: Color((m['color'] as num?)?.toInt() ?? 0xFF4A6180),
      volumeOrder: (m['volumeOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> _excerptToMap(Excerpt e) => <String, Object?>{
        'id': e.id,
        'bookId': e.bookId,
        'bookTitle': e.bookTitle,
        'chapterTitle': e.chapterTitle,
        'text': e.text,
        'capturedAt': e.capturedAt.millisecondsSinceEpoch,
        'chapterIndex': e.chapterIndex,
        'pageIndex': e.pageIndex,
        'highlight': e.highlight.name,
        'note': e.note,
        'signature': e.signature,
        'crossParagraph': e.crossParagraph,
      };

  Excerpt? _excerptFromMap(Map<String, Object?> m) {
    final String text = (m['text'] as String?) ?? '';
    if (text.isEmpty) return null;
    return Excerpt(
      id: (m['id'] as String?) ?? 'u-restored',
      bookId: (m['bookId'] as String?) ?? '',
      bookTitle: (m['bookTitle'] as String?) ?? '',
      chapterTitle: (m['chapterTitle'] as String?) ?? '',
      text: text,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['capturedAt'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch),
      chapterIndex: (m['chapterIndex'] as num?)?.toInt() ?? 0,
      pageIndex: (m['pageIndex'] as num?)?.toInt() ?? 0,
      highlight: _enumByName(
          HighlightColor.values, m['highlight'], HighlightColor.amber),
      note: (m['note'] as String?) ?? '',
      isUserAdded: true,
      crossParagraph: (m['crossParagraph'] as bool?) ?? false,
      signature: (m['signature'] as String?) ?? '',
    );
  }

  Map<String, Object?> _widgetToMap(WidgetSpec s) => <String, Object?>{
        'id': s.id,
        'content': s.content.name,
        'size': s.size.name,
        'showProgress': s.showProgress,
      };

  void setMotion(bool value) => updateSettings(_settings.copyWith(motion: value));
  void setTts(bool value) => updateSettings(_settings.copyWith(tts: value));

  /// 阅读排版面板的唯一写入口。normalized() 会在 motion 关闭时把翻页动效锁为 none，
  /// 面板不需要自己解释这条规则。
  void updateReader(ReaderStyle next) => updateSettings(_settings.copyWith(reader: next));

  void resetReader() => updateReader(const ReaderStyle());

  void setSeason(SeasonStyle style) {
    if (season.value == style) return;
    season.value = style; // season 的 listener 会触发 notifyListeners
  }

  @override
  void dispose() {
    season.removeListener(notifyListeners);
    season.dispose();
    super.dispose();
  }
}

/// InheritedNotifier：页面通过 AppScope.of(context) 读取并订阅，
/// 状态变化只重建依赖它的子树，不重建整个 IndexedStack。
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 未挂载：请检查 MaterialApp 外层');
    return scope!.notifier!;
  }
}
