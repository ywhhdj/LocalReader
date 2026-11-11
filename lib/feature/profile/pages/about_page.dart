import 'package:Local_reader/core/ui/components/glass/Page.dart';
import 'package:flutter/material.dart';

import '../../../core/model/wenku/wenku8_compliance.dart';
import '../../../l10n/lr_localizations.dart';
import '../../../core/ui/components/section_card.dart';
import '../../../core/common/design_tokens.dart';

/// 关于页
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> paragraphs = context.tList('aboutParagraphs');
    final List<String> notes = <String>[
      context.t('importFormats'),
      context.t('archiveNotice'),
      context.t('permissionNotice'),
      context.t('importChannels'),
      context.t('localOnlyNote'),
      context.t('onlineEntryNote'),
      context.t('thirdPartyService'),
      context.t('issueGuidance'),
      context.t('importWizardStaticNote'),
    ];
    return LrPage.builder(
      header: PageScrollHeader(
        title: context.t('mineAboutTitle'),
        subtitle: context.t('mineAboutSubtitle'),
      ),
      itemCount: 4,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return SectionCard(
            title: context.t('aboutVersionTitle'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(context.t('mineAboutSubtitle'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: LrSpacing.xs),
                Text(context.t('nonOfficial'),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }
        if (index == 1) {
          return SectionCard(
            title: context.t('aboutAllNotesTitle'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final String paragraph in paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LrSpacing.xs),
                    child: Text(paragraph,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          );
        }
        if (index == 2) {
          return SectionCard(
            title: context.t('aboutPromptsTitle'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final String note in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LrSpacing.xs),
                    child: Text('· $note',
                        style: Theme.of(context).textTheme.labelSmall),
                  ),
              ],
            ),
          );
        }
        return SectionCard(
          title: context.t('aboutStaticTitle'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(context.t('appDisclaimer'),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: LrSpacing.xs),
              Text(context.t('contentRights'),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: LrSpacing.xs),
              for (final String rule in Wenku8Compliance.rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('· $rule',
                      style: Theme.of(context).textTheme.labelSmall),
                ),
            ],
          ),
        );
      },
    );
  }
}
