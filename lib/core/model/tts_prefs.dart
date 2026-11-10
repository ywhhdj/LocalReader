import 'package:flutter/foundation.dart';

/// 听读音色：只是音调 / 语速的组合，不下载语音包。
/// 真正的发声人由系统「文字转语音」提供（平台层 ❄️ 冻结）。
enum TtsTimbre { soft, normal, bright }

@immutable
class TtsPreferences {
  const TtsPreferences({
    this.timbre = TtsTimbre.normal,
    this.voiceName = '',
    this.autoNext = true,
  });

  final TtsTimbre timbre;
  final String voiceName;
  final bool autoNext;

  TtsPreferences copyWith({
    TtsTimbre? timbre,
    String? voiceName,
    bool? autoNext,
  }) =>
      TtsPreferences(
        timbre: timbre ?? this.timbre,
        voiceName: voiceName ?? this.voiceName,
        autoNext: autoNext ?? this.autoNext,
      );

  @override
  bool operator ==(Object other) =>
      other is TtsPreferences &&
      other.timbre == timbre &&
      other.voiceName == voiceName &&
      other.autoNext == autoNext;

  @override
  int get hashCode => Object.hash(timbre, voiceName, autoNext);
}
