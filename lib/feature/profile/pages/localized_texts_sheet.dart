import 'package:flutter/material.dart';

import '../../../assembly/app_scope.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/components/glass.dart';
import '../../../l10n/localized_texts.dart';
import '../../../l10n/lr_localizations.dart';

/// 本地化资源预览面板：显示 ARB 的键数 / 模板数 / 待润色数，并预览合规句。
Future<void> showLocalizedTextsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => const LocalizedTextsSheet(),
    );

class LocalizedTextsSheet extends StatefulWidget {
  const LocalizedTextsSheet({super.key});

  @override
  State<LocalizedTextsSheet> createState() => _LocalizedTextsSheetState();
}

class _LocalizedTextsSheetState extends State<LocalizedTextsSheet> {
  /// 纯 UI 局部量：只影响预览，不影响应用界面。
  AppLanguage _preview = AppLanguage.zhCN;

  static const List<String> _previewKeys = <String>[
    'appDisclaimer',
    'freeStatement',
    'sources',
    'contentRights',
    'issueGuidance',
    'onlineEntryNote',
    'localOnlyNote',
    'screenshotNote',
    'localizationStaticNote',
  ];

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final Locale locale = _preview.locale;
    final LegalTextBundle bundle = LocalizedLegalTexts.of(locale);
    final List<String> missing = LocalizedLegalTexts.missingKeys(locale);
    final List<String> extra = LocalizedLegalTexts.extraKeys(locale);

    return GlassPanel(
      padding: EdgeInsets.fromLTRB(
        LrSpacing.l,
        LrSpacing.l,
        LrSpacing.l,
        LrSpacing.l + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(context.t('uiAppLanguage'), style: text.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<AppLanguage?>(
                segments: <ButtonSegment<AppLanguage?>>[
                  ButtonSegment<AppLanguage?>(
                      value: null, label: Text(context.t('uiFollowSystem'))),
                  ButtonSegment<AppLanguage?>(
                      value: AppLanguage.zhCN, label: Text(context.t('uiPhrase008'))),
                  ButtonSegment<AppLanguage?>(
                      value: AppLanguage.en, label: Text(context.t('uiEnglish'))),
                ],
                selected: <AppLanguage?>{state.settings.appLanguage},
                onSelectionChanged: (Set<AppLanguage?> v) {
                  state.setAppLanguage(v.first);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
              Text(
                context.t('uiWhenFollowingTheSystemFlutterResolvesTheLocale'),
                style: text.bodySmall,
              ),
              const Divider(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(context.t('localizationTitle'), style: text.headlineMedium),
                  ),
                  Text(
                    context.t('localizationDefaultNote'),
                    style: text.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: LrSpacing.s),
              Text(
                context.tArgs('uiKeysLists', <Object?>[LocalizedLegalTexts.keyCount, LocalizedLegalTexts.listCount]) +
                context.tArgs('uiArbStats', <Object?>[
                  LocalizedLegalTexts.placeholderKeyCount,
                  LocalizedLegalTexts.reviewKeyCount,
                ]),
                style: text.labelSmall,
              ),
              const SizedBox(height: LrSpacing.m),

              // 语言切换只作用于预览
              Wrap(
                spacing: LrSpacing.s,
                children: <Widget>[
                  for (final AppLanguage l in AppLanguage.values)
                    ChoiceChip(
                      label: Text(l.label, style: text.labelLarge),
                      selected: _preview == l,
                      onSelected: (bool _) => setState(() => _preview = l),
                    ),
                ],
              ),
              const SizedBox(height: LrSpacing.m),

              // 覆盖度：缺项 / 多余 / 段落条数对齐
              GlassPanel(
                padding: const EdgeInsets.all(LrSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(context.tArgs('uiCoverageCheck', <Object?>[_preview.label]), style: text.titleMedium),
                    const SizedBox(height: LrSpacing.s),
                    Text(
                      context.tArgs('uiItems', <Object?>[missing.length, extra.length]) +
                      context.tArgs('uiAboutParagraphsItems', <Object?>[bundle.list('aboutParagraphs').length]) +
                      context.tArgs('uiPhrase013', <Object?>[LocalizedLegalTexts.paragraphsAligned() ? lrText('uiAligned') : lrText('uiMisaligned')]),
                      style: text.bodySmall,
                    ),
                    if (missing.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: LrSpacing.s),
                        child: Text(context.tArgs('uiPhrase001', <Object?>[missing.join('、')]), style: text.labelSmall),
                      ),
                    if (extra.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: LrSpacing.s),
                        child: Text(context.tArgs('uiPhrase000', <Object?>[extra.join('、')]), style: text.labelSmall),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: LrSpacing.m),

              Text(context.t('localizationPreviewTitle'), style: text.titleMedium),
              const SizedBox(height: LrSpacing.s),
              ..._previewKeys.map<Widget>(
                (String key) => Padding(
                  padding: const EdgeInsets.only(bottom: LrSpacing.s),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(LrSpacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(key, style: text.labelSmall),
                        const SizedBox(height: LrSpacing.xs),
                        Text(bundle.value(key), style: text.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: LrSpacing.s),
              Text(context.t('localizationStaticNote'), style: text.bodySmall),
              const SizedBox(height: LrSpacing.xs),
              Text(context.t('demoDataNote'), style: text.labelSmall),
              const SizedBox(height: LrSpacing.xs),
              Text(context.t('uiArbSourceNote'), style: text.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
