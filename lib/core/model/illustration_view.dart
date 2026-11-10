import 'package:flutter/foundation.dart';

/// 插图 / 封面查看（第二十四轮）。
///
/// 参考仓库 README：「Pinch to zoom into covers and illustrations, or save the
/// original images.」「saving an image shows a brief confirmation.」
///
/// 静态阶段只做缩放状态与「保存确认」状态；**不读取像素、不写文件、不申请相册
/// 权限**。真实保存由平台层 `MediaStore / PhotoKit` 实现（❄️ 冻结）。
@immutable
class IllustrationZoom {
  const IllustrationZoom({
    this.scale = 1.0,
    this.minScale = 1.0,
    this.maxScale = 4.0,
  });

  final double scale;
  final double minScale;
  final double maxScale;

  IllustrationZoom pinch(double factor) => IllustrationZoom(
        scale: (scale * factor).clamp(minScale, maxScale).toDouble(),
        minScale: minScale,
        maxScale: maxScale,
      );

  IllustrationZoom reset() => IllustrationZoom(minScale: minScale, maxScale: maxScale);

  bool get isZoomed => scale > minScale + 0.01;
}

enum IllustrationSaveState { idle, saving, saved, failed, permissionDenied }

@immutable
class IllustrationSaveResult {
  const IllustrationSaveResult(this.state, {this.note = ''});

  final IllustrationSaveState state;
  final String note;

  /// 短暂确认文案：成功与失败都要给，静默成功等于「点了没反应」。
  String get confirmation {
    switch (state) {
      case IllustrationSaveState.idle:
        return '';
      case IllustrationSaveState.saving:
        return '正在保存原图…';
      case IllustrationSaveState.saved:
        return '原图已保存';
      case IllustrationSaveState.failed:
        return '保存失败，请稍后再试';
      case IllustrationSaveState.permissionDenied:
        return '没有保存权限，请到系统设置开启';
    }
  }

  bool get isDone =>
      state == IllustrationSaveState.saved ||
      state == IllustrationSaveState.failed ||
      state == IllustrationSaveState.permissionDenied;
}
