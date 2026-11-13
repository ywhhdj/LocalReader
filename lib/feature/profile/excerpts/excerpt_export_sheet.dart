import 'dart:async';

import 'package:flutter/material.dart';

import '../../../assembly/app_services.dart';
import '../../../core/model/stats/excerpt_query.dart';
import '../../../core/model/stats/reading_stats.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/components/glass/Nav.dart';
import '../../../l10n/lr_localizations.dart';

/// 导出预览：把当前筛选结果生成纯文本，用 `SelectableText` 供用户自行复制。
class ExcerptExportSheet extends StatelessWidget {
  const ExcerptExportSheet({
    super.key,
    required this.excerpts,
    required this.filterDescription,
  });

  final List<Excerpt> excerpts;
  final String filterDescription;

  static Future<void> open(
    BuildContext context, {
    required List<Excerpt> excerpts,
    required String filterDescription,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ExcerptExportSheet(
        excerpts: excerpts,
        filterDescription: filterDescription,
      ),
    );
  }

  void _hint(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveLocal(BuildContext context, String plain) async {
    try {
      final String name =
          'excerpts-${DateTime.now().millisecondsSinceEpoch}.txt';
      final String? path =
          await AppServices.of(context).share.saveText(name, plain);
      _hint(context, path == null ? '未返回保存路径' : '已保存到 $path');
    } catch (e) {
      _hint(context, '保存失败：$e');
    }
  }

  Future<void> _share(BuildContext context, String plain) async {
    try {
      await AppServices.of(context).share.shareText(plain);
    } catch (e) {
      _hint(context, '分享失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String plain = ExcerptExporter.toPlainText(excerpts);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(
          LrSpacing.l, LrSpacing.l, LrSpacing.l, LrSpacing.xl),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.84),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(context.t('uiExportPreview'),
                      style: text.headlineMedium),
                  const Spacer(),
                  Text(context.tArgs('uiItems2', <Object?>[excerpts.length]),
                      style: text.labelSmall),
                ],
              ),
              const SizedBox(height: LrSpacing.xs),
              Text(filterDescription, style: text.labelSmall),
              const SizedBox(height: LrSpacing.m),
              GlassPanel(
                child: SizedBox(
                  width: double.infinity,
                  child: SelectableText(
                    plain,
                    style: text.bodySmall?.copyWith(height: 1.75),
                  ),
                ),
              ),
              const SizedBox(height: LrSpacing.m),
              // 此前只有「预览 + 手动复制」，导出按钮并不存在：
              // 现在接 PlatformShareBridge 真正写文件 / 拉起系统分享。
              Wrap(
                spacing: LrSpacing.xs,
                runSpacing: LrSpacing.xs,
                children: <Widget>[
                  FilledButton.tonal(
                    onPressed: () => unawaited(_saveLocal(context, plain)),
                    child: const Text('保存到本地'),
                  ),
                  OutlinedButton(
                    onPressed: () => unawaited(_share(context, plain)),
                    child: const Text('系统分享'),
                  ),
                ],
              ),
              const SizedBox(height: LrSpacing.m),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: LrSpacing.xs),
                  Expanded(
                      child: Text(context.t('excerptExportNote'),
                          style: text.bodySmall)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
