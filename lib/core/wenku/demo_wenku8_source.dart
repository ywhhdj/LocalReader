import 'dart:ui' show Color;

import 'wenku8_compliance.dart';
import 'wenku8_models.dart';
import 'wenku8_source.dart';

/// 静态交付模式下的**确定性演示数据源**。
///
/// 不发 HTTP、不读文件、不缓存小说正文；只提供元数据，让「榜单 → 详情 →
/// 章节目录 → 加入本地」整条链路在零 SDK 环境下可走通。真实接入时替换为
/// `HttpWenku8Source`（❄️ 冻结），页面与 `AppState` 不用改。
class DemoWenku8Source implements Wenku8Source {
  const DemoWenku8Source();

  @override
  String get sourceId => Wenku8Compliance.wenku8SourceId;

  static const List<Wenku8Book> allBooks = <Wenku8Book>[];

  /// 全量也先过滤下架内容：合规层是**所有**列表出口的必经之路。
  static List<Wenku8Book> get available =>
      Wenku8Compliance.withoutWithdrawn(allBooks);

  static List<Wenku8Book> _feed(Wenku8Query q) {
    final List<Wenku8Book> base = available;
    final String kw = q.keyword.trim().toLowerCase();
    if (kw.isNotEmpty) {
      return List<Wenku8Book>.unmodifiable(base.where(
        (Wenku8Book b) =>
            b.title.toLowerCase().contains(kw) ||
            b.author.toLowerCase().contains(kw),
      ));
    }
    switch (q.feed) {
      case Wenku8FeedKind.recommendation:
        return base;
      case Wenku8FeedKind.recent:
        final List<Wenku8Book> out = List<Wenku8Book>.of(base)
          ..sort((Wenku8Book a, Wenku8Book b) =>
              b.updatedKey.compareTo(a.updatedKey));
        return List<Wenku8Book>.unmodifiable(out);
      case Wenku8FeedKind.ranking:
        return List<Wenku8Book>.unmodifiable(base.reversed);
      case Wenku8FeedKind.completed:
        return List<Wenku8Book>.unmodifiable(
          base.where((Wenku8Book b) => b.tags.contains('已完结')),
        );
      case Wenku8FeedKind.search:
        return base;
    }
  }

  @override
  Future<Wenku8Listing> listing(Wenku8Query query) async {
    final Wenku8Query q = query.normalized();
    return Wenku8Listing(
      feed: q.feed,
      books: _feed(q),
      status: Wenku8Status.ok,
      note: '演示目录 · 不含小说正文',
    );
  }

  @override
  Future<Wenku8Detail?> detail(String bookId) async {
    Wenku8Book? book;
    for (final Wenku8Book b in available) {
      if (b.id == bookId) {
        book = b;
        break;
      }
    }
    if (book == null) return null;
    final List<Wenku8Volume> volumes = List<Wenku8Volume>.unmodifiable(
      List<Wenku8Volume>.generate(
        book.volumeCount,
        (int i) => Wenku8Volume(
          index: i + 1,
          title: '第 ${i + 1} 卷',
          chapters: List<Wenku8Chapter>.unmodifiable(
            List<Wenku8Chapter>.generate(
              4,
              (int j) => Wenku8Chapter(
                index: i * 4 + j,
                title: '第 ${j + 1} 章 · 章节 ${i * 4 + j + 1}',
                volumeIndex: i + 1,
              ),
            ),
          ),
        ),
      ),
    );
    return Wenku8Detail(
      book: book,
      synopsis: '${book.title} · ${book.author}。目录与简介为演示元数据，'
          '章节正文由 Wenku8 在使用时提供，本应用不缓存、不打包、不分发。',
      volumes: volumes,
    );
  }
}
