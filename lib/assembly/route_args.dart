import 'package:flutter/foundation.dart';

import '../domain/repositories/book_repository.dart';
import '../domain/usecases/import_session.dart';
import '../core/model/stats/keepsake_kind.dart';
import '../core/model/stats/stats_date.dart';

/// 导航目标由 app 层注入：feature 页面只认这些回调，不自己构造路由。
/// 对齐原 Kotlin 工程「feature 之间不互相依赖，导航目标由 app 注入」。
typedef OpenBookDetail = void Function(BookSummary book);
typedef OpenReaderPage = void Function(BookSummary book, int chapterIndex);
typedef OpenTocPage = Future<int?> Function(BookSummary book, int currentChapter);

/// 打开独立搜索结果页，带上书架页里已输入的关键词。
typedef OpenSearchPage = void Function(String query);

/// 第二十四轮：功能总览页的强类型参数，可指定初始分组。
/// 与其它 *Args 一样，`AppRoutes` 里必须有 `args is` 守卫。
class FeatureMatrixArgs {
  const FeatureMatrixArgs({this.initialTab = 0});

  final int initialTab;

  int get normalizedTab => initialTab < 0 || initialTab > 4 ? 0 : initialTab;
}

/// 打开摘录管理页，可带初始关键词与按书筛选（统计页用）。
typedef OpenExcerptLibrary = void Function(String query, String? bookId);

/// 第二十一轮：日历「查看当天摘录」→ 摘录管理页，只传强类型 Args。
/// 页面不构造路由、不 import 另一个 feature，与纪念物深链同一套纪律。
typedef OpenExcerptLibraryArgs = void Function(ExcerptLibraryArgs args);

/// 详情页 → 摘录管理页：只传 bookId，书名是编辑覆盖层不能当筛选值。
typedef OpenBookExcerpts = void Function(String bookId);

/// 导入说明入口由 app 层注入：多个 feature 共用同一个 core 弹窗，
/// 避免 feature 之间互相 import，也便于未来换成真实 SAF 流程。
typedef ShowImport = void Function();

/// 打开多步骤导入向导，由 app 层注入。
typedef OpenImportWizard = void Function();

/// 打开整月阅读日历，由 app 层注入（带上当前显示的年月）。
typedef OpenCalendarMonth = void Function(int year, int month);

/// 打开纪念物册（完整视图）。带上统计页卡片当前的类型 / 月份筛选，
/// 让「在卡上筛了连续类」进册子后仍是连续类，不重置回全部。
/// 只传枚举与月份 key，页面不构造路由、不 import 另一个 feature。
typedef OpenKeepsakeLibrary = void Function(
  KeepsakeKind? kind,
  String? monthKey,
);

/// 第二十轮 · 双向深链：页面只把**强类型 Args**交给 app 层，不自己拼路由名 /
/// 参数字段。统计页 / 纪念物卡的老 typedef 保留，两个新 typedef 给日历与册子用。
typedef OpenKeepsakeLibraryArgs = void Function(KeepsakeLibraryArgs args);
typedef OpenCalendarMonthArgs = void Function(CalendarMonthArgs args);

/// 详情页参数。
@immutable
class DetailArgs {
  const DetailArgs({required this.book});
  final BookSummary book;
}

/// 章节目录参数。目录页不自己跳阅读器，而是 pop 出选中的章节序号，
/// 由调用方（详情页 / 阅读器）决定是新建阅读器还是切换章节，避免页面栈里堆两个阅读器。
@immutable
class TocArgs {
  const TocArgs({required this.book, this.currentChapter = 0});
  final BookSummary book;
  final int currentChapter;
}

/// 阅读器参数。
@immutable
class ReaderArgs {
  const ReaderArgs({required this.book, this.chapterIndex = 0});
  final BookSummary book;
  final int chapterIndex;
}

/// 搜索结果页参数：书架页把已输入的关键词带过去，避免用户重打一遍。
@immutable
class SearchArgs {
  const SearchArgs({this.initialQuery = ''});
  final String initialQuery;
}

/// 摘录管理页参数：统计页可带初始关键词或 bookId 打开筛选结果。
///
/// 深链入口（详情页「这本书的摘录」、收藏跳转、统计页摘录卡、日历「当天摘录」）
/// 都必须走工厂，不在调用点散写 `initialBookId: ...` / `initialDateKey: ...`：
/// 否则某处漏传就会静默变成「打开全部摘录」，且很难肉眼发现。
@immutable
class ExcerptLibraryArgs {
  const ExcerptLibraryArgs({
    this.initialQuery = '',
    this.initialBookId,
    this.initialDateKey,
  });

  /// 按书深链：详情页 / 收藏共用。id 为空时不带筛选，绝不打开一个空 id 条件。
  factory ExcerptLibraryArgs.forBook(String bookId) => ExcerptLibraryArgs(
        initialQuery: '',
        initialBookId: bookId.isEmpty ? null : bookId,
      );

  /// 关键词深链：统计页的摘录卡入口（可同时带按书筛选）。
  factory ExcerptLibraryArgs.forQuery(String query, {String? bookId}) =>
      ExcerptLibraryArgs(
        initialQuery: query,
        initialBookId: (bookId == null || bookId.isEmpty) ? null : bookId,
      );

