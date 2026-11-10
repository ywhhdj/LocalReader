import 'package:flutter/foundation.dart';

/// 双语阅读与朗读语言（第二十四轮）。
///
/// 参考仓库 README：「Preserve the book's lighter text styling and choose the
/// displayed language per book. Select spoken languages separately, with a
/// voice for each language; languages without a matching voice model are skipped.」
///
/// 静态阶段只做偏好与「跳过」裁决；真实 TTS 语音模型枚举属平台层（❄️ 冻结）。
enum ReadingLanguage { source, zhCn, zhTw, en, ja }

@immutable
class VoiceAssignment {
  const VoiceAssignment({required this.language, required this.voiceId});

  final ReadingLanguage language;
  final String voiceId;
}

@immutable
class BilingualPrefs {
  const BilingualPrefs({
    this.displayLanguage = ReadingLanguage.source,
    this.keepLighterStyling = true,
    this.spokenLanguages = const <ReadingLanguage>[ReadingLanguage.zhCn],
    this.voices = const <VoiceAssignment>[],
  });

  final ReadingLanguage displayLanguage;
  final bool keepLighterStyling;
  final List<ReadingLanguage> spokenLanguages;
  final List<VoiceAssignment> voices;

  static const Map<ReadingLanguage, String> labels = <ReadingLanguage, String>{
    ReadingLanguage.source: '原书语言',
    ReadingLanguage.zhCn: '简体中文',
    ReadingLanguage.zhTw: '繁體中文',
    ReadingLanguage.en: 'English',
    ReadingLanguage.ja: '日本語',
  };

  String? voiceFor(ReadingLanguage lang) {
    for (final VoiceAssignment v in voices) {
      if (v.language == lang) return v.voiceId;
    }
    return null;
  }

  /// 没有匹配语音模型的语言**跳过**，不回落到别的语言硬读
  ///（用中文腔读日文会完全不是一回事）。返回实际会朗读的语言顺序。
  List<ReadingLanguage> speakable({Set<ReadingLanguage> available = const <ReadingLanguage>{}}) {
    final List<ReadingLanguage> out = <ReadingLanguage>[];
    for (final ReadingLanguage lang in spokenLanguages) {
      if (voiceFor(lang) != null && (available.isEmpty || available.contains(lang))) {
        out.add(lang);
      }
    }
    return List<ReadingLanguage>.unmodifiable(out);
  }

  BilingualPrefs copyWith({
    ReadingLanguage? displayLanguage,
    bool? keepLighterStyling,
    List<ReadingLanguage>? spokenLanguages,
    List<VoiceAssignment>? voices,
  }) =>
      BilingualPrefs(
        displayLanguage: displayLanguage ?? this.displayLanguage,
        keepLighterStyling: keepLighterStyling ?? this.keepLighterStyling,
        spokenLanguages: spokenLanguages ?? this.spokenLanguages,
        voices: voices ?? this.voices,
      );
}
