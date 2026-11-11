// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖
// 合并状态 E13：已落入工程路径 lib/core/model/tts_engine_prefs.dart；同名类型已隔离；未编译 / 未运行 / 未下载依赖。
// 设计源：scaffold/tts_engine.dart（交付包内保留，作为规格基线）
// 建议落点：lib/core/model/tts_engine_prefs.dart（R11「语言接口」）
// 口径：按「朗读 / 语音引擎接口」理解，三种引擎用顶部导航栏切换各自配置页。
// 纯 Dart，无 Flutter 依赖。

/// 三种语言接口（R11）：系统语音 / OpenAI 兼容 / SSML。
enum TtsEngineKind { system, openAiCompatible, ssml }

const List<TtsEngineKind> kTtsEngineTabs = <TtsEngineKind>[
  TtsEngineKind.system,
  TtsEngineKind.openAiCompatible,
  TtsEngineKind.ssml,
];

/// 系统语音页：引擎 / 音色 / 语速 / 音调 / 自动下章。
// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class SystemTtsConfig {
  const SystemTtsConfig({
    this.enginePackage = '',
    this.voiceName = '',
    this.rate = 1.0,
    this.pitch = 1.0,
    this.autoNextChapter = true,
  });

  final String enginePackage;
  final String voiceName;
  final double rate;
  final double pitch;
  final bool autoNextChapter;

  SystemTtsConfig normalized() => SystemTtsConfig(
        enginePackage: enginePackage,
        voiceName: voiceName,
        rate: rate.clamp(0.5, 3.0).toDouble(),
        pitch: pitch.clamp(0.5, 2.0).toDouble(),
        autoNextChapter: autoNextChapter,
      );
}

/// OpenAI 兼容页：baseUrl / model / 音色映射 / 分句策略。
/// 注意：apiKeyRef 只是**安全存储里的引用键**，明文密钥不进偏好、备份、日志或同步文件。
// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class OpenAiCompatibleConfig {
  const OpenAiCompatibleConfig({
    this.baseUrl = '',
    this.model = '',
    this.apiKeyRef = '',
    this.voiceMap = const <String, String>{},
    this.sentenceSplit = 'paragraph',
  });

  final String baseUrl;
  final String model;
  final String apiKeyRef;
  final Map<String, String> voiceMap;
  final String sentenceSplit;

  bool get httpsOnly =>
      baseUrl.isEmpty || baseUrl.toLowerCase().startsWith('https://');

  OpenAiCompatibleConfig normalized() => OpenAiCompatibleConfig(
        baseUrl: httpsOnly ? baseUrl : '',
        model: model,
        apiKeyRef: apiKeyRef,
        voiceMap: voiceMap,
        sentenceSplit: sentenceSplit,
      );
}

/// SSML 页：endpoint / 自定义模板 / 请求头 / 试听文本。
/// 密钥同样只存 secureStore 引用。
// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class SsmlConfig {
  const SsmlConfig({
    this.endpoint = '',
    this.template = '<speak version="1.0"><voice name="{{voice}}">{{text}}</voice></speak>',
    this.headers = const <String, String>{},
    this.secretRef = '',
    this.previewText = '这是一段试听文本',
  });

  final String endpoint;
  final String template;
  final Map<String, String> headers;
  final String secretRef;
  final String previewText;

  bool get httpsOnly =>
      endpoint.isEmpty || endpoint.toLowerCase().startsWith('https://');

  SsmlConfig normalized() => SsmlConfig(
        endpoint: httpsOnly ? endpoint : '',
        template: template.contains('{{text}}') ? template : '<speak>{{text}}</speak>',
        headers: headers,
        secretRef: secretRef,
        previewText: previewText,
      );
}

/// 归一化后**只有一个引擎生效**；三套配置可各自保留，切换不丢表单。
// 不可变（纯 Dart 骨架不引入 foundation / meta 注解）
class TtsEnginePrefs {
  const TtsEnginePrefs({
    this.kind = TtsEngineKind.system,
    this.system = const SystemTtsConfig(),
    this.openAi = const OpenAiCompatibleConfig(),
    this.ssml = const SsmlConfig(),
  });

  final TtsEngineKind kind;
  final SystemTtsConfig system;
  final OpenAiCompatibleConfig openAi;
  final SsmlConfig ssml;

  TtsEnginePrefs normalized() => TtsEnginePrefs(
        kind: kind,
        system: system.normalized(),
        openAi: openAi.normalized(),
        ssml: ssml.normalized(),
      );

  /// 当前生效配置的摘要（不含任何密钥明文）。
  Map<String, Object> activeSummary() {
    switch (normalized().kind) {
      case TtsEngineKind.system:
        return <String, Object>{
          'kind': kind.name,
          'voice': system.voiceName,
          'rate': system.rate,
        };
      case TtsEngineKind.openAiCompatible:
        return <String, Object>{
          'kind': kind.name,
          'model': openAi.model,
          'hasKeyRef': openAi.apiKeyRef.isNotEmpty,
        };
      case TtsEngineKind.ssml:
        return <String, Object>{
          'kind': kind.name,
          'hasSecretRef': ssml.secretRef.isNotEmpty,
        };
    }
  }
}
