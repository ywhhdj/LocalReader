import 'dart:typed_data';

import '../models/book_document.dart';
import 'charset_bridge.dart';

/// 纯 Dart 解析可重排文本。章节切分与段落规整是 LocalReader 原有能力，直接平移。
class TextBookParser {
  const TextBookParser({required this.charset});

  final CharsetBridge charset;

  /// 中文卷章 / Chapter N / 卷 N / 序章楔子番外。
  static final RegExp _chapterRe = RegExp(
    r'^\s*(?:'
    r'第\s*[零〇一二三四五六七八九十百千两\d]+\s*[章卷回部篇集节](?:\s*[^\n]{0,40})?'
    r'|[Cc]hapter\s+\d+(?:\s*[^\n]{0,40})?'
    r'|卷\s*\d+(?:\s*[^\n]{0,40})?'
    r'|序章|楔子|尾声|后记|番外(?:[^\n]{0,20})?'
    r')\s*$',
    multiLine: true,
  );

  Future<BookDocument> parse(
    String path,
    Uint8List bytes, {
    required String id,
    required String title,
    String author = '',
    bool markdown = false,
  }) async {
    final DecodedText decoded = await charset.decode(bytes);
    final List<Chapter> chapters = _splitChapters(decoded.content, markdown: markdown);

    return BookDocument(
      id: id,
      title: title,
      author: author,
      chapters: chapters,
      sourcePath: path,
      sourceFormat: markdown ? SourceFormat.markdown : SourceFormat.txt,
      encoding: decoded.encoding.name,
      toc: <TocEntry>[
        for (int i = 0; i < chapters.length; i++)
          TocEntry(label: chapters[i].title, chapterIndex: i, blockIndex: 0),
      ],
    );
  }

  List<Chapter> _splitChapters(String text, {required bool markdown}) {
    final String normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final List<RegExpMatch> matches = _chapterRe.allMatches(normalized).toList();

    if (matches.isEmpty) {
      return <Chapter>[
        Chapter(id: 'c0', title: '正文', blocks: _toBlocks(normalized, markdown: markdown)),
      ];
    }

    final List<Chapter> chapters = <Chapter>[];
    // 卷首前言单独成章，避免被吞掉
    if (matches.first.start > 0) {
      final String preface = normalized.substring(0, matches.first.start).trim();
      if (preface.isNotEmpty) {
        chapters.add(Chapter(id: 'c0', title: '前言', blocks: _toBlocks(preface, markdown: markdown)));
      }
    }

    for (int i = 0; i < matches.length; i++) {
      final int start = matches[i].start;
      final int end = i + 1 < matches.length ? matches[i + 1].start : normalized.length;
      final String body = normalized.substring(start, end);
      final String heading = matches[i].group(0)?.trim() ?? '第 ${i + 1} 章';
      final String rest = body.substring(matches[i].group(0)?.length ?? 0);

      chapters.add(Chapter(
        id: 'c${chapters.length}',
        title: heading,
        ordinal: chapters.length,
        blocks: <ContentBlock>[
          ContentBlock(kind: BlockKind.heading, text: heading, level: 1, keepWithNext: true),
          ..._toBlocks(rest, markdown: markdown),
        ],
      ));
    }
    return chapters;
  }

  List<ContentBlock> _toBlocks(String raw, {required bool markdown}) {
    final List<ContentBlock> blocks = <ContentBlock>[];
    for (final String line in raw.split('\n')) {
      final String s = line.trim();
      if (s.isEmpty) continue;

      if (markdown) {
        final int hashes = _leadingHashes(s);
        if (hashes > 0) {
          blocks.add(ContentBlock(
            kind: BlockKind.heading,
            text: s.substring(hashes).trim(),
            level: hashes,
            keepWithNext: true,
          ));
          continue;
        }
        if (s.startsWith('>')) {
          blocks.add(ContentBlock(kind: BlockKind.quote, text: s.substring(1).trim()));
          continue;
        }
        if (s == '---' || s == '***') {
          blocks.add(const ContentBlock(kind: BlockKind.pageBreak));
          continue;
        }
      }
      blocks.add(ContentBlock(kind: BlockKind.paragraph, text: s));
    }
    return blocks;
  }

  int _leadingHashes(String s) {
    int n = 0;
    while (n < s.length && n < 6 && s.codeUnitAt(n) == 0x23) {
      n++;
    }
    return n;
  }
}
