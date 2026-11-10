import 'package:flutter/foundation.dart';

import '../../l10n/legal_texts.dart';
import '../repositories/book_repository.dart';
import 'library_query.dart';
import '../../data/parser/book_parser.dart';

/// 导入向导的纯 Dart 内核：步骤状态机 + 扫描分类 + 冲突决策 + 提交摘要。
///
/// 对应原项目 README 的「首页 导入 → 选择目录… → 授权持久化 → 重启一键重扫」
/// 与「手动合并 / 同步原书与阅读记录」。
///
/// **静态边界**：只处理路径字符串，不调用系统文件选择器、不读取文件字节、
/// 不解压、不联网。`SafController` / `BookParser.parse` 的真实调用是 ❄️ 冻结项；
/// 授权状态在这里只是「用户选了哪种方式」的演示标记。
///
/// 格式分界复用 `ParserRouter.routeForPath()` 这一张表（本轮把路由表提为静态出口），
/// 不允许导入页再维护第二份扩展名映射，否则 RAR5 / CBZ 的口径会漂移。

enum ImportStep { intro, permission, scan, conflicts, done }

/// 对齐原项目两种授权方式 + 系统文档选择器访问云盘。
enum ImportPermissionMode { saf, allFiles, documentPicker }

enum CandidateStatus { accepted, rejected, unsupported }

/// 冲突策略。演示书库只读：replace / mergeRecords 在静态阶段只记录决策、
/// 不改写演示数据，统一进入 `ImportCommit.deferred`。
enum ConflictResolution { skip, keepBoth, replace, mergeRecords }

/// 参考仓库 README 的云端导入渠道（第二十二轮补齐）：
/// OpenList / WebDAV / 夸克网盘（实验性），以及系统文档选择器访问
/// OneDrive / Google Drive 等服务。**不内置账号与凭据**，渠道只是入口选择，
/// 真实授权与文件读取仍 ❄️ 冻结（静态阶段只登记、不请求）。
enum CloudImportChannel { openList, webdav, quark, documentPicker }

class CloudImportLabels {
  const CloudImportLabels._();

  static const Map<CloudImportChannel, String> names =
      <CloudImportChannel, String>{
    CloudImportChannel.openList: 'OpenList',
    CloudImportChannel.webdav: 'WebDAV',
    CloudImportChannel.quark: '夸克网盘（实验性）',
    CloudImportChannel.documentPicker: '系统文档选择器',
  };

  static const Map<CloudImportChannel, String> hints =
      <CloudImportChannel, String>{
    CloudImportChannel.openList: '通过 OpenList 挂载的目录导入书籍文件。',
    CloudImportChannel.webdav: '通过 WebDAV 读取书库元数据与书籍文件。',
    CloudImportChannel.quark: '实验性渠道，第三方服务可能变更、限流或不可用。',
    CloudImportChannel.documentPicker:
        '可访问 OneDrive、Google Drive 等服务；不内置账号、密码或令牌。',
  };

  static const int count = 4;
}

class ImportLabels {
  const ImportLabels._();

  static const Map<ImportStep, String> steps = <ImportStep, String>{
    ImportStep.intro: '格式与权限说明',
    ImportStep.permission: '选择授权方式',
    ImportStep.scan: '扫描结果',
    ImportStep.conflicts: '冲突处理',
    ImportStep.done: '完成',
  };

  /// 步骤条用的短标签，同样只在模型里定义一份。
  static const Map<ImportStep, String> shortSteps = <ImportStep, String>{
    ImportStep.intro: '说明',
    ImportStep.permission: '授权',
    ImportStep.scan: '扫描',
    ImportStep.conflicts: '冲突',
    ImportStep.done: '完成',
  };

  static const Map<ImportPermissionMode, String> modes =
      <ImportPermissionMode, String>{
    ImportPermissionMode.saf: '系统文件选择器目录授权',
    ImportPermissionMode.allFiles: '所有文件访问权限',
    ImportPermissionMode.documentPicker: '系统文档选择器（云盘）',
  };

  static const Map<ImportPermissionMode, String> modeHints =
      <ImportPermissionMode, String>{
    ImportPermissionMode.saf: '推荐，无需全盘权限；授权会持久化，重启后可一键重扫。',
    ImportPermissionMode.allFiles: '授权后可直接扫描公共目录；文档类书籍仍需目录授权。',
    ImportPermissionMode.documentPicker:
        '可访问 OneDrive、Google Drive 等服务；不内置账号与凭据。',
  };

