import '../../core/model/book_document.dart';

/// 朗读回调：原生侧只负责「读一句」，队列与章节推进完全由 Dart 管，
/// 这样三端 TTS 行为一致，也避免原生插件各自实现一套续播逻辑。
typedef SpeakHandler = Future<void> Function(String sentence, int chapterIndex, int sentenceIndex);
typedef ChapterEndHandler = void Function(int finishedChapterIndex);

/// 分句队列：对应原项目「按批入队，暂停/续播精确到句，读完自动进入下一章」。
class SentenceQueue {
  SentenceQueue({required this.onSpeak, required this.onChapterEnd});

  final SpeakHandler onSpeak;
  final ChapterEndHandler onChapterEnd;

  final List<String> _sentences = <String>[];
  int _chapterIndex = 0;
  int _cursor = 0;
  bool _paused = true;
  bool _playing = false;

  int get chapterIndex => _chapterIndex;
  int get cursor => _cursor;
  int get length => _sentences.length;
  bool get isPaused => _paused;

  void loadChapter(int chapterIndex, List<ContentBlock> blocks) {
    _sentences
      ..clear()
      ..addAll(splitBlocks(blocks));
    _chapterIndex = chapterIndex;
    _cursor = 0;
    _paused = true;
  }

  /// 从指定句恢复（跨端同步进度时用）。
  void seek(int sentenceIndex) {
    _cursor = sentenceIndex.clamp(0, _sentences.length);
  }

  Future<void> play() async {
    if (_playing) return;
    _paused = false;
    _playing = true;
    try {
      while (!_paused && _cursor < _sentences.length) {
        final int i = _cursor;
        await onSpeak(_sentences[i], _chapterIndex, i);
        // 一次 speak 完成后才推进，保证「暂停/续播精确到句」。
        if (_paused) break;
        _cursor = i + 1;
      }
      if (!_paused && _cursor >= _sentences.length) {
        onChapterEnd(_chapterIndex);
      }
    } finally {
      _playing = false;
    }
  }

  void pause() => _paused = true;

  /// 返回 Future 便于调用方 unawaited；暂停后立刻续播时不另起循环，
  /// 让正在 await 的旧循环在当前句结束后继续，避免两句重叠。
  Future<void> resume() {
    if (!_paused) return Future<void>.value();
    _paused = false;
    if (_playing) return Future<void>.value();
    return play();
  }

  void skipNext() {
    _cursor = (_cursor + 1).clamp(0, _sentences.length);
  }

  void stop() {
    _paused = true;
    _cursor = 0;
  }

  /// 中文按终止标点切句，并把紧跟的右引号 / 右括号并入本句。
  static List<String> splitBlocks(List<ContentBlock> blocks) {
    final List<String> out = <String>[];
    for (final ContentBlock b in blocks) {
      if (b.isImage || b.isPageBreak || b.text.trim().isEmpty) continue;
      out.addAll(split(b.text));
    }
    return out;
  }

  static const Set<int> _terminators = <int>{
    0x3002, // 。
    0xFF01, // ！
    0xFF1F, // ？
    0x0021, // !
    0x003F, // ?
    0xFF1B, // ；
    0x003B, // ;
    0x2026, // …
  };
  static const Set<int> _closers = <int>{
    0x300D, 0x300F, 0x201D, 0x2019, // 」』”’
    0xFF09, 0x0029, 0x300B,  // ）) 》 』
    0x3011, 0x3009, // 】〉
  };

  static List<String> split(String text) {
    final List<String> sentences = <String>[];
    final StringBuffer buffer = StringBuffer();
    final String s = text.trim();
    for (int i = 0; i < s.length; i++) {
      final int c = s.codeUnitAt(i);
      buffer.writeCharCode(c);
      if (!_terminators.contains(c)) continue;

      // 连续标点（如「……！」）与右引号并入本句
      while (i + 1 < s.length) {
        final int next = s.codeUnitAt(i + 1);
        if (_terminators.contains(next) || _closers.contains(next)) {
          buffer.writeCharCode(next);
          i++;
        } else {
          break;
        }
      }
      final String sentence = buffer.toString().trim();
      if (sentence.isNotEmpty) sentences.add(sentence);
      buffer.clear();
    }
    if (buffer.toString().trim().isNotEmpty) sentences.add(buffer.toString().trim());
    return sentences;
  }
}
