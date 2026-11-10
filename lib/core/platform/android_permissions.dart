import 'package:flutter/foundation.dart';

/// Android 权限分级（第二十四轮）。
///
/// 原项目 README 逐条：「Android 13+ 只申请 READ_MEDIA_IMAGES」「Android 12-
/// 使用 READ_EXTERNAL_STORAGE」「已移除 READ_MEDIA_AUDIO / READ_MEDIA_VIDEO /
/// POST_NOTIFICATIONS」「文档类书籍仍需走 SAF 或所有文件访问授权」。
///
/// 静态阶段只产出**清单**，不调用权限申请 API；真机接入时由平台层按 SDK 版本
/// 取 `requiredPermissions()`。第二十三轮 Manifest 只加了 INTERNET，这里补齐说明。
@immutable
class AndroidPermissionProfile {
  const AndroidPermissionProfile(this.sdkInt);

  final int sdkInt;

  static const String internet = 'android.permission.INTERNET';
  static const String readMediaImages = 'android.permission.READ_MEDIA_IMAGES';
  static const String readExternalStorage = 'android.permission.READ_EXTERNAL_STORAGE';
  static const String allFilesAccess = 'android.permission.MANAGE_EXTERNAL_STORAGE';

  /// 明确**不申请**的三项，作为可断言的清单而不是一句注释。
  static const List<String> removed = <String>[
    'android.permission.READ_MEDIA_AUDIO',
    'android.permission.READ_MEDIA_VIDEO',
    'android.permission.POST_NOTIFICATIONS',
  ];

  bool get isAndroid13Plus => sdkInt >= 33;

  /// 媒体权限按版本二选一，绝不两种同时申请。
  List<String> requiredPermissions() => <String>[
        internet,
        if (isAndroid13Plus) readMediaImages else readExternalStorage,
      ];

  /// 文档类书籍（EPUB/TXT/PDF）不在媒体库覆盖范围内，必须走 SAF。
  static const List<String> documentFormatsRequiringSaf = <String>[
    'EPUB', 'TXT', 'PDF',
  ];

  static const String safNote =
      '文档类书籍不在媒体库覆盖范围内，仍需通过系统文件选择器授权目录；'
      '授权会持久化，重启后可一键重扫。';

  static const String allFilesNote =
      '「所有文件访问权限」仅用于直接扫描公共目录，属于可选方式二。';

  bool requestsRemovedPermission(List<String> requested) =>
      requested.any((String p) => removed.contains(p));
}
