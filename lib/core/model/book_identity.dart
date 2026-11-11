/// 书籍来源与展示编号的**唯一裁决点**。
///
/// 口径（对齐 docs/03 §3.5、PLAN.md P8 及第三十轮详情页契约）：
/// - 本地书籍 id 原样使用，展示编号 `LR-<bookid>`；
/// - 云端书籍在书库里统一带 `cloud-` 前缀，展示编号 `WK-<bookid>`（去掉前缀）；
/// - 封面右上角的「本地 / 云端」角标、卡片副标题「本地书籍 / 云端书籍」
///   也都从这里取值，避免书架 / 列表 / 详情页各写一份前缀判断。
///
/// 本文件位于 core 层，不依赖 domain / feature，纯 Dart，便于模型级单测。
library;

/// 书籍来源。
enum BookOrigin { local, cloud }

class BookIdentity {
  const BookIdentity._();

  /// 书库内部用来区分云端书籍的前缀（详情页、筛选、缓存共用）。
  static const String cloudPrefix = 'cloud-';

  static const String localDisplayPrefix = 'LR-';
  static const String cloudDisplayPrefix = 'WK-';

  static BookOrigin originOf(String bookId) =>
      bookId.startsWith(cloudPrefix) ? BookOrigin.cloud : BookOrigin.local;

  static bool isCloudId(String bookId) => originOf(bookId) == BookOrigin.cloud;

  /// 去掉云端前缀后的原始 bookid（本地 id 原样返回）。
  static String rawId(String bookId) => bookId.startsWith(cloudPrefix)
      ? bookId.substring(cloudPrefix.length)
      : bookId;

  /// 把来源站点的原始 id 包成书库内部 id；已经是 cloud- 时不重复添加。
  static String cloudId(String rawId) =>
      rawId.startsWith(cloudPrefix) ? rawId : '$cloudPrefix$rawId';

  /// 展示编号：本地 `LR-<bookid>`，云端 `WK-<bookid>`。
  /// 只用于 UI 展示，绝不写回书库主键（主键仍是带 cloud- 前缀的完整 id）。
  static String displayId(String bookId) {
    final BookOrigin origin = originOf(bookId);
    return '${origin == BookOrigin.cloud ? cloudDisplayPrefix : localDisplayPrefix}'
        '${rawId(bookId)}';
  }

  /// 封面右上角角标文案。
  static String originLabel(BookOrigin origin) =>
      origin == BookOrigin.cloud ? '云端' : '本地';

  /// 卡片 / 详情页的来源副标题。
  static String sourceSubtitle(BookOrigin origin) =>
      origin == BookOrigin.cloud ? '云端书籍' : '本地书籍';

  static BookOrigin originOfDisplayId(String displayId) =>
      displayId.startsWith(cloudDisplayPrefix)
          ? BookOrigin.cloud
          : BookOrigin.local;
}