  static const Map<CandidateStatus, String> statuses =
      <CandidateStatus, String>{
    CandidateStatus.accepted: '可导入',
    CandidateStatus.rejected: '不支持',
    CandidateStatus.unsupported: '未登记格式',
  };

  static const Map<ConflictResolution, String> resolutions =
      <ConflictResolution, String>{
    ConflictResolution.skip: '跳过',
    ConflictResolution.keepBoth: '两者都保留',
    ConflictResolution.replace: '替换（延后）',
    ConflictResolution.mergeRecords: '合并记录（延后）',
  };

  static const Map<RenderRoute, String> renderRoutes = <RenderRoute, String>{
    RenderRoute.dartText: '纯 Dart 文本',
    RenderRoute.nativeRaster: '原生栅格化',
    RenderRoute.unsupported: '未登记',
  };
}

/// 书库里已存在的一本书，用于冲突比对。只带纯数据，不依赖仓储实现。
@immutable
class ExistingBook {
  const ExistingBook({required this.id, required this.title});

  final String id;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is ExistingBook && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

@immutable
class ImportCandidate {
  const ImportCandidate({
    required this.path,
    required this.title,
    required this.format,
    required this.route,
    required this.status,
    this.reason = '',
  });

  final String path;
  final String title;
  final String format;
  final RenderRoute route;
  final CandidateStatus status;
  final String reason;

  bool get isAccepted => status == CandidateStatus.accepted;

  /// 与 `BookSummary.isComic` 共用同一份格式集合，不另写一份判据。
  bool get looksComic => BookSummary.comicFormats.contains(format);

  /// 稳定 id：同名不同路径仍指向同一本，重复导入不会生成两条。
  String get draftId =>
      'imp-${ImportScanner.normalize(title).hashCode.toUnsigned(32)}';

  @override
  bool operator ==(Object other) =>
      other is ImportCandidate &&
      other.path == path &&
      other.title == title &&
      other.format == format &&
      other.route == route &&
      other.status == status &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(path, title, format, route, status, reason);
}

@immutable
class ScanReport {
  const ScanReport(this.candidates);

  final List<ImportCandidate> candidates;

  List<ImportCandidate> get accepted => _where(CandidateStatus.accepted);
  List<ImportCandidate> get rejected => _where(CandidateStatus.rejected);
  List<ImportCandidate> get unsupported => _where(CandidateStatus.unsupported);

  List<ImportCandidate> _where(CandidateStatus s) =>
      List<ImportCandidate>.unmodifiable(
        candidates.where((ImportCandidate c) => c.status == s),
      );

  int get total => candidates.length;
  int get acceptedCount => accepted.length;
  int get rejectedCount => rejected.length;
  int get unsupportedCount => unsupported.length;
  bool get isEmpty => total == 0;

  Map<String, int> get byFormat {
    final Map<String, int> out = <String, int>{};
    for (final ImportCandidate c in candidates) {
      out[c.format] = (out[c.format] ?? 0) + 1;
    }
    return Map<String, int>.unmodifiable(out);
  }

  Map<CandidateStatus, int> get byStatus =>
      Map<CandidateStatus, int>.unmodifiable(
        <CandidateStatus, int>{
          CandidateStatus.accepted: acceptedCount,
          CandidateStatus.rejected: rejectedCount,
          CandidateStatus.unsupported: unsupportedCount,
        },
      );
}

@immutable
class ImportConflict {
  const ImportConflict({
    required this.candidate,
    required this.existing,
    this.resolution,
  });

  final ImportCandidate candidate;
  final ExistingBook existing;
  final ConflictResolution? resolution;

  bool get resolved => resolution != null;

  ImportConflict withResolution(ConflictResolution r) => ImportConflict(
        candidate: candidate,
        existing: existing,
        resolution: r,
      );

  @override
  bool operator ==(Object other) =>
      other is ImportConflict &&
      other.candidate == candidate &&
      other.existing == existing &&
      other.resolution == resolution;

  @override
  int get hashCode => Object.hash(candidate, existing, resolution);
}

@immutable
class ImportBookDraft {
  const ImportBookDraft({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.shelf,
    required this.sourcePath,
  });

