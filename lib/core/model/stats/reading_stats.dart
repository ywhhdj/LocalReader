import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../common/design_tokens.dart';
import 'excerpt_capture.dart';
import 'keepsake_kind.dart';
import 'stats_date.dart';

/// 统计与小组件的共享数据模型。
///
/// 参考仓库声明：今日阅读、周热力图、阅读日历、纪念与摘录卡，五种季节手账，
/// 每个小组件可独立配置内容与外观、可同时放置多个，S/M/L 三档支持明暗模式。
///
/// **边界**：这里只做「应用内配置 UI + 三端共享的数据模型」。
/// 桌面小组件本体不是 Flutter Widget 能画的——Android 用应用内配置，
/// iOS 用 WidgetKit 系统编辑控件，HarmonyOS 用卡片配置，均需原生实现（❄️ 冻结）。
/// Dart 侧只负责把配置序列化后交给各端读取。

// ---------------------------------------------------------------- 原始数据

@immutable
class ReadingDay {
  const ReadingDay({required this.date, this.minutes = 0, this.pages = 0});

  final DateTime date;
  final int minutes;
  final int pages;

  bool get hasRead => minutes > 0;

  /// 稳定 key：口径统一收口在 stats_date.dart，热力图与月度日历用同一个 key。
  String get key => dateKeyOf(date);
}

@immutable
class Excerpt {
  const Excerpt({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.text,
    required this.capturedAt,
    this.chapterIndex = 0,
    this.pageIndex = 0,
    this.highlight = HighlightColor.amber,
    this.note = '',
    this.isUserAdded = false,
    this.origin,
    this.crossParagraph = false,
    this.signature = '',
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final String chapterTitle;
  final String text;
  final DateTime capturedAt;

  // 以下字段由阅读器采集流程写入；演示摘录全部保持默认值，向后兼容。
  final int chapterIndex;
  final int pageIndex;
  final HighlightColor highlight;
  final String note;
  final bool isUserAdded;
  final LineRef? origin;
  final bool crossParagraph;

  /// 去重依据（见 SelectionDraft.signature）。演示数据为空串，不参与去重。
  final String signature;

  Excerpt copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    String? chapterTitle,
    String? text,
    DateTime? capturedAt,
    int? chapterIndex,
    int? pageIndex,
    HighlightColor? highlight,
    String? note,
    bool? isUserAdded,
    LineRef? origin,
    bool? crossParagraph,
    String? signature,
  }) =>
      Excerpt(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        bookTitle: bookTitle ?? this.bookTitle,
        chapterTitle: chapterTitle ?? this.chapterTitle,
        text: text ?? this.text,
        capturedAt: capturedAt ?? this.capturedAt,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        pageIndex: pageIndex ?? this.pageIndex,
        highlight: highlight ?? this.highlight,
        note: note ?? this.note,
        isUserAdded: isUserAdded ?? this.isUserAdded,
        origin: origin ?? this.origin,
        crossParagraph: crossParagraph ?? this.crossParagraph,
        signature: signature ?? this.signature,
      );

  /// 摘录卡的展示文本：有批注时把批注附在后面，不改动原文。
  String get displayText => note.isEmpty ? text : '$text\n\n—— $note';

  @override
  bool operator ==(Object other) =>
      other is Excerpt &&
      other.id == id &&
      other.bookId == bookId &&
      other.bookTitle == bookTitle &&
      other.chapterTitle == chapterTitle &&
      other.text == text &&
      other.capturedAt == capturedAt &&
      other.chapterIndex == chapterIndex &&
      other.pageIndex == pageIndex &&
      other.highlight == highlight &&
      other.note == note &&
      other.isUserAdded == isUserAdded &&
      other.origin == origin &&
      other.crossParagraph == crossParagraph &&
      other.signature == signature;

  @override
  int get hashCode => Object.hash(
        id, bookId, bookTitle, chapterTitle, text, capturedAt,
        chapterIndex, pageIndex, highlight, note, isUserAdded,
        origin, crossParagraph, signature,
      );
}

// ---------------------------------------------------------------- 小组件配置

/// 小组件可展示的内容类型。与统计页四张卡一一对应。
enum WidgetContent { today, heatmap, calendar, excerpt, streak, keepsake }

/// 三档尺寸：只描述「占多少格」，不描述像素——三端桌面网格单位不同。
enum WidgetSize { small, medium, large }

@immutable
class WidgetSpec {
  const WidgetSpec({
    required this.id,
    this.content = WidgetContent.today,
    this.size = WidgetSize.small,
    this.season = SeasonStyle.paper,
    this.showProgress = true,
    this.keepsakeKind,
  });

  final String id;
  final WidgetContent content;
  final WidgetSize size;

  /// 每个小组件可独立选季节样式，不跟随应用整体换肤。
  final SeasonStyle season;
  final bool showProgress;

