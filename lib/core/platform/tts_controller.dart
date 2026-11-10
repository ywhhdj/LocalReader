import '../models/book_document.dart';
import 'reader_bridge.dart';
import 'tts_queue.dart';

/// SentenceQueue（纯 Dart 队列）↔ TtsBridge（三端原生）的唯一适配层。
/// 队列决定「读哪一句」，原生只负责读一句；暂停/续播精确到句靠 Dart 侧 cursor。
class TtsController {
  TtsController({required this.bridge, this.rate = 1.0, this.pitch = 1.0});

  final TtsBridge bridge;
  double rate;
  double pitch;

  SentenceQueue? _queue;
  bool _playing = false;
  int _chapterIndex = 0;
  void Function(int finishedChapter)? onChapterEnd;

  bool get isPlaying => _playing;
  int get cursor => _queue?.cursor ?? 0;
  int get length => _queue?.length ?? 0;

  /// 打开一章；切换章节时由调用方重新 loadChapter。
  void loadChapter(int chapterIndex, List<ContentBlock> blocks) {
    _chapterIndex = chapterIndex;
    _queue = SentenceQueue(
      onSpeak: _speak,
      onChapterEnd: (int finished) {
        _playing = false;
        onChapterEnd?.call(finished); // 读完自动进入下一章由调用方接住
      },
    )..loadChapter(chapterIndex, blocks);
  }

  Future<void> _speak(String sentence, int chapterIndex, int sentenceIndex) {
    // 真实实现：Pigeon TtsApi.speak(sentence, utteranceId) → 等待
    // TtsEvents.onSentenceDone 事件后才返回，Dart 队列才会推进 cursor。
    // 当前 MethodChannelBridge.enqueueSentences 是占位，这里保持接口形状不变。
    return bridge.enqueueSentences(<String>[sentence]);
  }

  Future<void> play() async {
    final SentenceQueue? q = _queue;
    if (q == null || _playing) return;
    await bridge.setRate(rate);
    await bridge.setPitch(pitch);
    _playing = true;
    await q.resume();
    if (q.isPaused || q.cursor >= q.length) _playing = false;
  }

  Future<void> pause() async {
    _queue?.pause();
    _playing = false;
    await bridge.pause();
  }

  /// 从指定句恢复（跨端同步进度 / 应用重启后续播）。
  Future<void> resumeAt(int sentenceIndex) async {
    final SentenceQueue? q = _queue;
    if (q == null) return;
    q.seek(sentenceIndex);
    await bridge.resumeAtSentence(sentenceIndex);
    _playing = true;
    await q.resume();
  }

  Future<void> setRate(double value) async {
    rate = value;
    await bridge.setRate(value);
  }

  Future<void> setPitch(double value) async {
    pitch = value;
    await bridge.setPitch(value);
  }

  void skipNext() => _queue?.skipNext();

  Future<void> stop() async {
    _queue?.stop();
    _playing = false;
    await bridge.stop();
  }

  int get chapterIndex => _chapterIndex;
}