  final String id;
  final String title;
  final String author;
  final String format;
  final String shelf;
  final String sourcePath;

  @override
  bool operator ==(Object other) =>
      other is ImportBookDraft &&
      other.id == id &&
      other.title == title &&
      other.format == format &&
      other.sourcePath == sourcePath;

  @override
  int get hashCode => Object.hash(id, title, format, sourcePath);
}

/// 提交结果：`added` 会写回内存书库；`deferred` 是需要真实数据库能力才能落地的决策。
@immutable
class ImportCommit {
  const ImportCommit({
    required this.added,
    required this.deferred,
    required this.skipped,
    required this.unsupported,
    required this.conflictCount,
    required this.totalCandidates,
  });

  final List<ImportBookDraft> added;
  final List<ImportConflict> deferred;
  final int skipped;
  final int unsupported;
  final int conflictCount;
  final int totalCandidates;

  int get addedCount => added.length;
  int get deferredCount => deferred.length;
  bool get isEmpty => added.isEmpty && deferred.isEmpty;
}

class ImportScanner {
  const ImportScanner._();

  /// 静态阶段无法读文件头，只能按路径里的显式标记识别 RAR5 / 加密包；
  /// 真实判定在 `ParserRouter.parse()` 里按字节签名完成（❄️ 冻结）。
  static const List<String> rar5Markers = <String>['rar5'];
  static const List<String> encryptedMarkers = <String>[
    '加密',
    '密码',
    'encrypted',
    'password',
    'protected',
  ];

  static String normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[_\-（）()]'), '');

  static String stem(String path) {
    final String name = path.split(RegExp(r'[/\\]')).last;
    final int dot = name.lastIndexOf('.');
    return dot < 0 ? name : name.substring(0, dot);
  }

  static ScanReport scan(Iterable<String> rawPaths) {
    // 去重 + 自然排序：001 / 002 / 010 不被字典序打乱。
    final List<String> paths = rawPaths.toSet().toList()
      ..sort(LibraryQuery.naturalCompare);

    final List<ImportCandidate> out = <ImportCandidate>[];
    for (final String path in paths) {
      final String lower = path.toLowerCase();
      final String format = ParserRouter.extOf(path).toUpperCase();
      final FormatRoute route = ParserRouter.routeForPath(path);
      final String title = stem(path).trim();

      CandidateStatus status;
      String reason = '';
      if (_matches(lower, rar5Markers)) {
        status = CandidateStatus.rejected;
        reason = LegalTexts.importRar5Reason;
      } else if (_matches(lower, encryptedMarkers)) {
        status = CandidateStatus.rejected;
        reason = LegalTexts.importEncryptedReason;
      } else if (route.route == RenderRoute.unsupported) {
        status = CandidateStatus.unsupported;
        reason = LegalTexts.importUnsupportedReason;
      } else {
        status = CandidateStatus.accepted;
        reason = route.note;
      }

      out.add(ImportCandidate(
        path: path,
        title: title,
        format: format.isEmpty ? '未知' : format,
        route: route.route,
        status: status,
        reason: reason,
      ));
    }
    return ScanReport(List<ImportCandidate>.unmodifiable(out));
  }

  static bool _matches(String lower, List<String> markers) {
    for (final String m in markers) {
      if (lower.contains(m)) return true;
    }
    return false;
  }

  /// 只对 **可导入** 的候选做同名冲突比对；被拒的项不占用决策名额。
  static List<ImportConflict> conflicts(
    ScanReport report,
    Iterable<ExistingBook> existing,
  ) {
    final Map<String, ExistingBook> index = <String, ExistingBook>{};
    for (final ExistingBook b in existing) {
      index.putIfAbsent(normalize(b.title), () => b);
    }
    final List<ImportConflict> out = <ImportConflict>[];
    for (final ImportCandidate c in report.accepted) {
      final ExistingBook? hit = index[normalize(c.title)];
      if (hit != null) {
        out.add(ImportConflict(candidate: c, existing: hit));
      }
    }
    return List<ImportConflict>.unmodifiable(out);
  }
}

/// 演示路径：故意覆盖可重排文本、原生栅格化、未知格式、RAR5、加密包、
/// 以及与演示书库同名的一本（触发冲突页）。静态阶段这些只是字符串。
class ImportDemoPaths {
  const ImportDemoPaths._();

