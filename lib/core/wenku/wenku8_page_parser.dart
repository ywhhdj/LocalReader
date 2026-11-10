import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import 'wenku8_login_inspection.dart';
import 'wenku8_models.dart';

/// 解析结果：把「站点结构变了」「版权受限」「需要验证」和网络失败区分开。
/// 绝不把乱码 / 质询页当成小说列表渲染。
enum Wenku8ParseIssue { none, upstreamChanged, restricted, challenge, empty }

@immutable
class Wenku8ParseOutcome<T> {
  const Wenku8ParseOutcome.ok(this.value)
      : issue = Wenku8ParseIssue.none,
        note = '';

  const Wenku8ParseOutcome.failed(this.issue, this.note) : value = null;

  final T? value;
  final Wenku8ParseIssue issue;
  final String note;

  bool get isOk => value != null && issue == Wenku8ParseIssue.none;
}

/// 站点适配层（第二十三轮）。
///
/// **重要**：公开资料没有 Wenku8 官方页面结构文档，且参考仓库 README 明确提醒
/// 第三方服务可能变更。这里给的是**可替换的适配规则**，不是对真实 DOM 的断言。
/// 真机接入时按实际公开页面核对正则与结构标记；核对不上就返回
/// `upstreamChanged`，由界面提示「来源结构已变化」，**不猜内容、不降级成乱码**。
abstract interface class Wenku8PageParser {
  Wenku8ParseOutcome<List<Wenku8Book>> parseListing(String html);
  Wenku8ParseOutcome<Wenku8Detail> parseDetail(String html, Wenku8Book fallback);
  Wenku8ParseOutcome<Wenku8ChapterText> parseChapter(
      String html, String bookId, String chapterId);
}

/// 版权受限 / 验证质询标记。命中后**停止请求、不重试、不尝试绕过**，
/// 界面引导用户去来源官网自行完成验证或确认可读状态。
const List<String> kWenku8ChallengeMarkers = <String>[
  '访问验证', '请完成验证', '人机验证', 'cf-challenge', 'just a moment',
];
const List<String> kWenku8RestrictedMarkers = <String>[
  '版权原因', '版权限制', '已下架', '停止开放', '暂不提供阅读',
];

class Wenku8WebPageParser implements Wenku8PageParser {
  const Wenku8WebPageParser();

  /// 书目页形态来自公开资料：`/book/2312.htm`。
  /// 站点改版时只需改这里，页面 / 状态 / 合规层不动。
  static final RegExp _bookLink = RegExp(
    r'/book/(\d+)\.htm[^>]*>([^<]{1,80})<',
    caseSensitive: false,
  );

  static final RegExp _chapterLink = RegExp(
    r'cid=(\d+)[^>]*>([^<]{1,120})<',
    caseSensitive: false,
  );

  static const List<String> _structureMarkers = <String>[
    '/book/', '.htm', '<a ',
  ];

  Wenku8ParseIssue? _guard(String html) {
    final String lower = html.toLowerCase();
    for (final String m in kWenku8ChallengeMarkers) {
      if (lower.contains(m.toLowerCase())) {
        return Wenku8ParseIssue.challenge;
      }
    }
    for (final String m in kWenku8RestrictedMarkers) {
      if (html.contains(m)) return Wenku8ParseIssue.restricted;
    }
    // 第二十五轮：来源返回「本站正式关闭」公告时，不能当成空列表 / 章节读不到，
    // 要明确报结构变化，避免界面显示「暂无数据」把真实原因藏起来。
    for (final String m in kWenku8ClosureMarkers) {
      if (html.contains(m)) return Wenku8ParseIssue.upstreamChanged;
    }
    return null;
  }

  /// 解析失败的说明只有一份，页面不各写一份中文句子。
  static String noteFor(Wenku8ParseIssue issue) {
    switch (issue) {
      case Wenku8ParseIssue.challenge:
        return '来源要求访问验证；请到官网完成后再试，本应用不绕过验证。';
      case Wenku8ParseIssue.restricted:
        return '该内容因版权原因不可读，本应用不提供下架内容。';
      case Wenku8ParseIssue.upstreamChanged:
        return '来源页面结构已变化或返回站点公告，需按实际页面更新解析规则。';
      case Wenku8ParseIssue.empty:
        return '来源未返回可解析内容。';
      case Wenku8ParseIssue.none:
        return '';
    }
  }

