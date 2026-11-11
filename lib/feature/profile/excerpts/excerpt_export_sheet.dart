import 'package:flutter/material.dart';

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
