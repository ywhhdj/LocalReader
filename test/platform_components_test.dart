import 'package:flutter_test/flutter_test.dart';
import 'package:local_reader/core/models/book_document.dart';
import 'package:local_reader/core/platform/render_bridge.dart';
import 'package:local_reader/core/platform/tts_queue.dart';
import 'package:local_reader/core/storage/progress_sampler.dart';
import 'package:local_reader/features/reader/comic_prefetch.dart';

class RecordingStore implements ProgressStore {
  final List<ReadingProgress> writes = <ReadingProgress>[];
  @override
  Future<void> write(ReadingProgress p) async => writes.add(p);
  @override
  Future<ReadingProgress?> read(String id) async =>
      writes.isEmpty ? null : writes.last;
}

class RecordingBridge extends UnimplementedRenderBridge {
  RecordingBridge() : super('測試平台');

  final List<List<int>> prefetched = <List<int>>[];
  final List<List<int>> evicted = <List<int>>[];

  @override
  Future<void> prefetch(int handle, List<int> upcoming) async => prefetched.add(upcoming);
  @override
  Future<void> evict(int handle, List<int> indices) async => evicted.add(indices);
}

void main() {
  group('SentenceQueue 分句', () {
    test('中文终止标点切句，右引号并入本句', () {
      final List<String> s = SentenceQueue.split('他說：「走了。」然後呢？沒了……');
      expect(s.length, 3);
      expect(s[0], '他說：「走了。」');
      expect(s[1], '然後呢？');
      expect(s[2], '沒了……');
    });

    test('尾段无标点也要入队', () {
      expect(SentenceQueue.split('一句。还没有标点的尾巴'), <String>['一句。', '还没有标点的尾巴']);
    });

    test('图片与分页符不进入朗读队列', () {
      final List<String> s = SentenceQueue.splitBlocks(<ContentBlock>[
        const ContentBlock(kind: BlockKind.paragraph, text: '正文一句。'),
        const ContentBlock(kind: BlockKind.image, assetPath: 'a.png'),
        const ContentBlock(kind: BlockKind.pageBreak),
        const ContentBlock(kind: BlockKind.paragraph, text: '另一句。'),
      ]);
      expect(s, <String>['正文一句。', '另一句。']);
    });

    test('一次 speak 完成才推进 cursor，暂停后从该句续播', () async {
      final List<String> spoken = <String>[];
      final SentenceQueue q = SentenceQueue(
        onSpeak: (String s, int c, int i) async {
          spoken.add(s);
          await Future<void>.delayed(const Duration(milliseconds: 1));
        },
        onChapterEnd: (_) {},
      );
      q.loadChapter(0, <ContentBlock>[
        const ContentBlock(kind: BlockKind.paragraph, text: '甲。乙。丙。'),
      ]);

      final Future<void> running = q.play();
      // 模拟用户中途暂停：当前句读完后循环应停住
      q.pause();
      await running;
      expect(q.cursor, lessThanOrEqualTo(1));
      expect(q.length, 3);

      final int at = q.cursor;
      await q.resume();
      expect(q.cursor, 3);
      expect(spoken.length, greaterThan(at));
    });

    test('seek 后再 play 从指定句开始', () async {
      final List<String> spoken = <String>[];
      final SentenceQueue q = SentenceQueue(
        onSpeak: (String s, int c, int i) async => spoken.add(s),
        onChapterEnd: (_) {},
      );
      q.loadChapter(0, <ContentBlock>[
        const ContentBlock(kind: BlockKind.paragraph, text: '甲。乙。丙。'),
      ]);
      q.seek(2);
      await q.play();
      expect(spoken, <String>['丙。']);
    });
  });

  group('ProgressSampler 节流与兜底', () {
    test('首次 record 立即落库，短时间内重复 record 被节流', () async {
      final RecordingStore store = RecordingStore();
      final ProgressSampler sampler = ProgressSampler(
        store: store,
        interval: const Duration(hours: 1),
      );
      final ReadingProgress p = ReadingProgress(
        bookId: 'b1', chapterIndex: 0, pageIndex: 1, pageOffset: 0.2,
        updatedAt: DateTime.now(),
      );
      sampler.record(p);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(store.writes.length, 1);

      sampler.record(p.copyWith(pageIndex: 2));
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(store.writes.length, 1, reason: '节流窗口内不重复写');

      await sampler.flush();
      expect(store.writes.length, 2);
      expect(store.writes.last.pageIndex, 2);
    });

    test('flush 在无脏数据时不写库', () async {
      final RecordingStore store = RecordingStore();
      final ProgressSampler sampler = ProgressSampler(store: store);
      await sampler.flush();
      expect(store.writes, isEmpty);
    });
  });

  group('ComicPrefetchWindow 批量窗口', () {
    test('窗口差集批量 prefetch / evict，重复位置不重复调用', () {
      final RecordingBridge bridge = RecordingBridge();
      final ComicPrefetchWindow w = ComicPrefetchWindow(bridge: bridge, back: 1, ahead: 2)
        ..attach(7, 10);

      w.moveTo(3);
      expect(w.activeWindow, <int>{2, 3, 4, 5});
      expect(bridge.prefetched.length, 1);
      expect(bridge.prefetched.single, <int>[2, 3, 4, 5]);

      w.moveTo(3);
      expect(bridge.prefetched.length, 1, reason: '同一页不重复预取');

      w.moveTo(4);
      expect(bridge.prefetched.last, <int>[6]);
      expect(bridge.evicted.last, <int>[2]);
    });
  });
}
