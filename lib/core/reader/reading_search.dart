import 'package:flutter/foundation.dart';

import '../models/book_document.dart';

/// 章内 / 全书搜索（第二十四轮）。
///
/// 参考仓库 README：「in-chapter and whole-book search」。静态阶段只做**命中
/// 模型与聚合**：给定 `BookDocument` 的内容块，算出块号 / 行号 / 页码预览；
/// 真正的页码由分页引擎在 `EffectiveReaderStyle` 下算出（❄️ 冻结），
/// 所以命中里带 `blockIndex` 而不硬编码 pageIndex，避免字号一变结果全错。
enum ReadingSearchScope { chapter, book }

@immutable
class ReadingSearchHit {
  const ReadingSearchHit({
    required this.chapterIndex,
    required this.blockIndex,
    required this.snippet,
    required this.matchStart,
  });

  final int chapterIndex;
  final int blockIndex;
  final String snippet;
  final int matchStart;

  /// 跳章跳页的唯一坐标：章号 + 块号，页码交给分页层现算。
  String get anchor => 'c$chapterIndex-b$blockIndex';
}

@immutable
class ReadingSearchResult {
  const ReadingSearchResult({
    required this.query,
    required this.scope,
    required this.hits,
  });

  final String query;
  final ReadingSearchScope scope;
  final List<ReadingSearchHit> hits;

  bool get isEmpty => hits.isEmpty;
  int get count => hits.length;

  Map<int, int> get byChapter {
    final Map<int, int> out = <int, int>{};
    for (final ReadingSearchHit h in hits) {
      out[h.chapterIndex] = (out[h.chapterIndex] ?? 0) + 1;
    }
    return Map<int, int>.unmodifiable(out);
  }
}

/// 搜索器：空词返回空结果（不把整章误报成全命中），大小写不敏感，
/// 片段保留上下文而不是只给命中词，便于面板直接渲染。
class ReadingSearch {
  const ReadingSearch._();

  static ReadingSearchResult search(
    BookDocument doc,
    String rawQuery, {
    ReadingSearchScope scope = ReadingSearchScope.chapter,
    int chapterIndex = 0,
    int contextChars = 18,
  }) {
    final String query = rawQuery.trim();
    if (query.isEmpty || doc.chapters.isEmpty) {
      return ReadingSearchResult(
        query: query,
        scope: scope,
        hits: const <ReadingSearchHit>[],
      );
    }
    final String needle = query.toLowerCase();
    final List<ReadingSearchHit> hits = <ReadingSearchHit>[];
    final List<int> chapterIndexes = scope == ReadingSearchScope.chapter
        ? <int>[chapterIndex.clamp(0, doc.chapters.length - 1)]
        : List<int>.generate(doc.chapters.length, (int i) => i);

    for (final int ci in chapterIndexes) {
      final Chapter chapter = doc.chapters[ci];
      for (int bi = 0; bi < chapter.blocks.length; bi++) {
        final ContentBlock block = chapter.blocks[bi];
        final String text = block.text;
        final String lower = text.toLowerCase();
        int from = 0;
        while (true) {
          final int at = lower.indexOf(needle, from);
          if (at < 0) break;
          final int start = at - contextChars < 0 ? 0 : at - contextChars;
          final int end = at + query.length + contextChars > text.length
              ? text.length
              : at + query.length + contextChars;
          hits.add(ReadingSearchHit(
            chapterIndex: ci,
            blockIndex: bi,
            snippet: text.substring(start, end),
            matchStart: at - start,
          ));
          from = at + query.length;
        }
      }
    }
    return ReadingSearchResult(
      query: query,
      scope: scope,
      hits: List<ReadingSearchHit>.unmodifiable(hits),
    );
  }
}
