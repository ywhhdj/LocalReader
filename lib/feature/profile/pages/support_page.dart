import 'package:flutter/material.dart';

import '../../../l10n/lr_localizations.dart';
import '../../../core/ui/components/page_scaffold.dart';
import '../../../core/ui/components/page_scroll_header.dart';
import '../../../core/ui/components/section_card.dart';
import '../../../core/common/design_tokens.dart';
import 'feedback_sheet.dart';

/// 赞助与反馈页
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) => LrPage.builder(
        header: PageScrollHeader(
          title: context.t('mineSupportTitle'),
          subtitle: context.t('mineSupportSubtitle'),
        ),
        itemCount: 3,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return SectionCard(
              title: context.t('supportTitle'),
              child: Text(context.t('supportBody'),
                  style: Theme.of(context).textTheme.bodyMedium),
            );
          }
          if (index == 1) {
            return SectionCard(
              title: context.t('feedbackTitle'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(context.t('feedbackSubtitle'),
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: LrSpacing.m),
                  FilledButton.tonal(
                    onPressed: () => FeedbackSheet.open(context),
                    child: Text(context.t('feedbackTitle')),
                  ),
                ],
              ),
            );
          }
          return SectionCard(
            title: context.t('freeStatementTitle'),
            child: Text(context.t('freeStatement'),
                style: Theme.of(context).textTheme.bodySmall),
          );
        },
      );
}