  bool _looksLikeListing(String html) =>
      _structureMarkers.every((String m) => html.contains(m));

  @override
  Wenku8ParseOutcome<List<Wenku8Book>> parseListing(String html) {
    final Wenku8ParseIssue? guard = _guard(html);
    if (guard != null) {
      return Wenku8ParseOutcome<List<Wenku8Book>>.failed(
        guard, noteFor(guard));
    }
    if (html.trim().length < 200 || !_looksLikeListing(html)) {
      return const Wenku8ParseOutcome<List<Wenku8Book>>.failed(
        Wenku8ParseIssue.upstreamChanged,
        '公开页面结构未匹配，需按实际站点更新解析器。',
      );
    }
    final Map<String, Wenku8Book> byId = <String, Wenku8Book>{};
    for (final RegExpMatch m in _bookLink.allMatches(html)) {
      final String id = m.group(1) ?? '';
      final String title = _clean(m.group(2) ?? '');
      if (id.isEmpty || title.isEmpty) continue;
      byId.putIfAbsent(
        id,
        () => Wenku8Book(
          id: id,
          title: title,
          author: '',
          coverColor: _colorFor(id),
          tags: const <String>['Wenku8'],
          latestChapter: '',
          updatedKey: '',
        ),
      );
    }
    if (byId.isEmpty) {
      return const Wenku8ParseOutcome<List<Wenku8Book>>.failed(
        Wenku8ParseIssue.upstreamChanged,
        '未从公开页面提取到书目，需核对解析规则。',
      );
    }
    return Wenku8ParseOutcome<List<Wenku8Book>>.ok(
      List<Wenku8Book>.unmodifiable(byId.values),
    );
  }

  @override
  Wenku8ParseOutcome<Wenku8Detail> parseDetail(String html, Wenku8Book fallback) {
    final Wenku8ParseIssue? guard = _guard(html);
    if (guard != null) {
      return Wenku8ParseOutcome<Wenku8Detail>.failed(
        guard, noteFor(guard));
    }
    final List<Wenku8Chapter> chapters = <Wenku8Chapter>[];
    for (final RegExpMatch m in _chapterLink.allMatches(html)) {
      final String cid = m.group(1) ?? '';
      final String title = _clean(m.group(2) ?? '');
      if (cid.isEmpty || title.isEmpty) continue;
      chapters.add(Wenku8Chapter(
        index: chapters.length,
        title: title,
        volumeIndex: 1,
        chapterId: cid,
      ));
    }
    if (chapters.isEmpty || !_looksLikeListing(html)) {
      return const Wenku8ParseOutcome<Wenku8Detail>.failed(
        Wenku8ParseIssue.upstreamChanged,
        '目录结构未匹配，需按实际站点更新解析器。',
      );
    }
    return Wenku8ParseOutcome<Wenku8Detail>.ok(
      Wenku8Detail(
        book: fallback,
        synopsis: '目录与简介由 Wenku8 提供，可用性以来源为准。',
        volumes: <Wenku8Volume>[
          Wenku8Volume(
            index: 1,
            title: '正文',
            chapters: List<Wenku8Chapter>.unmodifiable(chapters),
          ),
        ],
      ),
    );
  }

  @override
  Wenku8ParseOutcome<Wenku8ChapterText> parseChapter(
      String html, String bookId, String chapterId) {
    final Wenku8ParseIssue? guard = _guard(html);
    if (guard != null) {
      return Wenku8ParseOutcome<Wenku8ChapterText>.failed(
        guard, noteFor(guard));
    }
    // 只移除脚本 / 样式与标签，保留段落文本；不做整本拼接、不导出。
    final String stripped = html
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&nbsp;|&#160;'), ' ')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
    if (stripped.length < 40) {
      return const Wenku8ParseOutcome<Wenku8ChapterText>.failed(
        Wenku8ParseIssue.upstreamChanged,
        '章节正文结构未匹配，需核对解析规则。',
      );
    }
    return Wenku8ParseOutcome<Wenku8ChapterText>.ok(
      Wenku8ChapterText(
        bookId: bookId,
        chapterId: chapterId,
        title: '章节 $chapterId',
        text: stripped,
      ),
    );
  }

  static String _clean(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Color _colorFor(String id) {
    final int h = id.codeUnits.fold<int>(0, (int a, int b) => (a * 31 + b) % 360);
    return Color.lerp(const Color(0xFF6E8CA8), const Color(0xFF9C7BA0), h / 360)!;
  }
}
