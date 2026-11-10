import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/data/book_repository.dart';
import 'package:local_reader/core/state/app_scope.dart';
import 'package:local_reader/core/state/app_settings.dart';
import 'package:local_reader/core/stats/excerpt_capture.dart';
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

SelectionDraft draft(List<LineRef> refs, {int chapter = 1, int page = 0}) {
  SelectionDraft d =
      SelectionDraft(bookId: 'b01', chapterIndex: chapter, pageIndex: page);
  for (final LineRef r in refs) {
    d = d.toggle(r);
  }
  return d;
}

void main() {
  group('行锚点 LineRef', () {
    test('身份不含 pageIndex：重排后页码漂移仍能匹配', () {
      final LineRef a = ref(3, 1, '雪落在纸上', page: 0);
      final LineRef b = ref(3, 1, '雪落在纸上', page: 7);
      expect(a.matches(b), isTrue);
      expect(a == b, isFalse, reason: '对象相等仍保留页码，但业务匹配忽略它');
    });

    test('章节 / 块 / 行不同则不匹配', () {
      expect(ref(3, 1, 'x').matches(ref(3, 2, 'x')), isFalse);
      expect(ref(3, 1, 'x').matches(ref(4, 1, 'x')), isFalse);
      expect(ref(3, 1, 'x').matches(ref(3, 1, 'x', chapter: 2)), isFalse);
    });

    test('文本兜底匹配忽略空白，但要求同书同章', () {
      final LineRef a = ref(3, 1, '  雪落在纸上  ');
      expect(a.matchesByText(ref(9, 9, '雪落在纸上')), isTrue);
      expect(a.matchesByText(ref(9, 9, '雪落在纸上', chapter: 2)), isFalse);
      expect(a.matchesByText(ref(9, 9, '别的句子')), isFalse);
    });
  });

  group('选区 SelectionDraft', () {
    test('toggle 加选 / 取消，不修改原对象', () {
      final SelectionDraft empty = draft(<LineRef>[]);
      final SelectionDraft one = empty.toggle(ref(1, 0, '第一行'));
      expect(empty.isEmpty, isTrue);
      expect(one.count, 1);
      expect(one.toggle(ref(1, 0, '第一行')).isEmpty, isTrue);
    });

    test('倒着点选也能拼成通顺顺序', () {
      final SelectionDraft d = draft(<LineRef>[
        ref(2, 1, '第三行'),
        ref(1, 0, '第一行'),
        ref(1, 1, '第二行'),
      ]);
      expect(d.normalizedText(), '第一行第二行第三行');
    });

    test('clear 保留章节与页码；switchTo 换页换章清空选区', () {
      final SelectionDraft d =
          draft(<LineRef>[ref(1, 0, '第一行')], chapter: 2, page: 3);
      final SelectionDraft cleared = d.clear();
      expect(cleared.isEmpty, isTrue);
      expect(cleared.chapterIndex, 2);
      expect(cleared.pageIndex, 3);

      final SelectionDraft moved = d.switchTo(chapterIndex: 5, pageIndex: 0);
      expect(moved.isEmpty, isTrue);
      expect(moved.chapterIndex, 5);
      expect(moved.pageIndex, 0);
    });

    test('归一化丢掉空行与纯标点行', () {
      final SelectionDraft d = draft(<LineRef>[
        ref(1, 0, '  「书页翻过去的时候，'),
        ref(1, 1, '   ......   '),
        ref(1, 2, '  屋里只剩下一小片安静。」  '),
      ]);
      expect(d.normalizedText(), '「书页翻过去的时候，屋里只剩下一小片安静。」');
    });

    test('连续性与跨段落判定', () {
      expect(draft(<LineRef>[ref(1, 0, 'a'), ref(1, 1, 'b')]).isContiguous,
          isTrue);
      expect(draft(<LineRef>[ref(1, 0, 'a'), ref(1, 2, 'c')]).isContiguous,
          isFalse);
      final SelectionDraft cross =
          draft(<LineRef>[ref(1, 0, 'a'), ref(2, 0, 'b')]);
      expect(cross.spansParagraphs, isTrue);
      expect(cross.isContiguous, isTrue, reason: '跨段落不算断行，另行提示');
    });

    test('签名去掉空白与标点后稳定，不同句子不同', () {
      final String a = draft(<LineRef>[ref(1, 0, '「雪落  在纸上。」')]).signature();
      final String b = draft(<LineRef>[ref(1, 0, '「雪落在纸上。」')]).signature();
      final String c = draft(<LineRef>[ref(1, 0, '雪落在书上。')]).signature();
      expect(a, b);
      expect(a, isNot(c));
      expect(a, contains('b01|1|'));
    });

    test('校验：空选区 / 纯标点 / 超长', () {
      expect(draft(<LineRef>[]).isValid, isFalse);
      expect(draft(<LineRef>[]).validationMessage, contains('先点选'));
      expect(draft(<LineRef>[ref(1, 0, '……')]).isValid, isFalse);
      expect(draft(<LineRef>[ref(1, 0, '……')]).validationMessage,
          contains('没有可摘录'));

      final String long = '字' * (SelectionDraft.maxExcerptLength + 1);
      final SelectionDraft tooLong = draft(<LineRef>[ref(1, 0, long)]);
      expect(tooLong.isValid, isFalse);
      expect(tooLong.validationMessage, contains('最长'));
      expect(draft(<LineRef>[ref(1, 0, '正常的一句')]).isValid, isTrue);
    });

    test('toDraft 带锚点、颜色、批注与跨段落标记', () {
      final SelectionDraft d =
          draft(<LineRef>[ref(1, 0, '第一行'), ref(2, 0, '第二段')]);
      final ExcerptDraft out =
          d.toDraft(highlight: HighlightColor.rose, note: '  记一下  ');
      expect(out.text, '第一行第二段');
      expect(out.highlight, HighlightColor.rose);
      expect(out.note, '记一下');
      expect(out.crossParagraph, isTrue);
      expect(out.origin!.blockIndex, 1);
      expect(out.signature, d.signature());
      expect(out.copyWith(note: '改了').note, '改了');
      expect(out.note, '记一下', reason: 'copyWith 不改原对象');
    });
  });

  group('划线色板', () {
    test('四色都有标签与色值', () {
      expect(HighlightPalette.labels.length, HighlightColor.values.length);
      expect(HighlightPalette.colors.length, HighlightColor.values.length);
      for (final HighlightColor c in HighlightColor.values) {
        expect(
            HighlightPalette.lineTint(c), isNot(HighlightPalette.colors[c]!));
      }
    });
  });

  group('Excerpt 向后兼容', () {
    final Excerpt seed = Excerpt(
      id: 'e1',
      bookId: 'b01',
      bookTitle: '纸白纪事',
      chapterTitle: '第一章',
      text: '一段正文',
      capturedAt: DateTime.utc(2026, 1, 1),
    );

    test('演示摘录保持默认字段', () {
      expect(seed.isUserAdded, isFalse);
      expect(seed.highlight, HighlightColor.amber);
      expect(seed.note, isEmpty);
      expect(seed.origin, isNull);
      expect(seed.displayText, '一段正文');
    });

    test('copyWith 与 displayText 带批注', () {
      final Excerpt e = seed.copyWith(note: '好看', isUserAdded: true);
      expect(seed.note, isEmpty);
      expect(e.displayText, contains('—— 好看'));
      expect(e.isUserAdded, isTrue);
    });

    test('值相等可用于列表去重判断', () {
      expect(seed, seed.copyWith());
      expect(seed.hashCode, seed.copyWith().hashCode);
      expect(seed, isNot(seed.copyWith(text: '另一段')));
    });
  });

  group('AppState 摘录闭环', () {
    AppState make() => AppState(
          settingsStore: InMemorySettingsStore(),
          books: const DemoBookRepository(),
        );

    ExcerptDraft sampleDraft(String text, {String signature = 'sig-a'}) =>
        ExcerptDraft(
          bookId: 'b01',
          chapterIndex: 1,
          pageIndex: 0,
          text: text,
          signature: signature,
          highlight: HighlightColor.sage,
          note: '批注',
          origin: ref(1, 0, text, chapter: 1),
        );

    test('初始只有 4 条演示摘录，且只读', () {
      final AppState s = make();
      expect(s.excerpts.length, 4);
      expect(s.excerpts.every((Excerpt e) => !e.isUserAdded), isTrue);
      expect(() => s.excerpts.add(seedForTest()), throwsUnsupportedError);
      expect(s.removeExcerpt('e1'), isFalse);
      expect(s.excerpts.length, 4);
    });

    test('写入后排在最前，并可被统计页同一次 build 读到', () {
      final AppState s = make();
      final Excerpt? saved = s.addExcerpt(
        sampleDraft('新摘的一句'),
        bookTitle: '雪国的旅行者',
        chapterTitle: '第二章  雪',
      );
      expect(saved, isNotNull);
      expect(saved!.isUserAdded, isTrue);
      expect(s.excerpts.length, 5);
      expect(s.excerpts.first.text, '新摘的一句');
      expect(s.userExcerpts.length, 1);
    });

    test('同 signature 去重，返回 null 不制造重复卡片', () {
      final AppState s = make();
      expect(
          s.addExcerpt(sampleDraft('第一句'), bookTitle: 'A', chapterTitle: 'c'),
          isNotNull);
      expect(
          s.addExcerpt(sampleDraft('第一句，标点不同'),
              bookTitle: 'A', chapterTitle: 'c'),
          isNull);
      expect(s.userExcerpts.length, 1);
      expect(s.hasSignature('sig-a'), isTrue);
    });

    test('不同 signature 可写入多条，新→旧排列', () {
      final AppState s = make();
      s.addExcerpt(sampleDraft('第一句', signature: 'sig-1'),
          bookTitle: 'A', chapterTitle: 'c');
      s.addExcerpt(sampleDraft('第二句', signature: 'sig-2'),
          bookTitle: 'A', chapterTitle: 'c');
      expect(s.excerpts.first.text, '第二句');
      expect(s.excerpts[1].text, '第一句');
    });

    test('空文本不写入', () {
      final AppState s = make();
      expect(
          s.addExcerpt(sampleDraft('   '), bookTitle: 'A', chapterTitle: 'c'),
          isNull);
      expect(s.userExcerpts, isEmpty);
    });

    test('只能删除用户摘录，删后合并列表回到演示 4 条', () {
      final AppState s = make();
      final Excerpt? saved =
          s.addExcerpt(sampleDraft('要删的'), bookTitle: 'A', chapterTitle: 'c');
      expect(s.removeExcerpt(saved!.id), isTrue);
      expect(s.userExcerpts, isEmpty);
      expect(s.excerpts.length, 4);
      expect(s.removeExcerpt(saved.id), isFalse);
      expect(s.removeExcerpt('e1'), isFalse);
    });

    test('highlightsFor 只返回带锚点且同书同章的摘录', () {
      final AppState s = make();
      s.addExcerpt(sampleDraft('划线句'), bookTitle: 'A', chapterTitle: 'c');
      expect(s.highlightsFor(bookId: 'b01', chapterIndex: 1).length, 1);
      expect(s.highlightsFor(bookId: 'b01', chapterIndex: 2), isEmpty);
      expect(s.highlightsFor(bookId: 'other', chapterIndex: 1), isEmpty);
    });
  });
}

Excerpt seedForTest() => Excerpt(
      id: 'x',
      bookId: 'x',
      bookTitle: 'x',
      chapterTitle: 'x',
      text: 'x',
      capturedAt: DateTime.utc(2026, 1, 1),
    );
