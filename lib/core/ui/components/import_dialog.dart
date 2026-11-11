import 'package:flutter/material.dart';

import '../../../l10n/lr_localizations.dart';

/// 导入说明弹窗放在 core 层：书架页、文库页、搜索结果页共用同一份文案与交互，
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
