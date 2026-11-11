// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖
// 合并状态 E13：已落入工程路径 lib/domain/usecases/scan_result.dart；同名类型已隔离；未编译 / 未运行 / 未下载依赖。
// 设计源：scaffold/scan_result.dart（交付包内保留，作为规格基线）
// 建议落点：lib/domain/usecases/scan_result.dart
// 对应需求：R13 扫描格式选择 / 选择扫描范围 / 返回文件按原项目结构 / 格式 <number>
// 对齐：docs/08 §8.5；纯 Dart。

/// 扫描格式：全部 + 常见格式（对齐 main README 支持格式表）。
enum ScanFormat {
  all, epub, txt, pdf, zip, cbz, cbr, html, md, docx, rtf, fb2, mobi,
}

const Map<ScanFormat, String> kScanFormatExt = <ScanFormat, String>{
  ScanFormat.all: '',
  ScanFormat.epub: '.epub',
  ScanFormat.txt: '.txt',
  ScanFormat.pdf: '.pdf',
  ScanFormat.zip: '.zip',
  ScanFormat.cbz: '.cbz',
  ScanFormat.cbr: '.cbr',
  ScanFormat.html: '.html',
  ScanFormat.md: '.md',
  ScanFormat.docx: '.docx',
  ScanFormat.rtf: '.rtf',
  ScanFormat.fb2: '.fb2',
  ScanFormat.mobi: '.mobi',
};

String formatOfPath(String path) {
  final String lower = path.toLowerCase();
  for (final MapEntry<ScanFormat, String> e in kScanFormatExt.entries) {
    if (e.value.isNotEmpty && lower.endsWith(e.value)) return e.key.name;
  }
  return 'other';
}

/// 扫描范围：SAF 授权目录 / 指定文件夹 / 全盘（需 MANAGE_EXTERNAL_STORAGE）/ 上次范围。
enum ScanScope { safDirectory, chosenFolder, allStorage, lastUsed }

class ScanFile {
  const ScanFile({
    required this.id,
    required this.name,
    required this.format,
    required this.path,
    required this.parentPath,
    this.sizeBytes = 0,
    this.groupId = '',
  });

  /// 懒加载列表三列：名字 / 格式 / 路径。
  final String name;
  final String format;
  final String path;
  final String parentPath;
  final int sizeBytes;
  final String groupId;
  final String id;
}

/// 扫描批次：结果按原项目结构（目录层级）组织，不摊平成无层级列表。
class ScanBatch {
  const ScanBatch({
    required this.id,
    required this.roots,
    required this.scope,
    required this.formats,
    required this.files,
    this.scannedAt = 0,
  });

  final String id;
  final List<String> roots;
  final ScanScope scope;
  final Set<ScanFormat> formats;
  final List<ScanFile> files;
  final int scannedAt;

  /// 按 parentPath 分组 = 原项目目录结构。
  Map<String, List<ScanFile>> treeByDirectory() {
    final Map<String, List<ScanFile>> out = <String, List<ScanFile>>{};
    for (final ScanFile f in files) {
      out.putIfAbsent(f.parentPath, () => <ScanFile>[]).add(f);
    }
    return out;
  }

  List<ScanFile> filterByFormat(ScanFormat format) => format == ScanFormat.all
      ? files
      : files.where((ScanFile f) => f.format == format.name).toList();
}

/// 「全部格式」+「格式 <number>」分面：数字是命中文件数，不是页数。
class FormatFacet {
  const FormatFacet({required this.format, required this.count, this.label = ''});

  final ScanFormat format;
  final int count;
  final String label;

  String get display => format == ScanFormat.all
      ? '全部格式'
      : '${format.name.toUpperCase()} $count';

  static List<FormatFacet> of(List<ScanFile> files) {
    final Map<String, int> counts = <String, int>{};
    for (final ScanFile f in files) {
      counts[f.format] = (counts[f.format] ?? 0) + 1;
    }
    final List<FormatFacet> out = <FormatFacet>[
      FormatFacet(format: ScanFormat.all, count: files.length),
    ];
    for (final ScanFormat fmt in ScanFormat.values) {
      if (fmt == ScanFormat.all) continue;
      final int n = counts[fmt.name] ?? 0;
      if (n > 0) out.add(FormatFacet(format: fmt, count: n));
    }
    return List<FormatFacet>.unmodifiable(out);
  }
}

/// 扫描页从上往下：格式选择 → 选择扫描范围。
class ScanFolderSpec {
  const ScanFolderSpec({
    this.formats = const <ScanFormat>{ScanFormat.all},
    this.scope = ScanScope.safDirectory,
    this.roots = const <String>[],
  });

  final Set<ScanFormat> formats;
  final ScanScope scope;
  final List<String> roots;

  bool get isAllFormats =>
      formats.isEmpty || formats.contains(ScanFormat.all);

  ScanFolderSpec normalized() => ScanFolderSpec(
        formats: isAllFormats ? const <ScanFormat>{ScanFormat.all} : formats,
        scope: scope,
        roots: roots,
      );

  ScanFolderSpec copyWith({
    Set<ScanFormat>? formats,
    ScanScope? scope,
    List<String>? roots,
  }) =>
      ScanFolderSpec(
        formats: formats ?? this.formats,
        scope: scope ?? this.scope,
        roots: roots ?? this.roots,
      ).normalized();
}
