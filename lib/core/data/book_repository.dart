import 'package:flutter/material.dart';

/// 书架演示数据从页面里抽出来，四 tab 共享同一份真相。
/// 未来接 Drift/Isar 时替换实现，页面不需要改。
@immutable
class BookSummary {
  const BookSummary({
    required this.id,
    required this.title,
    required this.author,
    required this.spineColor,
    required this.shelf,
    this.progress = 0,
    this.format = 'TXT',
    this.encoding = 'UTF-8',
    this.volumeOrder = 0,
  });

  final String id;
  final String title;
  final String author;
  final Color spineColor;
  final String shelf;
  final double progress;
  final String format;
  final String encoding;

  /// 卷序：对应参考仓库「编辑卷顺序」。0 表示未分卷。
  final int volumeOrder;

  static const Set<String> comicFormats = <String>{
    'CBZ', 'CBR', 'ZIP', 'RAR', '漫画', 'IMAGEFOLDER',
  };

  /// 漫画 → 竖向阅读 + 分话目录；PDF 虽也走原生栅格化，但不是漫画。
  bool get isComic => comicFormats.contains(format.toUpperCase());

  BookSummary copyWith({
    String? title,
    String? author,
    Color? spineColor,
    String? shelf,
    double? progress,
    String? format,
    String? encoding,
    int? volumeOrder,
  }) =>
      BookSummary(
        id: id,
        title: title ?? this.title,
        author: author ?? this.author,
        spineColor: spineColor ?? this.spineColor,
        shelf: shelf ?? this.shelf,
        progress: progress ?? this.progress,
        format: format ?? this.format,
        encoding: encoding ?? this.encoding,
        volumeOrder: volumeOrder ?? this.volumeOrder,
      );
}

abstract interface class BookRepository {
  /// 同步缓存：静态演示 / 首屏即刻渲染用。
  List<BookSummary> get cached;

  /// 真实实现在这里异步刷新书库（文件扫描 → 解析 → 落库）。
  Future<List<BookSummary>> refresh();

  Future<List<BookSummary>> search(String query);

  BookSummary? byId(String id);

  /// 按分组取书，书架页按层板渲染用。
  List<BookSummary> byShelf(String shelf);
}

class DemoBookRepository implements BookRepository {
  const DemoBookRepository();

  static const List<BookSummary> _sample = <BookSummary>[
    BookSummary(id: 'b01', title: '雪国的旅行者', author: '川端 雪', spineColor: Color(0xFF4A6180), shelf: '最近阅读', progress: 0.62),
    BookSummary(id: 'b02', title: '春樱手账', author: '林 未央', spineColor: Color(0xFFB4677C), shelf: '最近阅读', progress: 0.18),
    BookSummary(id: 'b03', title: '夏汐来信', author: '江 潮生', spineColor: Color(0xFF3F8079), shelf: '最近阅读'),
    BookSummary(id: 'b04', title: '秋笺拾遗', author: '沈 砚', spineColor: Color(0xFFA96433), shelf: '最近阅读', progress: 0.91),
    BookSummary(id: 'b05', title: '冬寂图书馆', author: '白 鹭', spineColor: Color(0xFF6B7A94), shelf: '最近阅读', progress: 0.35),
    BookSummary(id: 'b06', title: '纸白纪事', author: '苏 禾', spineColor: Color(0xFF8A6A4F), shelf: '最近阅读'),
    BookSummary(id: 'b07', title: '星屑与旧钟', author: '夜 航', spineColor: Color(0xFF5A5F8C), shelf: '本地书库', progress: 0.44),
    BookSummary(id: 'b08', title: '玻璃庭院', author: '温 瓷', spineColor: Color(0xFF6E8B7B), shelf: '本地书库'),
    BookSummary(id: 'b09', title: '山雀通信', author: '谷 雨', spineColor: Color(0xFF9A6B4F), shelf: '本地书库', progress: 0.73),
    BookSummary(id: 'b10', title: '海边的目录', author: '陆 屿', spineColor: Color(0xFF3F6F86), shelf: '本地书库'),
    BookSummary(id: 'b11', title: '雨街漫画志', author: '青 岚', spineColor: Color(0xFF6B6F8C), shelf: '本地书库', format: 'CBZ', progress: 0.28),
  ];

  static const List<String> shelfTitles = <String>['最近阅读', '本地书库'];

  @override
  List<BookSummary> get cached => List<BookSummary>.unmodifiable(_sample);

  @override
  Future<List<BookSummary>> refresh() async => cached;

  @override
  Future<List<BookSummary>> search(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return cached;
    return List<BookSummary>.unmodifiable(
      _sample.where((BookSummary b) => b.title.contains(q) || b.author.contains(q)),
    );
  }

  @override
  BookSummary? byId(String id) {
    for (final BookSummary b in _sample) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  List<BookSummary> byShelf(String shelf) =>
      List<BookSummary>.unmodifiable(_sample.where((BookSummary b) => b.shelf == shelf));
}