  /// 第二十一轮：阅读日历选中日 → 「只看这一天摘下的话」。
  /// 严格解析 dateKey，非法一律回落不带筛选，绝不把脏字符串塞进路由；
  /// 跨月补格由 `CalendarDayLink` 在调用侧禁用，这里只负责日期本身。
  /// 按日与按书是**两个独立维度**：从日历进来的深链不带 bookId。
  factory ExcerptLibraryArgs.fromDay(String? dateKey) {
    final DateTime? d = tryParseDateKey(dateKey);
    return d == null
        ? const ExcerptLibraryArgs()
        : ExcerptLibraryArgs(initialDateKey: dateKeyOf(d));
  }

  final String initialQuery;
  final String? initialBookId;
  final String? initialDateKey;

  /// 是否是「只看某一本书」的深链，供页面与规格单测共用同一判据。
  bool get isBookScoped => initialBookId != null && initialBookId!.isNotEmpty;
  bool get isDayScoped => initialDateKey != null;
}

/// 导入向导参数：可指定起始步骤，便于「重扫」直接跳到扫描页。
@immutable
class ImportWizardArgs {
  const ImportWizardArgs({this.initialStep = ImportStep.intro});
  final ImportStep initialStep;
}

/// 整月日历参数：可指定年月与默认选中的日期 key，便于未来从纪念物 / 小组件深链。
@immutable
class CalendarMonthArgs {
  const CalendarMonthArgs({this.year, this.month, this.selectedDateKey});

  /// 纪念物册 → 日历：按 `YYYY-MM-DD` 反解年月并选中当天。
  /// 非法 key 回落到不带任何约束的默认参数，绝不把脏字符串塞进路由。
  factory CalendarMonthArgs.fromDateKey(String? dateKey) {
    final DateTime? d = tryParseDateKey(dateKey);
    return d == null
        ? const CalendarMonthArgs()
        : CalendarMonthArgs(
            year: d.year,
            month: d.month,
            selectedDateKey: dateKeyOf(d),
          );
  }

  /// 纪念物册 / 小组件 → 日历：只定位整月，不改选中日。
  factory CalendarMonthArgs.fromMonthKey(String? monthKey) {
    final MonthAnchor? a = tryParseMonthKey(monthKey);
    return a == null
        ? const CalendarMonthArgs()
        : CalendarMonthArgs(year: a.year, month: a.month);
  }

  final int? year;
  final int? month;
  final String? selectedDateKey;

  bool get isDayScoped => selectedDateKey != null;
}

/// 纪念物册参数：从统计页卡片带入当前类型 / 月份筛选。
/// 两个工厂把「不带筛选」和「只按类型 / 只按月份」收口，避免调用点散写字段。
@immutable
class KeepsakeLibraryArgs {
  const KeepsakeLibraryArgs({
    this.initialKind,
    this.initialMonthKey,
    this.initialDateKey,
  });

  factory KeepsakeLibraryArgs.fromCard(KeepsakeKind? kind, String? monthKey) =>
      KeepsakeLibraryArgs(
        initialKind: kind,
        initialMonthKey: (monthKey == null || monthKey.isEmpty) ? null : monthKey,
      );

  /// 日历 → 纪念物册：只看某一天。月份同步由 dateKey 反解，
  /// **不信任调用方另传的 monthKey**，避免「日期 11-08、月份却是 10」的脏组合。
  factory KeepsakeLibraryArgs.fromDay(String? dateKey) {
    final DateTime? d = tryParseDateKey(dateKey);
    return d == null
        ? const KeepsakeLibraryArgs()
        : KeepsakeLibraryArgs(
            initialDateKey: dateKeyOf(d),
            initialMonthKey: monthKeyOf(d),
          );
  }

  /// 日历月度汇总 / 小组件预览 → 纪念物册：只看整月。
  factory KeepsakeLibraryArgs.fromMonth(String? monthKey) {
    final MonthAnchor? a = tryParseMonthKey(monthKey);
    return a == null
        ? const KeepsakeLibraryArgs()
        : KeepsakeLibraryArgs(initialMonthKey: a.key);
  }

  final KeepsakeKind? initialKind;
  final String? initialMonthKey;
  final String? initialDateKey;

  bool get isScoped =>
      initialKind != null || initialMonthKey != null || initialDateKey != null;
  bool get isDayScoped => initialDateKey != null;

  /// 深链不变量：带日期时，月份必须与日期同月且非空。
  bool get isConsistent {
    if (initialDateKey == null) return true;
    return initialMonthKey != null &&
        monthKeyOfDateKey(initialDateKey) == initialMonthKey;
  }
}

enum MineSection { stats, bookmarks, settings, about, support }

class MineSectionArgs {
  const MineSectionArgs(this.section);

  final MineSection section;
}

/// R13 · 导入书籍流程的强类型参数（合并版新增，命名避开现有 *Args）。
/// 页面只认 Args，不自己拼路由名；接入 onGenerateRoute 时补 `args is` 守卫。
class ImportBooksArgs {
  const ImportBooksArgs({this.openScanFolder = false});
  final bool openScanFolder;
}

class ImportSettingsArgs {
  const ImportSettingsArgs({this.showRulePreview = true});
  final bool showRulePreview;
}

class ScanFolderArgs {
  const ScanFolderArgs({this.root = '', this.format = 'all'});
  final String root;
  final String format;
}

class MergeBooksArgs {
  const MergeBooksArgs({required this.batchId, this.query = ''});
  final String batchId;
  final String query;
}

/// 底栏两个新 tab 的强类型参数（路由 /favorites 与 /wenkuLibrary）。
class WenkuLibraryArgs {
  const WenkuLibraryArgs({this.initialRank = 0});
  final int initialRank;
}

class FavoritesArgs {
  const FavoritesArgs({this.section = 0, this.comicOnly = false});
  final int section;
  final bool comicOnly;
}
