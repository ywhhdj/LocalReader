import '../../core/model/book_identity.dart';
import '../../core/model/wenku/wenku8_models.dart';
import '../repositories/book_repository.dart';

/// 云端 Wenku8 书目 ⇄ 书库 BookSummary 的**唯一投影**。
///
/// 书架云端视图、轻小说文库、收藏页里点开的都是同一个 `/detail` 页面，
/// 统一吃 BookSummary；云端书进书库时仍只登记元数据壳，不下载正文。
/// 投影放在 domain 层，core/ui 的卡片组件不需要认识 Wenku8Book。

const String kCloudShelfName = '最近阅读';

/// 站点书目 → 书库摘要（id 带 cloud- 前缀，展示编号自动变成 WK-）。
BookSummary cloudBookSummary(Wenku8Book book) => BookSummary(
      id: BookIdentity.cloudId(book.id),
      title: book.title,
      author: book.author.isEmpty ? '未知作者' : book.author,
      spineColor: book.coverColor,
      shelf: kCloudShelfName,
      format: 'EPUB',
      encoding: 'UTF-8',
      volumeOrder: book.volumeCount <= 0 ? 0 : book.volumeCount,
    );

/// 书库摘要 → 站点书目：详情页「加入书架 / 缓存」时复用既有合规校验。
Wenku8Book cloudBookOf(BookSummary book) => Wenku8Book(
      id: BookIdentity.rawId(book.id),
      title: book.title,
      author: book.author.isEmpty ? '未知作者' : book.author,
      coverColor: book.spineColor,
      tags: const <String>['云端'],
      latestChapter: '',
      updatedKey: '',
      volumeCount: book.volumeOrder <= 0 ? 1 : book.volumeOrder,
    );

/// 按展示编号或内部 id 找到书库摘要（云端视图点击时先从目录里查元数据）。
BookSummary? cloudSummaryFor(
  Iterable<Wenku8Book> books,
  String idOrDisplayId,
) {
  final String raw = BookIdentity.rawId(
    idOrDisplayId.startsWith(BookIdentity.cloudDisplayPrefix)
        ? '${BookIdentity.cloudPrefix}'
            '${idOrDisplayId.substring(BookIdentity.cloudDisplayPrefix.length)}'
        : idOrDisplayId,
  );
  for (final Wenku8Book b in books) {
    if (b.id == raw || BookIdentity.cloudId(b.id) == idOrDisplayId) {
      return cloudBookSummary(b);
    }
  }
  return null;
}
