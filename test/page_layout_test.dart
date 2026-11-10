import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/layout/line_break_rules.dart';
import 'package:local_reader/core/layout/page_layout.dart';
import 'package:local_reader/core/layout/pagination_isolate.dart';
import 'package:local_reader/core/models/book_document.dart';

/// 固定宽度测量器：每个 code unit 宽 10，CJK 与 ASCII 一致，便于精确推算页容量。
class FakeMeasurer implements TextMeasurer {
  const FakeMeasurer([this.width = 10]);
  final double width;

  @override
  double measure(String text, TextStyle style) => text.codeUnits.length * width;
}

PaginationConfig config({
  double width = 100,
  double height = 100,
  double fontSize = 10,
  int orphan = 2,
  int widow = 2,
}) =>
    PaginationConfig(
      pageSize: Size(width, height),
      textStyle: TextStyle(fontSize: fontSize, height: 1.0),
      firstLineIndentEm: 2,
      lineHeight: 1.0,
      paragraphSpacing: 0,
      orphanLines: orphan,
      widowLines: widow,
    );

Chapter chapterOf(List<ContentBlock> blocks) =>
    Chapter(id: 'c0', title: '测试', blocks: blocks);

void main() {
  const PaginationEngine engine = PaginationEngine(measurer: FakeMeasurer());

  group('首行缩进与跨页续块', () {
    test('段落首行缩进 2em，其余行 indent 为 0', () {
      final Chapter c = chapterOf(<ContentBlock>[
        const ContentBlock(
            kind: BlockKind.paragraph,
            text: '一二三四五六七八九十' * 3
        ),
      ]);
      final PaginationResult r = engine.layout(c, config(width: 100, height: 1000));

      final List<LaidOutLine> lines = r.pages.first.lines;
      expect(lines.length, greaterThan(1));
      expect(lines.first.indent, 20); // fontSize 10 × 2em
      for (final LaidOutLine l in lines.skip(1)) {
        expect(l.indent, 0, reason: '续行不得重复缩进');
      }
    });

    test('超长段落被拆到下一页时，第二页首行仍不缩进', () {
      final Chapter c = chapterOf(<ContentBlock>[
        const ContentBlock(kind: BlockKind.paragraph, text: '书页翻过去的时候' * 20),
      ]);
      // 每行 10 字，页高 50 → 每页 5 行
      final PaginationResult r = engine.layout(c, config(width: 100, height: 50));
      expect(r.pages.length, greaterThan(1));

      final LaidOutLine secondPageFirstLine = r.pages[1].lines.first;
      expect(secondPageFirstLine.lineInBlock, greaterThan(0));
      expect(secondPageFirstLine.indent, 0, reason: '跨页续块不重复缩进');
    });

    test('标题不参与首行缩进', () {
      final Chapter c = chapterOf(<ContentBlock>[
        const ContentBlock(kind: BlockKind.heading, text: '第一章', level: 1),
      ]);
      final PaginationResult r = engine.layout(c, config());
      expect(r.pages.first.lines.first.indent, 0);
    });
  });

  group('孤儿行 / widow / keepWithNext', () {
    test('超长段最后一页至少留 orphanLines 行', () {
      const int orphan = 2;
      final Chapter c = chapterOf(<ContentBlock>[
        const ContentBlock(kind: BlockKind.paragraph, text: '甲乙丙丁戊己庚辛壬癸' * 10),
      ]);
      final PaginationResult r = engine.layout(c, config(height: 50, orphan: orphan));
      expect(r.pages.length, greaterThan(1));
      expect(r.pages.last.lines.length, greaterThanOrEqualTo(orphan));
    });

    test('keepWithNext 标题与正文合并，不单独挂在页底', () {
      final Chapter c = chapterOf(<ContentBlock>[
        const ContentBlock(kind: BlockKind.heading, text: '第一章', level: 1, keepWithNext: true),
        const ContentBlock(kind: BlockKind.paragraph, text: '一二三四五六七八九十'),
      ]);
      // 页高 15 → 只能容 1 行；合并后 2 行放不下，整体推到新页
      final PaginationResult r = engine.layout(c, config(height: 15));
      expect(r.pages.first.lines.length, 2, reason: '标题与正文应作为不可拆单元同页');
    });

    test('显式分页符强制换页', () {
      final Chapter c = chapterOf(<ContentBlock>[
        const ContentBlock(kind: BlockKind.paragraph, text: '甲'),
        const ContentBlock(kind: BlockKind.pageBreak),
        const ContentBlock(kind: BlockKind.paragraph, text: '乙'),
      ]);
      final PaginationResult r = engine.layout(c, config(height: 100));
      expect(r.pages.length, 2);
      expect(r.pages.first.lines.single.text, '甲');
      expect(r.pages.last.lines.single.text, '乙');
    });
  });

  group('中文标点避头尾', () {
    test('行首禁则标点回退一字', () {
      const String s = '甲乙，丙丁';
      // 假设断行点落在 '，' 前（index=2），下一行行首会是禁则标点
      expect(LineBreakRules.isNoLineStart(s.codeUnitAt(2)), isTrue);
      expect(LineBreakRules.adjustEnd(s, 0, 2), 1);
    });

    test('行末禁则开符号被带到下一行', () {
      const String s = '甲乙（丙丁';
      // end=3 时本行末字是 '（'，应回退到 2
      expect(LineBreakRules.isNoLineEnd(s.codeUnitAt(2)), isTrue);
      expect(LineBreakRules.adjustEnd(s, 0, 3), 2);
    });

    test('adjustEnd 恒大于 start，不会让分页死循环', () {
      expect(LineBreakRules.adjustEnd('，', 0, 1), 1);
      expect(LineBreakRules.adjustEnd('甲，', 0, 1), 1);
    });
  });

  group('isolate 边界', () {
    test('PaginationRequest 可在 compute 里产出页数', () {
      final PaginationRequest req = PaginationRequest(
        chapterId: 'c0',
        blocks: <BlockDto>[
          BlockDto.from(const ContentBlock(kind: BlockKind.paragraph, text: '一二三四五六七八九十' * 6)),
        ],
        pageWidth: 100,
        pageHeight: 50,
        fontSize: 10,
        fontFamily: null,
        lineHeight: 1.0,
        firstLineIndentEm: 2,
        paragraphSpacing: 0,
        orphanLines: 2,
        widowLines: 2,
      );
      final PaginationReply reply = paginationEntry(req);
      expect(reply.measuredExactly, isFalse, reason: '后台 isolate 使用 FallbackMeasurer');
      expect(reply.pages, isNotEmpty);
      expect(reply.chapterId, 'c0');
    });

    test('FallbackMeasurer 对 CJK 与 ASCII 的估宽可复现', () {
      const FallbackMeasurer m = FallbackMeasurer(10);
      expect(m.measure('中文', const TextStyle()), 20);
      expect(m.measure('ab', const TextStyle()), 10);
    });
  });

  group('PageAnchor', () {
    test('空结果返回零锚点，不越界', () {
      const PaginationResult r = PaginationResult(
        chapterId: 'c0',
        pages: <LaidOutPage>[],
        config: PaginationConfig(pageSize: Size(100, 100), textStyle: TextStyle()),
      );
      expect(r.anchorFor(0).pageIndex, 0);
      expect(r.anchorFor(99).pageIndex, 0);
    });
  });
}
