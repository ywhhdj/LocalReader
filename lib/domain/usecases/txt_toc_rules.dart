// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖
// 合并状态 E13：已落入工程路径 lib/domain/usecases/txt_toc_rules.dart；同名类型已隔离；未编译 / 未运行 / 未下载依赖。
// 设计源：scaffold/txt_toc_rules.dart（交付包内保留，作为规格基线）
// 建议落点：lib/domain/usecases/txt_toc_rules.dart
// 对应需求：R13 自定义规则「展示匹配的章节正则和分卷正则」+ 无标题策略
// 对齐：docs/08 §8.3；纯 Dart，RegExp 只做匹配，不读文件、不联网。

import 'package:Local_reader/core/model/import_prefs.dart';

enum TocMatchKind { chapter, volume, bodyFragment }

class TocMatch {
  const TocMatch({
    required this.kind,
    required this.rawLine,
    required this.lineIndex,
    required this.ordinal,
    this.title = '',
    this.generatedTitle = false,
    this.isBodyFragment = false,
  });

  final TocMatchKind kind;
  final String rawLine;
  final int lineIndex;
  final int ordinal;
  final String title;

  /// 原书未提供标题时按策略生成「第 N 章」，或标为正文片段。
  final bool generatedTitle;
  final bool isBodyFragment;
}

/// 章节 / 分卷匹配结果 + 匹配预览（设置页展示用）。
class TocRulePreview {
  const TocRulePreview({
    required this.chapterRegex,
    required this.volumeRegex,
    this.chapterSamples = const <String>[],
    this.volumeSamples = const <String>[],
    this.valid = true,
  });

  final String chapterRegex;
  final String volumeRegex;
  final List<String> chapterSamples;
  final List<String> volumeSamples;
  final bool valid;
}

class TocRuleEngine {
  const TocRuleEngine({this.maxSamples = 5});

  final int maxSamples;

  /// 自动模式用内置规则；自定义模式用用户可改的两条正则。
  TxtCustomRules effectiveRules(ImportSettings settings) =>
      settings.usesCustomRules ? settings.rules.normalized() : const TxtCustomRules();

  /// 设置页预览：展示两条正则本身 + 各取前 N 条命中行，改完立刻能看到命中什么。
  TocRulePreview preview(String text, ImportSettings settings) {
    final TxtCustomRules rules = effectiveRules(settings);
    if (!rules.isValid) {
      return TocRulePreview(
        chapterRegex: rules.chapterRegex,
        volumeRegex: rules.volumeRegex,
        valid: false,
      );
    }
    final RegExp chapter = RegExp(rules.chapterRegex, multiLine: true);
    final RegExp volume = RegExp(rules.volumeRegex, multiLine: true);
    return TocRulePreview(
      chapterRegex: rules.chapterRegex,
      volumeRegex: rules.volumeRegex,
      chapterSamples: _samples(text, chapter),
      volumeSamples: _samples(text, volume),
      valid: true,
    );
  }

  List<String> _samples(String text, RegExp re) {
    final List<String> out = <String>[];
    for (final Match m in re.allMatches(text)) {
      out.add(m.group(0)?.trim() ?? '');
      if (out.length >= maxSamples) break;
    }
    return List<String>.unmodifiable(out);
  }

  /// 解析目录：分卷优先于章节；同一行同时命中两条时按分卷计。
  /// 原书未提供标题的行按 UntitledPolicy 处理：
  ///   fillChapterName      → 生成「第 N 章」并标 generatedTitle
  ///   markAsBodyFragment   → 标 isBodyFragment，归入上一章正文，不新建章节
  List<TocMatch> parse(String text, ImportSettings settings) {
    final TxtCustomRules rules = effectiveRules(settings);
    if (!rules.isValid) return <TocMatch>[];
    final RegExp chapterRe = RegExp(rules.chapterRegex, multiLine: true);
    final RegExp volumeRe = RegExp(rules.volumeRegex, multiLine: true);
    final List<String> lines = text.split(RegExp(r'\r?\n'));
    final List<TocMatch> out = <TocMatch>[];
    int chapterNo = 0;

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      final bool isVolume = volumeRe.hasMatch(line);
      final bool isChapter = chapterRe.hasMatch(line);
      if (!isVolume && !isChapter) continue;

      final String title = line.trim();
      final bool hasTitle = title.isNotEmpty;
      if (isVolume) {
        out.add(TocMatch(
          kind: TocMatchKind.volume,
          rawLine: line,
          lineIndex: i,
          ordinal: out.where((TocMatch m) => m.kind == TocMatchKind.volume).length + 1,
          title: hasTitle ? title : '第 ${_volumeNoOf(out) + 1} 卷',
          generatedTitle: !hasTitle,
        ));
        continue;
      }

      chapterNo += 1;
      if (!hasTitle || _isBlankTitle(line)) {
        switch (settings.untitledPolicy) {
          case UntitledPolicy.fillChapterName:
            out.add(TocMatch(
              kind: TocMatchKind.chapter,
              rawLine: line,
              lineIndex: i,
              ordinal: chapterNo,
              title: '第 $chapterNo 章',
              generatedTitle: true,
            ));
            break;
          case UntitledPolicy.markAsBodyFragment:
            out.add(TocMatch(
              kind: TocMatchKind.bodyFragment,
              rawLine: line,
              lineIndex: i,
              ordinal: chapterNo,
              isBodyFragment: true,
            ));
            break;
        }
      } else {
        out.add(TocMatch(
          kind: TocMatchKind.chapter,
          rawLine: line,
          lineIndex: i,
          ordinal: chapterNo,
          title: title,
        ));
      }
    }
    return List<TocMatch>.unmodifiable(out);
  }

  int _volumeNoOf(List<TocMatch> matches) =>
      matches.where((TocMatch m) => m.kind == TocMatchKind.volume).length;

  bool _isBlankTitle(String line) => line.trim().isEmpty;
}