  static const List<String> base = <String>[
    '/本地书籍/雨街短篇集.txt',
    '/本地书籍/纸白纪事.epub',
    '/本地书籍/夏汐来信.md',
    '/本地书籍/校勘笔记.docx',
    '/本地书籍/海边的目录.pdf',
    '/本地书籍/雨街漫画志.cbz',
    '/本地书籍/旧刊合辑.cbr',
    '/本地书籍/雪国的旅行者.txt', // 与演示书库同名 → 冲突
    '/本地书籍/归档_rar5.cbz', // 文件名标记 RAR5
    '/本地书籍/加密备份.zip', // 文件名标记加密包
    '/本地书籍/未知格式.xyz',
  ];

  static const List<String> cloud = <String>[
    '/OneDrive/云端摘录.txt',
    '/Google Drive/旅行手账.epub',
  ];

  static List<String> forMode(ImportPermissionMode mode) {
    switch (mode) {
      case ImportPermissionMode.saf:
        return List<String>.unmodifiable(base);
      case ImportPermissionMode.allFiles:
        return List<String>.unmodifiable(<String>[
          ...base,
          '/sdcard/Download/公共目录扫描.txt',
        ]);
      case ImportPermissionMode.documentPicker:
        return List<String>.unmodifiable(<String>[
          ...base,
          ...cloud,
        ]);
    }
  }
}

/// 不可变步骤状态机。`copyWith` 的清空条件一律用显式 `clear*` 开关，
/// 不让 `null` 同时表示「没传」与「清空」（第十轮起钉死的口径）。
@immutable
class ImportSession {
  const ImportSession({
    this.step = ImportStep.intro,
    this.mode,
    this.granted = false,
    this.report,
    this.conflicts = const <ImportConflict>[],
    this.committed = false,
  });

  final ImportStep step;
  final ImportPermissionMode? mode;
  final bool granted;
  final ScanReport? report;
  final List<ImportConflict> conflicts;
  final bool committed;

  int get stepIndex => ImportStep.values.indexOf(step);
  bool get isFirst => step == ImportStep.intro;
  bool get isLast => step == ImportStep.done;

  int get unresolvedCount =>
      conflicts.where((ImportConflict c) => !c.resolved).length;

  bool get canAdvance {
    switch (step) {
      case ImportStep.intro:
        return true;
      case ImportStep.permission:
        return mode != null && granted;
      case ImportStep.scan:
        return report != null && report!.acceptedCount > 0;
      case ImportStep.conflicts:
        return unresolvedCount == 0;
      case ImportStep.done:
        return false;
    }
  }

  /// 按钮禁用时给一句可执行的引导，不写「无法继续」这种空话。
  String get blockingHint {
    switch (step) {
      case ImportStep.permission:
        if (mode == null) return LegalTexts.importNoModeHint;
        return LegalTexts.importNoGrantHint;
      case ImportStep.scan:
        if (report == null || report!.isEmpty)
          return LegalTexts.importScanEmpty;
        return LegalTexts.importNoAcceptedHint;
      case ImportStep.conflicts:
        return '还有 $unresolvedCount 项冲突没有选择处理方式';
      case ImportStep.intro:
      case ImportStep.done:
        return '';
    }
  }

  ImportSession copyWith({
    ImportStep? step,
    ImportPermissionMode? mode,
    bool? granted,
    ScanReport? report,
    List<ImportConflict>? conflicts,
    bool? committed,
    bool clearReport = false,
    bool clearConflicts = false,
  }) =>
      ImportSession(
        step: step ?? this.step,
        mode: mode ?? this.mode,
        granted: granted ?? this.granted,
        report: clearReport ? null : (report ?? this.report),
        conflicts: clearConflicts
            ? const <ImportConflict>[]
            : (conflicts ?? this.conflicts),
        committed: committed ?? this.committed,
      );

  /// 换授权方式会**清空扫描结果与冲突决策**，避免「换了方式却还显示旧结果」。
  ImportSession chooseMode(ImportPermissionMode next) {
    if (mode == next && granted) return this;
    return copyWith(
      mode: next,
      granted: false,
      clearReport: true,
      clearConflicts: true,
      committed: false,
    );
  }

  ImportSession grant() {
    if (mode == null || granted) return this;
    return copyWith(granted: true, clearReport: true, clearConflicts: true);
  }

