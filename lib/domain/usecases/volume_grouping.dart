// 设计骨架 · 本轮未编译 / 未运行 / 未下载依赖
// 合并状态 E13：已落入工程路径 lib/domain/usecases/volume_grouping.dart；同名类型已隔离；未编译 / 未运行 / 未下载依赖。
// 设计源：scaffold/volume_grouping.dart（交付包内保留，作为规格基线）
// 建议落点：lib/domain/usecases/volume_grouping.dart
// 对应需求：R13「检测到同样的书（丰收 第一卷.epub / 丰收第二卷.epub）进行合并」
// 对齐：参考仓库 README「confirm how volumes in the same series should be merged」
//       docs/08 §8.4；纯 Dart。
//
// 红线：只做「文件 → 卷组」的分组与命名，不搬动、不复制、不改写原文件；
//       真实导入由解禁后的 SAF/文件系统流程执行。

import 'package:Local_reader/domain/usecases/scan_result.dart';

/// 合并后的书籍：合并页展示的就是它，而不是散文件。
class VolumeGroup {
  const VolumeGroup({
    required this.id,
    required this.normalizedTitle,
    required this.displayTitle,
    required this.files,
    this.volumeCount = 0,
    this.mergedBookId = '',
  });

  final String id;
  final String normalizedTitle;
  final String displayTitle;

  /// 组内原始文件（名字 / 格式 / 路径），用户可逐个勾选导入。
  final List<ScanFile> files;
  final int volumeCount;
  final String mergedBookId;

  bool get isMultiVolume => files.length > 1;
}

const Map<String, int> kCnDigits = <String, int>{
  '零': 0, '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
  '六': 6, '七': 7, '八': 8, '九': 9, '两': 2,
};

class VolumeGroupingEngine {
  const VolumeGroupingEngine();

  /// 书名归一化：去扩展名、去卷号短语、去空白与常见分隔符、转小写。
  /// 「丰收 第一卷」「丰收第二卷」「Harvest Vol.1」都应归到同一键。
  String normalize(String fileName) {
    String s = fileName;
    final int dot = s.lastIndexOf('.');
    if (dot > 0) s = s.substring(0, dot);
    s = s.replaceAll(
      RegExp(r'(第[零一二三四五六七八九十百千万两\d]+[卷部册集篇]|'
          r'[Vv]ol(?:ume)?\.?\s*\d+|'
          r'\(?\s*\d+\s*\)?\s*$|'
          r'【[^】]*】|\[[^\]]*\]|'
          r'[_－—\-–]+)'),
      '',
    );
    s = s.replaceAll(RegExp(r'\s+'), '');
    return s.toLowerCase();
  }

  /// 卷号识别：中文数字 / 阿拉伯数字 / Vol.N。解析失败返回 0（按文件名排序兜底）。
  int volumeNo(String fileName) {
    final String s = fileName;
    final RegExp cn = RegExp(r'第([零一二三四五六七八九十百千万两]+)[卷部册集篇]');
    final Match? m = cn.firstMatch(s);
    if (m != null) return _parseCn(m.group(1)!);
    final Match? ar = RegExp(r'第(\d+)[卷部册集篇]').firstMatch(s);
    if (ar != null) return int.tryParse(ar.group(1)!) ?? 0;
    final Match? vol = RegExp(r'[Vv]ol(?:ume)?\.?\s*(\d+)').firstMatch(s);
    if (vol != null) return int.tryParse(vol.group(1)!) ?? 0;
    final Match? tail = RegExp(r'(\d+)\s*(?:\.|$|\))').firstMatch(s);
    return tail != null ? (int.tryParse(tail.group(1)!) ?? 0) : 0;
  }

  int _parseCn(String raw) {
    if (RegExp(r'^\d+$').hasMatch(raw)) return int.parse(raw);
    int total = 0;
    int section = 0;
    int number = 0;
    for (final String ch in raw.split('')) {
      final int? d = kCnDigits[ch];
      if (d != null) {
        number = d;
        continue;
      }
      if (ch == '十') {
        section += (number == 0 ? 1 : number) * 10;
        number = 0;
      } else if (ch == '百') {
        section += (number == 0 ? 1 : number) * 100;
        number = 0;
      } else if (ch == '千') {
        section += (number == 0 ? 1 : number) * 1000;
        number = 0;
      } else if (ch == '万') {
        total += (section + number) * 10000;
        section = 0;
        number = 0;
      }
    }
    return total + section + number;
  }

  /// 分组 → 组内按卷号排序 → 生成合并后的展示标题。
  List<VolumeGroup> group(List<ScanFile> files) {
    final Map<String, List<ScanFile>> buckets = <String, List<ScanFile>>{};
    for (final ScanFile f in files) {
      buckets.putIfAbsent(normalize(f.name), () => <ScanFile>[]).add(f);
    }
    final List<VolumeGroup> out = <VolumeGroup>[];
    for (final MapEntry<String, List<ScanFile>> e in buckets.entries) {
      final List<ScanFile> sorted = List<ScanFile>.from(e.value)
        ..sort((ScanFile a, ScanFile b) {
          final int va = volumeNo(a.name);
          final int vb = volumeNo(b.name);
          return va == vb ? a.name.compareTo(b.name) : va.compareTo(vb);
        });
      out.add(VolumeGroup(
        id: 'vg-${e.key.hashCode.abs()}',
        normalizedTitle: e.key,
        displayTitle: _displayTitle(sorted),
        files: List<ScanFile>.unmodifiable(sorted),
        volumeCount: sorted.length,
        mergedBookId: 'merged-${e.key.hashCode.abs()}',
      ));
    }
    out.sort((VolumeGroup a, VolumeGroup b) =>
        a.displayTitle.compareTo(b.displayTitle));
    return List<VolumeGroup>.unmodifiable(out);
  }

  String _displayTitle(List<ScanFile> files) {
    final String first = files.isEmpty ? '' : files.first.name;
    final int dot = first.lastIndexOf('.');
    final String base = dot > 0 ? first.substring(0, dot) : first;
    final String cleaned = base.replaceAll(
        RegExp(r'(第[零一二三四五六七八九十百千万两\d]+[卷部册集篇]|'
            r'[Vv]ol(?:ume)?\.?\s*\d+|\s*\d+\s*$)'),
        '').trim();
    return cleaned.isEmpty ? base.trim() : cleaned;
  }
}
