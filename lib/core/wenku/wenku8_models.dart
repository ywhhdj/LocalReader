import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import 'wenku8_status.dart';

/// Wenku8 在线目录的**元数据模型**（第二十二轮）。
///
/// 只描述「书 / 卷 / 章 / 榜单」的元数据，**不承载小说正文、封面图或插画字节**。
/// 参考仓库 README 写明：在线列表与内容来自 Wenku8，本地书由用户导入；
/// 小说、封面、插画归各自权利人所有，源码许可不授予内容权利。本应用不运营
/// 在线书库、不发布小说、不打包小说文件，也不提供因版权原因下架的内容。
///
/// **静态边界**：字段都是演示元数据，不读文件、不发请求、不缓存正文。
/// 真实章节内容由 Wenku8 在用户使用时提供（❄️ 冻结）。

/// 榜单 / 列表分类。搜索不是独立来源，只是同一 Wenku8 数据源上的查询。
enum Wenku8FeedKind { recommendation, recent, ranking, completed, search }

class Wenku8FeedLabels {
  const Wenku8FeedLabels._();

  static const Map<Wenku8FeedKind, String> labels = <Wenku8FeedKind, String>{
    Wenku8FeedKind.recommendation: '推荐',
    Wenku8FeedKind.recent: '最近更新',
    Wenku8FeedKind.ranking: '排行榜',
    Wenku8FeedKind.completed: '已完结',
    Wenku8FeedKind.search: '搜索结果',
  };

  static const Map<Wenku8FeedKind, String> hints = <Wenku8FeedKind, String>{
    Wenku8FeedKind.recommendation: 'Wenku8 公开目录',
    Wenku8FeedKind.recent: '按更新时间排列',
    Wenku8FeedKind.ranking: '按热度排列',
    Wenku8FeedKind.completed: '全本目录',
    Wenku8FeedKind.search: '仅匹配标题与作者',
  };
}

@immutable
class Wenku8Chapter {
  const Wenku8Chapter({
    required this.index,
    required this.title,
    required this.volumeIndex,
    this.chapterId = '',
  });

  final int index;
  final String title;
  final int volumeIndex;

  /// 真实接入时的站点章节 id；演示数据留空（第二十三轮）。
  final String chapterId;
}

@immutable
class Wenku8Volume {
  const Wenku8Volume({
    required this.index,
    required this.title,
    required this.chapters,
  });

  final int index;
  final String title;
  final List<Wenku8Chapter> chapters;

  int get chapterCount => chapters.length;
}

@immutable
class Wenku8Book {
  const Wenku8Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverColor,
    required this.tags,
    required this.latestChapter,
    required this.updatedKey,
    this.volumeCount = 1,
    this.withdrawn = false,
  });

  final String id;
  final String title;
  final String author;
  final Color coverColor;
  final List<String> tags;
  final String latestChapter;
  final String updatedKey;
  final int volumeCount;

  /// 因版权原因下架的内容不展示、不提供访问（参考仓库 README 明确口径）。
  final bool withdrawn;

  bool get isAvailable => !withdrawn;
}

@immutable
class Wenku8Detail {
  const Wenku8Detail({
    required this.book,
    required this.synopsis,
    required this.volumes,
  });

  final Wenku8Book book;
  final String synopsis;
  final List<Wenku8Volume> volumes;

  int get chapterCount =>
      volumes.fold<int>(0, (int n, Wenku8Volume v) => n + v.chapterCount);
}

/// 单章正文读取结果（第二十三轮）。
///
/// 只承载用户显式点开的**一章**，不拼接整本、不缓存分发、不导出。
/// 失败时 `status` 明确区分限流 / 不可用 / 结构变化 / 版权受限。
@immutable
class Wenku8ChapterText {
  const Wenku8ChapterText({
    required this.bookId,
    required this.chapterId,
    required this.title,
    required this.text,
    this.status = Wenku8Status.ok,
    this.note = '',
  });

  factory Wenku8ChapterText.failed(
    String bookId,
    String chapterId,
    Wenku8Status status,
    String note,
  ) =>
      Wenku8ChapterText(
        bookId: bookId,
        chapterId: chapterId,
        title: '',
        text: '',
        status: status,
        note: note,
      );

  final String bookId;
  final String chapterId;
  final String title;
  final String text;
  final Wenku8Status status;
  final String note;

  bool get isReadable => status == Wenku8Status.ok && text.isNotEmpty;
}

@immutable
class Wenku8Listing {
  const Wenku8Listing({
    required this.feed,
    required this.books,
    required this.status,
    this.note = '',
  });

  final Wenku8FeedKind feed;
  final List<Wenku8Book> books;
  final Wenku8Status status;
  final String note;

  bool get hasBooks => books.isNotEmpty;
}
