// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖
// 合并状态 E13：已落入工程路径 lib/core/model/import_prefs.dart；同名类型已隔离；未编译 / 未运行 / 未下载依赖。
// 设计源：scaffold/import_prefs.dart（交付包内保留，作为规格基线）
// 建议落点：lib/core/model/import_prefs.dart
// 对应需求：R13「导入书籍 → 右侧设置」里的 TXT 编码 / 目录识别 / 自定义规则 / 无标题策略
// 对齐：docs/08 §8.3；纯 Dart，便于模型级测试。

/// TXT 编码：自动 + 常见中文编码（自动时由 dev 现有 charset 探测决定）。
enum TxtEncoding { auto, utf8, gbk, big5, utf16, gb18030 }

const Map<TxtEncoding, String> kTxtEncodingLabels = <TxtEncoding, String>{
  TxtEncoding.auto: '自动',
  TxtEncoding.utf8: 'UTF-8',
  TxtEncoding.gbk: 'GBK',
  TxtEncoding.big5: 'Big5',
  TxtEncoding.utf16: 'UTF-16',
  TxtEncoding.gb18030: 'GB18030',
};

/// TXT 目录识别：自动识别 / 自定义规则。
enum TxtTocMode { auto, custom }

/// 原书未提供标题时的两种处理（用户原文：补齐章节名 / 标为正文片段）。
enum UntitledPolicy { fillChapterName, markAsBodyFragment }

/// 自定义规则：展示「匹配的章节正则」与「分卷正则」，用户可修改。
/// 两条正则都作为字符串保存，页面用 TextField 直接编辑，规则引擎负责编译与预览。
class TxtCustomRules {
  const TxtCustomRules({
    this.chapterRegex =
        r'^\s*(第[零一二三四五六七八九十百千万\d]+[章节回篇]|Chapter\s+\d+|\d+[\.、])\s*.{0,60}$',
    this.volumeRegex =
        r'^\s*(第[零一二三四五六七八九十百千万\d]+卷|Volume\s+\d+|卷\s*\d+)\s*.{0,60}$',
    this.editable = true,
  });

  final String chapterRegex;
  final String volumeRegex;
  final bool editable;

  TxtCustomRules copyWith({
    String? chapterRegex,
    String? volumeRegex,
    bool? editable,
  }) =>
      TxtCustomRules(
        chapterRegex: chapterRegex ?? this.chapterRegex,
        volumeRegex: volumeRegex ?? this.volumeRegex,
        editable: editable ?? this.editable,
      );

  /// 正则合法性只在这里判定，非法表达式不落库、不覆盖上次可用规则。
  bool get isValid {
    try {
      RegExp(chapterRegex);
      RegExp(volumeRegex);
      return true;
    } on FormatException {
      return false;
    }
  }

  TxtCustomRules normalized() => isValid
      ? this
      : const TxtCustomRules(); // 非法输入回退到内置规则，不静默留下坏正则
}

/// 导入设置聚合：唯一裁决点，页面不自己解释开关。
class ImportSettings {
  const ImportSettings({
    this.encoding = TxtEncoding.auto,
    this.tocMode = TxtTocMode.auto,
    this.rules = const TxtCustomRules(),
    this.untitledPolicy = UntitledPolicy.fillChapterName,
    this.showRulePreview = true,
  });

  final TxtEncoding encoding;
  final TxtTocMode tocMode;
  final TxtCustomRules rules;
  final UntitledPolicy untitledPolicy;
  final bool showRulePreview;

  bool get usesCustomRules => tocMode == TxtTocMode.custom;

  ImportSettings copyWith({
    TxtEncoding? encoding,
    TxtTocMode? tocMode,
    TxtCustomRules? rules,
    UntitledPolicy? untitledPolicy,
    bool? showRulePreview,
  }) =>
      ImportSettings(
        encoding: encoding ?? this.encoding,
        tocMode: tocMode ?? this.tocMode,
        rules: rules ?? this.rules,
        untitledPolicy: untitledPolicy ?? this.untitledPolicy,
        showRulePreview: showRulePreview ?? this.showRulePreview,
      );

  ImportSettings normalized() => copyWith(rules: rules.normalized());

  /// 存进 app_prefs 的 JSON 白名单（v4 已有 app_prefs 表）。
  /// 不含路径、账号、Cookie、令牌。
  Map<String, Object> toPrefs() => <String, Object>{
        'txtEncoding': encoding.name,
        'txtTocMode': tocMode.name,
        'chapterRegex': rules.chapterRegex,
        'volumeRegex': rules.volumeRegex,
        'untitledPolicy': untitledPolicy.name,
      };
}