  /// 内容选「纪念物」时，每个小组件可**单独**指定一种类型；null = 显示全部。
  /// 对应参考仓库「Configure each widget's content and appearance independently」。
  final KeepsakeKind? keepsakeKind;

  /// `keepsakeKind` 本身可为 null，所以清空必须用显式 `clearKeepsakeKind` 开关，
  /// 不能靠传 null——与 `ExcerptFilter.clearBook` 同一条纪律。
  WidgetSpec copyWith({
    String? id,
    WidgetContent? content,
    WidgetSize? size,
    SeasonStyle? season,
    bool? showProgress,
    KeepsakeKind? keepsakeKind,
    bool clearKeepsakeKind = false,
  }) =>
      WidgetSpec(
        id: id ?? this.id,
        content: content ?? this.content,
        size: size ?? this.size,
        season: season ?? this.season,
        showProgress: showProgress ?? this.showProgress,
        keepsakeKind: clearKeepsakeKind
            ? null
            : (keepsakeKind ?? this.keepsakeKind),
      );

  Map<String, Object> toMap() => <String, Object>{
        'id': id,
        'content': content.name,
        'size': size.name,
        'season': season.name,
        'showProgress': showProgress,
        'keepsakeKind': keepsakeKind?.name ?? '',
      };

  static WidgetSpec fromMap(Map<dynamic, dynamic> m) => WidgetSpec(
        id: m['id'] is String ? m['id'] as String : 'w',
        content: _enum<WidgetContent>(m['content'], WidgetContent.values, WidgetContent.today),
        size: _enum<WidgetSize>(m['size'], WidgetSize.values, WidgetSize.small),
        season: _enum<SeasonStyle>(m['season'], SeasonStyle.values, SeasonStyle.paper),
        showProgress: m['showProgress'] is bool ? m['showProgress'] as bool : true,
        keepsakeKind: (m['keepsakeKind'] is String &&
                (m['keepsakeKind'] as String).isNotEmpty)
            ? _enum<KeepsakeKind>(
                m['keepsakeKind'], KeepsakeKind.values, KeepsakeKind.firstRead)
            : null,
      );

  static T _enum<T extends Enum>(Object? raw, List<T> values, T fallback) {
    if (raw is! String) return fallback;
    for (final T v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is WidgetSpec &&
      other.id == id &&
      other.content == content &&
      other.size == size &&
      other.season == season &&
      other.showProgress == showProgress &&
      other.keepsakeKind == keepsakeKind;

  @override
  int get hashCode =>
      Object.hash(id, content, size, season, showProgress, keepsakeKind);
}

class WidgetSpecLabels {
  const WidgetSpecLabels._();

  static const Map<WidgetContent, String> content = <WidgetContent, String>{
    WidgetContent.today: '今日阅读',
    WidgetContent.heatmap: '阅读热力',
    WidgetContent.calendar: '阅读日历',
    WidgetContent.excerpt: '摘录卡',
    WidgetContent.streak: '连续天数',
    WidgetContent.keepsake: '纪念物',
  };

  static const Map<WidgetSize, String> size = <WidgetSize, String>{
    WidgetSize.small: '小 · 2×2',
    WidgetSize.medium: '中 · 4×2',
    WidgetSize.large: '大 · 4×4',
  };

  static const Map<WidgetContent, IconData> icon = <WidgetContent, IconData>{
    WidgetContent.today: Icons.schedule_outlined,
    WidgetContent.heatmap: Icons.grid_on_outlined,
    WidgetContent.calendar: Icons.calendar_month_outlined,
    WidgetContent.excerpt: Icons.format_quote_outlined,
    WidgetContent.streak: Icons.local_fire_department_outlined,
    WidgetContent.keepsake: Icons.auto_awesome_outlined,
  };
}

// ---------------------------------------------------------------- 聚合快照

@immutable
class StatsSnapshot {
  const StatsSnapshot({
    required this.today,
    required this.goalMinutes,
    required this.days,
    required this.excerpts,
    required this.totalBooks,
    this.lastReadBookId,
    this.lastReadBookTitle,
  });

  final int today;
  final int goalMinutes;

  /// 近 35 天（5 周 × 7 天），按时间升序，最后一格是今天。
  final List<ReadingDay> days;
  final List<Excerpt> excerpts;
  final int totalBooks;
  final String? lastReadBookId;
  final String? lastReadBookTitle;

  /// 连续阅读天数：从今天往回数，中断即停。今天没读也允许从昨天算起。
  int get streakDays {
    int streak = 0;
    for (int i = days.length - 1; i >= 0; i--) {
      if (days[i].hasRead) {
        streak++;
      } else if (i != days.length - 1) {
        break;
      }
    }
    return streak;
  }

  int get weekMinutes =>
      days.skip(days.length < 7 ? 0 : days.length - 7).fold<int>(0, (int s, ReadingDay d) => s + d.minutes);

  int get totalPages => days.fold<int>(0, (int s, ReadingDay d) => s + d.pages);

  double get progress => goalMinutes <= 0 ? 0 : (today / goalMinutes).clamp(0.0, 1.0).toDouble();

  /// 最近 7 天，供日历条使用。
  List<ReadingDay> get calendarWeek =>
      days.skip(days.length < 7 ? 0 : days.length - 7).toList();

  String get weekLabel => formatMinutes(weekMinutes);
  String get todayLabel => '$today';

  static String formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes 分钟';
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return m == 0 ? '$h 小时' : '$h 小时 $m 分';
  }

  /// 热力图分级：0 无阅读，1~4 由浅到深。边界固定，页面与三端小组件共用同一口径。
  static int heatmapLevel(int minutes) {
    if (minutes <= 0) return 0;
    if (minutes < 15) return 1;
    if (minutes < 30) return 2;
    if (minutes < 60) return 3;
    return 4;
  }
}

/// 参考仓库「cycle directly to another excerpt」：环形切换，不越界、不停在空项。
@immutable
class ExcerptCycler {
  const ExcerptCycler(this.excerpts, {this.index = 0});

