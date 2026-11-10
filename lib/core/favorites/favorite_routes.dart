import 'package:flutter/foundation.dart';

import '../data/book_repository.dart';
import '../router/route_args.dart';

/// 收藏路由：把「一条收藏」解析成「路由名 + 强类型参数」的**唯一出口**。
///
/// 原项目 README 里「收藏路由与书架筛选」是一次提交里并列的两件事。
/// 这里对应前者：详情页 / 阅读器 / 书架 / 「我的」页只负责 toggle 与展示，
/// 真正要跳去哪由 app 层按 FavoriteNavigation 统一映射（feature 层不构造路由）。
///
/// 静态口径：收藏只存内存，不落库；不含任何网络请求，纯本地 master switch 不受影响。

enum FavoriteTarget { detail, reader, excerpts }

enum FavoriteRouteName { detail, reader, excerpts }

class FavoriteTargetLabels {
  const FavoriteTargetLabels._();

  static const Map<FavoriteTarget, String> labels = <FavoriteTarget, String>{
    FavoriteTarget.detail: '书籍详情',
    FavoriteTarget.reader: '继续阅读',
    FavoriteTarget.excerpts: '这本书的摘录',
  };

  static const Map<FavoriteTarget, Object> icons = <FavoriteTarget, Object>{
    // 只存语义名，避免 core 层依赖 material 图标；页面按名取图标。
    FavoriteTarget.detail: 'book',
    FavoriteTarget.reader: 'play',
    FavoriteTarget.excerpts: 'quote',
  };
}

@immutable
class FavoriteEntry {
  const FavoriteEntry({
    required this.bookId,
    this.target = FavoriteTarget.detail,
    required this.addedAt,
    this.note = '',
  });

  final String bookId;
  final FavoriteTarget target;
  final DateTime addedAt;
  final String note;

  FavoriteEntry copyWith({
    String? bookId,
    FavoriteTarget? target,
    DateTime? addedAt,
    String? note,
  }) =>
      FavoriteEntry(
        bookId: bookId ?? this.bookId,
        target: target ?? this.target,
        addedAt: addedAt ?? this.addedAt,
        note: note ?? this.note,
      );

  Map<String, Object> toMap() => <String, Object>{
        'bookId': bookId,
        'target': target.name,
        'addedAt': addedAt.toIso8601String(),
        'note': note,
      };

  static FavoriteEntry fromMap(Map<dynamic, dynamic> m) => FavoriteEntry(
        bookId: m['bookId'] is String ? m['bookId'] as String : '',
        target: _enum<FavoriteTarget>(
          m['target'],
          FavoriteTarget.values,
          FavoriteTarget.detail,
        ),
        addedAt: DateTime.tryParse(
              m['addedAt'] is String ? m['addedAt'] as String : '',
            ) ??
            DateTime.utc(2026, 1, 1),
        note: m['note'] is String ? m['note'] as String : '',
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
      other is FavoriteEntry &&
      other.bookId == bookId &&
      other.target == target &&
      other.addedAt == addedAt &&
      other.note == note;

  @override
  int get hashCode => Object.hash(bookId, target, addedAt, note);
}

/// 解析结果只带枚举与参数对象，不写死 '/detail' 这类字符串——
/// 路由常量在 AppRoutes 里单一维护，app 层做一次 switch 即可。
@immutable
class FavoriteNavigation {
  const FavoriteNavigation({required this.route, required this.arguments});

  final FavoriteRouteName route;
  final Object arguments;
}

typedef OpenFavorite = void Function(FavoriteNavigation navigation);

class FavoriteRouter {
  const FavoriteRouter._();

  /// 统一解析入口。书籍不存在时返回 null，调用方给提示而不是跳空页面。
  static FavoriteNavigation? resolve(FavoriteEntry entry, BookSummary? book) {
    if (book == null || book.id.isEmpty) return null;
    switch (entry.target) {
      case FavoriteTarget.detail:
        return FavoriteNavigation(
          route: FavoriteRouteName.detail,
          arguments: DetailArgs(book: book),
        );
      case FavoriteTarget.reader:
        return FavoriteNavigation(
          route: FavoriteRouteName.reader,
          arguments: ReaderArgs(book: book),
        );
      case FavoriteTarget.excerpts:
        return FavoriteNavigation(
          route: FavoriteRouteName.excerpts,
          arguments: ExcerptLibraryArgs.forBook(book.id),
        );
    }
  }

  static FavoriteRouteName routeNameFor(FavoriteTarget target) {
    switch (target) {
      case FavoriteTarget.detail: return FavoriteRouteName.detail;
      case FavoriteTarget.reader: return FavoriteRouteName.reader;
      case FavoriteTarget.excerpts: return FavoriteRouteName.excerpts;
    }
  }
}
