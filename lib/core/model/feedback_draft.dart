import 'package:flutter/foundation.dart';

import '../../l10n/legal_texts.dart';
import 'wenku/wenku8_compliance.dart';

/// 问题反馈草稿（第二十二轮，对齐参考仓库 README）。
///
/// README 要求「反馈需带应用版本 / 设备 / 操作系统版本 / 复现步骤」，
/// 并明确「Issue 里绝不包含密码、Cookie 或 Token」。所以草稿模型把这两条
/// 写成可执行约束：字段齐全才可生成预览，生成前一律过 `Wenku8Compliance.redact()`。
///
/// **静态边界**：只生成纯文本字符串供应用内复制，不上传、不打开 Issue 页面、
/// 不写文件、不引入 `dart:io`。
@immutable
class FeedbackDraft {
  const FeedbackDraft({
    this.appVersion = '',
    this.device = '',
    this.osVersion = '',
    this.steps = '',
    this.details = '',
  });

  final String appVersion;
  final String device;
  final String osVersion;
  final String steps;
  final String details;

  static const List<String> requiredFieldLabels = <String>[
    '应用版本',
    '设备',
    '操作系统版本',
    '复现步骤',
  ];

  FeedbackDraft copyWith({
    String? appVersion,
    String? device,
    String? osVersion,
    String? steps,
    String? details,
  }) =>
      FeedbackDraft(
        appVersion: appVersion ?? this.appVersion,
        device: device ?? this.device,
        osVersion: osVersion ?? this.osVersion,
        steps: steps ?? this.steps,
        details: details ?? this.details,
      );

  bool get isComplete => appVersion.trim().isNotEmpty &&
      device.trim().isNotEmpty &&
      osVersion.trim().isNotEmpty &&
      steps.trim().isNotEmpty;

  List<String> get missingFields {
    final List<String> out = <String>[];
    if (appVersion.trim().isEmpty) out.add('应用版本');
    if (device.trim().isEmpty) out.add('设备');
    if (osVersion.trim().isEmpty) out.add('操作系统版本');
    if (steps.trim().isEmpty) out.add('复现步骤');
    return List<String>.unmodifiable(out);
  }

  /// 脱敏后的纯文本预览。空字段也列出，方便用户直接补全。
  String toPlainText() {
    final StringBuffer b = StringBuffer()
      ..writeln(LegalTexts.feedbackPreviewTitle)
      ..writeln('应用版本：${appVersion.trim().isEmpty ? '（待填写）' : appVersion.trim()}')
      ..writeln('设备：${device.trim().isEmpty ? '（待填写）' : device.trim()}')
      ..writeln('操作系统版本：${osVersion.trim().isEmpty ? '（待填写）' : osVersion.trim()}')
      ..writeln('复现步骤：${steps.trim().isEmpty ? '（待填写）' : steps.trim()}');
    if (details.trim().isNotEmpty) b.writeln('补充说明：${details.trim()}');
    return Wenku8Compliance.redact(b.toString());
  }

  /// 供自检 / 单测：原始文本里若出现凭据，脱敏后必须不再出现。
  bool get needsRedaction => Wenku8Compliance.containsCredential(
        '$appVersion $device $osVersion $steps $details',
      );

  @override
  bool operator ==(Object other) =>
      other is FeedbackDraft &&
      other.appVersion == appVersion &&
      other.device == device &&
      other.osVersion == osVersion &&
      other.steps == steps &&
      other.details == details;

  @override
  int get hashCode => Object.hash(appVersion, device, osVersion, steps, details);
}