  final List<Excerpt> excerpts;
  final int index;

  bool get hasMultiple => excerpts.length > 1;
  bool get isEmpty => excerpts.isEmpty;

  Excerpt? get current =>
      excerpts.isEmpty ? null : excerpts[index.clamp(0, excerpts.length - 1).toInt()];

  ExcerptCycler next() => excerpts.isEmpty
      ? this
      : ExcerptCycler(excerpts, index: (index + 1) % excerpts.length);

  ExcerptCycler previous() => excerpts.isEmpty
      ? this
      : ExcerptCycler(excerpts, index: (index - 1 + excerpts.length) % excerpts.length);

  ExcerptCycler select(int i) => excerpts.isEmpty
      ? this
      : ExcerptCycler(excerpts, index: i.clamp(0, excerpts.length - 1).toInt());
}

// ---------------------------------------------------------------- 仓储

abstract interface class StatsRepository {
  StatsSnapshot snapshot();
}

/// 固定基准日的演示数据：避免真机时间变化让热力图/连续天数在单测里漂移。
class DemoStatsRepository implements StatsRepository {
  DemoStatsRepository({DateTime? today}) : today = today ?? _defaultToday;

  static final DateTime _defaultToday = DateTime.utc(2026, 11, 9);
  final DateTime today;

  static const List<int> _minutes = <int>[
    0, 18, 42, 0, 76, 25, 12,
    30, 48, 0, 64, 20, 58, 0,
    0, 36, 88, 52, 9, 0, 45,
    62, 22, 0, 40, 72, 30, 55,
    14, 0, 47, 92, 26, 61, 46,
  ];

  @override
  StatsSnapshot snapshot() {
    final List<ReadingDay> days = <ReadingDay>[
      for (int i = 0; i < _minutes.length; i++)
        ReadingDay(
          date: today.subtract(Duration(days: _minutes.length - 1 - i)),
          minutes: _minutes[i],
          pages: _minutes[i] * 2 ~/ 3,
        ),
    ];
    return StatsSnapshot(
      today: _minutes.last,
      goalMinutes: 60,
      days: days,
      totalBooks: 4,
      lastReadBookId: 'b01',
      lastReadBookTitle: '雪国的旅行者',
      excerpts: <Excerpt>[
        Excerpt(
          id: 'e1',
          bookId: 'b01',
          bookTitle: '纸白纪事',
          chapterTitle: '第一章  纸白',
          text: '「书页翻过去的时候，屋里只剩下一小片安静。」',
          capturedAt: DateTime.utc(2026, 11, 8),
        ),
        Excerpt(
          id: 'e2',
          bookId: 'b02',
          bookTitle: '春樱手账',
          chapterTitle: '第三章  斜光',
          text: '「她把摘录卡夹进那一页，纸白微微发黄，像放久了的信。」',
          capturedAt: DateTime.utc(2026, 11, 6),
        ),
        Excerpt(
          id: 'e3',
          bookId: 'b03',
          bookTitle: '夏汐通信',
          chapterTitle: '第五章  雨后的目录',
          text: '「目录翻到最后一页时，才发现有些名字从来没有被写上去。」',
          capturedAt: DateTime.utc(2026, 11, 4),
        ),
        Excerpt(
          id: 'e4',
          bookId: 'b04',
          bookTitle: '秋笺残页',
          chapterTitle: '番外  书架背面',
          text: '「书架背面贴着一张旧便签，字迹淡得几乎要看不见。」',
          capturedAt: DateTime.utc(2026, 11, 2),
        ),
      ],
    );
  }
}
