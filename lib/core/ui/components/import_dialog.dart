import 'package:flutter/material.dart';

import '../../../l10n/lr_localizations.dart';

/// 导入说明弹窗放在 core 层：书架页、文库页、搜索结果页共用同一份文案与交互，
/// 不会形成 feature → feature 的反向依赖（静态自检强制）。
///
/// `onOpenWizard` 由 app 层注入：弹窗只负责「快速说明 + 跳转」，不构造路由，
/// 完整的多步骤流程在 `/import` 页面里。静态交付模式下不调用任何平台能力。
Future<void> showImportDialog(
  BuildContext context, {
  VoidCallback? onOpenWizard,
}) =>
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(lrText('importTitle')),
        content: SingleChildScrollView(
          child: Text(
            '${lrText('importBody')}\n\n${lrText('importWizardStaticNote')}',
          ),
        ),
        actions: <Widget>[
          if (onOpenWizard != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onOpenWizard();
              },
              child: Text(lrText('importWizardEntry')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lrText('uiGotIt')),
          ),
        ],
      ),
    );
