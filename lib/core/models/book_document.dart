import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../comic/comic_toc.dart';

/// 统一内容模型：解析层的唯一出口。
/// 无论 TXT / EPUB / FB2 / Markdown 还是原生栅格化格式，都先收敛成这个结构，
/// 排版引擎只认 ContentBlock，不认文件格式。
enum BlockKind { paragraph, heading, quote, image, pageBreak }

@immutable
class ContentBlock {
  const ContentBlock({
    required this.kind,
    this.text = '',
    this.assetPath,
    this.level = 0,
    this.keepWithNext = false,
  });

  final BlockKind kind;
  final String text;
  final String? assetPath;
  final int level;
  final bool keepWithNext;

  bool get isImage => kind == BlockKind.image;
  bool get isPageBreak => kind == BlockKind.pageBreak;
}

@immutable
class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.blocks,
    this.ordinal = 0,
  });

  final String id;
  final String title;
  final List<ContentBlock> blocks;
  final int ordinal;
}

@immutable
class TocEntry {
  const TocEntry({required this.label, required this.chapterIndex, required this.blockIndex});

  final String label;
  final int chapterIndex;
  final int blockIndex;
}

enum SourceFormat { txt, epub, markdown, fb2, rtf, docx, pdf, cbz, cbr, imageFolder, unknown }

@immutable
class BookDocument {
  const BookDocument({
    required this.id,
    required this.title,
    required this.author,
    required this.chapters,
    required this.sourcePath,
    required this.sourceFormat,
    this.coverBytes,
    this.toc = const <TocEntry>[],
    this.requiresNativeRender = false,
    this.encoding,
    this.comicToc,
  });

  final String id;
  final String title;
  final String author;
  final List<Chapter> chapters;
  final String sourcePath;
  final SourceFormat sourceFormat;
  final Uint8List? coverBytes;
  final List<TocEntry> toc;

  /// true = 正文不能重排（PDF / 图片型 EPUB / 漫画），交给 BookRenderBridge 出页。
  final bool requiresNativeRender;
  final String? encoding;

  /// 仅漫画类文档挂载：分话目录 + 重排后的页序。
  /// PDF 也是 nativeRaster，但 comicToc == null，所以走 PDF 占位而不是漫画竖向阅读。
  final ComicToc? comicToc;

  bool get isComic => requiresNativeRender && comicToc != null && !comicToc!.isEmpty;
  int get comicPageCount => comicToc?.pageCount ?? 0;

  int get blockCount => chapters.fold<int>(0, (int sum, Chapter c) => sum + c.blocks.length);
}

@immutable
class PageAnchor {
  const PageAnchor({
    required this.chapterIndex,
    required this.pageIndex,
    required this.blockIndex,
    required this.lineIndex,
    required this.charOffset,
  });

  final int chapterIndex;
  final int pageIndex;
  final int blockIndex;
  final int lineIndex;
  final int charOffset;
}

@immutable
class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.chapterIndex,
    required this.pageIndex,
    required this.pageOffset,
    required this.updatedAt,
  });

  final String bookId;
  final int chapterIndex;

  /// 由分页引擎生成的页序号；窗口尺寸变化会重排，所以必须同时存 anchor。
  final int pageIndex;

  /// 页内位置 0..1，对应原项目「进度采样含页内位置」。
  final double pageOffset;
  final DateTime updatedAt;

  ReadingProgress copyWith({int? pageIndex, double? pageOffset, DateTime? updatedAt}) => ReadingProgress(
        bookId: bookId,
        chapterIndex: chapterIndex,
        pageIndex: pageIndex ?? this.pageIndex,
        pageOffset: pageOffset ?? this.pageOffset,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