  /// 从「授权」推进到「扫描」时一次性算好报告与冲突，后续步骤只读这两份结果。
  ImportSession advance({required List<ExistingBook> existing}) {
    if (!canAdvance) return this;
    switch (step) {
      case ImportStep.intro:
        return copyWith(step: ImportStep.permission);
      case ImportStep.permission:
        final ScanReport scanned =
            ImportScanner.scan(ImportDemoPaths.forMode(mode!));
        return copyWith(
          step: ImportStep.scan,
          report: scanned,
          conflicts: ImportScanner.conflicts(scanned, existing),
        );
      case ImportStep.scan:
        return copyWith(step: ImportStep.conflicts);
      case ImportStep.conflicts:
        return copyWith(step: ImportStep.done);
      case ImportStep.done:
        return this;
    }
  }

  /// 回退到授权页时清空扫描结果；从冲突页回扫描页则保留报告与决策，方便复查。
  ImportSession back() {
    switch (step) {
      case ImportStep.intro:
        return this;
      case ImportStep.permission:
        return copyWith(step: ImportStep.intro);
      case ImportStep.scan:
        return copyWith(
          step: ImportStep.permission,
          clearReport: true,
          clearConflicts: true,
        );
      case ImportStep.conflicts:
        return copyWith(step: ImportStep.scan);
      case ImportStep.done:
        return copyWith(step: ImportStep.conflicts);
    }
  }

  ImportSession resolve(int index, ConflictResolution resolution) {
    if (index < 0 || index >= conflicts.length) return this;
    final List<ImportConflict> next = List<ImportConflict>.of(conflicts);
    next[index] = next[index].withResolution(resolution);
    return copyWith(conflicts: List<ImportConflict>.unmodifiable(next));
  }

  /// 批量应用后仍允许单条覆盖，不会被批量结果锁死。
  ImportSession resolveAll(ConflictResolution resolution) => copyWith(
        conflicts: List<ImportConflict>.unmodifiable(
          conflicts.map((ImportConflict c) => c.withResolution(resolution)),
        ),
      );

  /// 生成提交摘要。演示书库只读：replace / mergeRecords 不改写它，只进 deferred。
  ImportCommit commit({Set<String> existingIds = const <String>{}}) {
    final ScanReport? r = report;
    if (r == null) {
      return const ImportCommit(
        added: <ImportBookDraft>[],
        deferred: <ImportConflict>[],
        skipped: 0,
        unsupported: 0,
        conflictCount: 0,
        totalCandidates: 0,
      );
    }

    final Map<String, ConflictResolution> decisions =
        <String, ConflictResolution>{};
    final List<ImportConflict> deferred = <ImportConflict>[];
    for (final ImportConflict c in conflicts) {
      final ConflictResolution d = c.resolution ?? ConflictResolution.skip;
      decisions[c.candidate.path] = d;
      if (d == ConflictResolution.replace ||
          d == ConflictResolution.mergeRecords) {
        deferred.add(c);
      }
    }

    final List<ImportBookDraft> added = <ImportBookDraft>[];
    int skipped = 0;
    for (final ImportCandidate c in r.accepted) {
      final ConflictResolution? d = decisions[c.path];
      if (d == ConflictResolution.skip ||
          d == ConflictResolution.replace ||
          d == ConflictResolution.mergeRecords) {
        skipped++;
        continue;
      }
      final bool keepBoth = d == ConflictResolution.keepBoth;
      final String id = keepBoth ? '${c.draftId}-copy' : c.draftId;
      if (existingIds.contains(id) ||
          added.any((ImportBookDraft a) => a.id == id)) {
        skipped++;
        continue;
      }
      added.add(ImportBookDraft(
        id: id,
        title: keepBoth ? '${c.title}（导入副本）' : c.title,
        author: '本地导入',
        format: c.format,
        shelf: '本地书库',
        sourcePath: c.path,
      ));
    }

    return ImportCommit(
      added: List<ImportBookDraft>.unmodifiable(added),
      deferred: List<ImportConflict>.unmodifiable(deferred),
      skipped: skipped,
      unsupported: r.rejectedCount + r.unsupportedCount,
      conflictCount: conflicts.length,
      totalCandidates: r.total,
    );
  }

  ImportSession markCommitted() => copyWith(committed: true);
}
