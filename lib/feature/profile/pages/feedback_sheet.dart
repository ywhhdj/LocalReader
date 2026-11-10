import 'package:flutter/material.dart';

import '../../../assembly/app_scope.dart';
import '../../../core/model/feedback_draft.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/components/glass.dart';
import '../../../l10n/lr_localizations.dart';

/// 问题反馈面板
class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({super.key});

  static Future<void> open(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: const FeedbackSheet(),
        ),
      );

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final TextEditingController _version = TextEditingController();
  final TextEditingController _device = TextEditingController();
  final TextEditingController _os = TextEditingController();
  final TextEditingController _steps = TextEditingController();
  final TextEditingController _details = TextEditingController();
  FeedbackDraft _draft = const FeedbackDraft();

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in _controllers) {
      c.addListener(_sync);
    }
  }

  List<TextEditingController> get _controllers =>
      <TextEditingController>[_version, _device, _os, _steps, _details];

  void _sync() {
    setState(() {
      _draft = FeedbackDraft(
        appVersion: _version.text,
        device: _device.text,
        osVersion: _os.text,
        steps: _steps.text,
        details: _details.text,
      );
    });
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppState state = AppScope.of(context);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(
          LrSpacing.l, LrSpacing.l, LrSpacing.l, LrSpacing.xl),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(context.t('feedbackTitle'), style: text.headlineMedium),
            const SizedBox(height: LrSpacing.xs),
            Text(context.t('feedbackSubtitle'), style: text.bodySmall),
            const SizedBox(height: LrSpacing.m),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  _field(context.t('uiAppVersion'), _version, context.t('uiEG1001'), text),
                  _field(context.t('uiDevice'), _device, context.t('uiEGPixel8'), text),
                  _field(context.t('uiOsVersion'), _os, context.t('uiEGAndroid15'), text),
                  _field(context.t('uiStepsToReproduce'), _steps, '1. … 2. …', text, maxLines: 3),
                  _field(context.t('uiAdditionalNotesOptional'), _details, context.t('uiOtherObservations'), text,
                      maxLines: 2),
                  const SizedBox(height: LrSpacing.s),
                  if (!_draft.isComplete)
                    Text(
                      '${context.t('feedbackMissing')}${_draft.missingFields.join('、')}',
                      style: text.labelSmall,
                    ),
                  const SizedBox(height: LrSpacing.m),
                  Text(context.t('feedbackPreviewTitle'), style: text.titleMedium),
                  const SizedBox(height: LrSpacing.s),
                  GlassPanel(
                    padding: const EdgeInsets.all(LrSpacing.m),
                    child: SelectableText(
                      _draft.toPlainText(),
                      style: text.bodySmall,
                    ),
                  ),
                  const SizedBox(height: LrSpacing.s),
                  Text(context.t('wenkuNoCredentials'), style: text.labelSmall),
                  const SizedBox(height: LrSpacing.xs),
                  Text(context.t('feedbackStaticNote'), style: text.labelSmall),
                  const SizedBox(height: LrSpacing.s),
                  Text(
                    context.tArgs('uiCurrentContents', <Object?>[context.t('freeStatement')]) +
                    context.tArgs('uiPhrase003', <Object?>[state.onlineEnabled ? lrText('uiEnabled') : lrText('uiDisabled')]),
                    style: text.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, String hint,
          TextTheme text,
          {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: LrSpacing.s),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            labelStyle: text.labelSmall,
            hintStyle: text.labelSmall,
            isDense: true,
          ),
          style: text.bodySmall,
        ),
      );
}
