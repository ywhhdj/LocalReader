import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/stats/excerpt_capture.dart';
import 'package:local_reader/core/stats/line_anchor_resolver.dart';
import 'package:local_reader/core/stats/reading_stats.dart';

LineRef ref(
  int block,
  int line,
  String text, {
  int chapter = 1,
  int page = 0,
  String book = 'b01',
}) =>
    LineRef(
      bookId: book,
      chapterIndex: chapter,
      pageIndex: page,
      blockIndex: block,
      lineInBlock: line,
      text: text,
    );

Excerpt ex(
  String id,
  LineRef? origin, {
  String book = 'b01',
  int chapter = 1,
  HighlightColor color = HighlightColor.amber,
  String text = '一句摘录',
}) =>
    Excerpt(
      id: id,
      bookId: book,
      bookTitle: '演示书名',
      chapterTitle: '第一章',
      text: text,
      capturedAt: DateTime.utc(2026, 11, 9),
      chapterIndex: chapter,
      origin: origin,
      highlight: color,
    );

void main() {
  group('置信度词表', () {
    test('五档都有标签与是否自动高亮的裁决', () {
      expect(AnchorConfidence.values.length, 5);
      expect(AnchorConfidenceLabels.labels.length, 5);
      expect(AnchorConfidenceLabels.shouldHighlight.length, 5);
      expect(AnchorConfidenceLabels.shouldHighlight[AnchorConfidence.ambiguous],
          isFalse);
      expect(AnchorConfidenceLabels.shouldHighlight[AnchorConfidence.none],
          isFalse);
      for (final AnchorConfidence c in <AnchorConfidence>[
        AnchorConfidence.exact,
        AnchorConfidence.structural,
        AnchorConfidence.textUnique,
      ]) {
        expect(AnchorConfidenceLabels.shouldHighlight[c], isTrue);
      }
    });

    test('LineAnchorMatch 值语义与 note', () {
      const LineAnchorMatch a = LineAnchorMatch(
        excerptId: 'e1', highlight: HighlightColor.rose,
        confidence: AnchorConfidence.exact, candidateCount: 1,
      );
      expect(a.shouldHighlight, isTrue);
      expect(a.note, '精确还原');
      expect(a, const LineAnchorMatch(
        excerptId: 'e1', highlight: HighlightColor.rose,
        confidence: AnchorConfidence.exact, candidateCount: 1,
      ));
    });
  });

  group('索引构造', () {
    test('只收带 origin 的摘录，演示种子被跳过', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('seed', null),
        ex('e1', ref(2, 0, '雪落在纸上')),
      ]);
      expect(r.anchorCount, 1);
    });

    test('scopeKey 是 bookId + chapter，不同书 / 不同章不串', () {
      expect(LineAnchorResolver.scopeKeyOf(ref(0, 0, 'x', book: 'b02')), 'b02|1');
      expect(LineAnchorResolver.scopeKeyOf(ref(0, 0, 'x', chapter: 3)), 'b01|3');
    });
  });

  group('① exact：位置 + 文本全等', () {
    test('精确还原，页码漂移不影响', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '雪落在纸上'), color: HighlightColor.rose),
      ]);
      final LineAnchorMatch? m = r.resolve(ref(2, 0, '雪落在纸上', page: 9));
      expect(m, isNotNull);
      expect(m!.confidence, AnchorConfidence.exact);
      expect(m.shouldHighlight, isTrue);
      expect(m.highlight, HighlightColor.rose);
      expect(m.excerptId, 'e1');
      expect(m.candidateCount, 1);
    });

    test('带首尾空白的文本按 trim 归一', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '  雪落在纸上  ')),
      ]);
      expect(r.resolve(ref(2, 0, '雪落在纸上'))?.confidence, AnchorConfidence.exact);
    });
  });

  group('② structural：位置相同、文字已变', () {
    test('仍自动高亮，但置信度标明「文字已变」', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '旧版文字')),
      ]);
      final LineAnchorMatch? m = r.resolve(ref(2, 0, '新版文字'));
      expect(m!.confidence, AnchorConfidence.structural);
      expect(m.shouldHighlight, isTrue);
      expect(m.note, contains('文字已变'));
    });

    test('优先级低于 exact：同一位置另有文本全等的锚点时取 exact', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '旧版文字')),
        ex('e2', ref(2, 0, '新版文字')),
      ]);
      final LineAnchorMatch? m = r.resolve(ref(2, 0, '新版文字'));
      expect(m!.confidence, AnchorConfidence.exact);
      expect(m.excerptId, 'e2');
    });
  });

  group('③ textUnique：重排后行号漂移，按本章文本唯一还原', () {
    test('块号 / 行号都变了仍能还原', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '雪落在纸上'), color: HighlightColor.sage),
      ]);
      final LineAnchorMatch? m = r.resolve(ref(7, 4, '雪落在纸上'));
      expect(m!.confidence, AnchorConfidence.textUnique);
      expect(m.shouldHighlight, isTrue);
      expect(m.highlight, HighlightColor.sage);
      expect(m.note, contains('按文本还原'));
    });

    test('页码变了不影响（pageIndex 永不参与身份）', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '雪落在纸上', page: 0)),
      ]);
      expect(r.resolve(ref(7, 4, '雪落在纸上', page: 12))?.confidence,
          AnchorConfidence.textUnique);
    });

    test('不同章的同名文本不跨章命中', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '雪落在纸上', chapter: 1)),
      ]);
      expect(r.resolve(ref(7, 4, '雪落在纸上', chapter: 2)), isNull);
    });

    test('不同书的同名文本不跨书命中', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '雪落在纸上', book: 'b01')),
      ]);
      expect(r.resolve(ref(7, 4, '雪落在纸上', book: 'b02')), isNull);
    });
  });

  group('④ ambiguous：多处相同文本 / 多个锚点抢同一位置', () {
    test('两条摘录引用同一句文本 → 不自动高亮', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '雪落在纸上')),
        ex('e2', ref(5, 1, '雪落在纸上')),
      ]);
      final LineAnchorMatch? m = r.resolve(ref(9, 3, '雪落在纸上'));
      expect(m!.confidence, AnchorConfidence.ambiguous);
      expect(m.shouldHighlight, isFalse);
      expect(m.candidateCount, 2);
      expect(m.note, contains('待确认'));
    });

    test('两条摘录锚在同一位置但文本都不同 → ambiguous', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '甲句')),
        ex('e2', ref(2, 0, '乙句')),
      ]);
      final LineAnchorMatch? m = r.resolve(ref(2, 0, '丙句'));
      expect(m!.confidence, AnchorConfidence.ambiguous);
      expect(m.shouldHighlight, isFalse);
    });

    test('同一条摘录的多个锚点命中同一文本不算歧义（未来多行锚点）', () {
      // 当前 Excerpt 只有一个 origin，这里用两条**同 id** 的摘录模拟多行锚点，
      // 验证 _pick 按 excerptId 去重而不是按候选数量粗暴判歧义。
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '雪落在纸上')),
        ex('e1', ref(3, 0, '雪落在纸上')),
      ]);
      final LineAnchorMatch? m = r.resolve(ref(9, 3, '雪落在纸上'));
      expect(m!.confidence, AnchorConfidence.textUnique,
          reason: '同一条摘录的多行锚点不应互相打架');
      expect(m.shouldHighlight, isTrue);
    });
  });

  group('⑤ 无匹配', () {
    test('完全没有候选锚点返回 null', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '雪落在纸上')),
      ]);
      expect(r.resolve(ref(2, 0, '完全不同的一句')), isNull);
    });

    test('空摘录列表返回 null', () {
      expect(LineAnchorResolver.from(<Excerpt>[]).resolve(ref(0, 0, 'x')), isNull);
    });

    test('无 origin 的摘录不产生任何匹配', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[ex('seed', null)]);
      expect(r.anchorCount, 0);
      expect(r.resolve(ref(0, 0, '一句摘录')), isNull);
    });
  });

  group('resolveLines 批量还原', () {
    test('保持顺序，未命中的位置为 null', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '甲句')),
      ]);
      final List<LineAnchorMatch?> out = r.resolveLines(<LineRef>[
        ref(2, 0, '甲句'),
        ref(2, 1, '乙句'),
        ref(8, 0, '甲句'),
      ]);
      expect(out.length, 3);
      expect(out[0]?.confidence, AnchorConfidence.exact);
      expect(out[1], isNull);
      expect(out[2]?.confidence, AnchorConfidence.textUnique);
      expect(() => out.add(null), throwsUnsupportedError);
    });
  });

  group('静态边界口径', () {
    test('跨段落摘录只还原首行：模型只索引每条摘录的一个 origin', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '第一段'), color: HighlightColor.blue),
      ]);
      expect(r.anchorCount, 1);
      expect(r.resolve(ref(2, 1, '第二段')), isNull);
    });

    test('歧义显式不自动高亮，页面不会画错位置', () {
      final LineAnchorResolver r = LineAnchorResolver.from(<Excerpt>[
        ex('e1', ref(2, 0, '重复句')),
        ex('e2', ref(4, 0, '重复句')),
      ]);
      final LineAnchorMatch m = r.resolve(ref(2, 0, '重复句'))!;
      expect(m.shouldHighlight, isFalse);
    });
  });
}
