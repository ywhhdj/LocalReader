import 'book_identity.dart';

export 'book_identity.dart' show BookOrigin;

/// 第三十轮：详情页按钮语义（云端收藏 / 评论 vs 本地收藏 / 分组）
/// 与右上角图标（云下载 vs 删除 / 重置进度）只看这一个裁决点。
/// 书架筛选 `ShelfPrefs._sourceMatches` 用的是同一个前缀，口径不分裂。
class BookOriginResolver {
  const BookOriginResolver._();

  static const String cloudPrefix = BookIdentity.cloudPrefix;

  static BookOrigin of(dynamic book) => BookIdentity.originOf(book.id as String);

  static bool isCloud(dynamic book) => of(book) == BookOrigin.cloud;
}
