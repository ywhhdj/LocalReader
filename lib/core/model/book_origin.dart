import '../../domain/repositories/book_repository.dart';

/// 第三十轮：详情页按钮语义（云端收藏 / 评论 vs 本地收藏 / 分组）
/// 与右上角图标（云下载 vs 删除 / 重置进度）只看这一个裁决点。
/// 书架筛选 `ShelfPrefs._sourceMatches` 用的是同一个前缀，口径不分裂。
enum BookOrigin { local, cloud }

class BookOriginResolver {
  const BookOriginResolver._();

  static const String cloudPrefix = 'cloud-';

  static BookOrigin of(BookSummary book) =>
      book.id.startsWith(cloudPrefix) ? BookOrigin.cloud : BookOrigin.local;

  static bool isCloud(BookSummary book) => of(book) == BookOrigin.cloud;
}
