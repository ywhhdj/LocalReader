import 'package:flutter/material.dart';

import '../../../core/model/tts_prefs.dart';
import '../../../l10n/lr_localizations.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/components/glass/Nav.dart';

/// 听读设置面板
/// 语速 / 音调写回 `ReaderStyle`；音色、发声人、自动下章是面板状态，
/// 由调用方决定是否持久化——组件不读 AppState、不构造路由。
class TtsSettingsPanel extends StatelessWidget {
  const TtsSettingsPanel({
    super.key,
    required this.rate,
    required this.pitch,
    required this.timbre,
    required this.autoNext,
    required this.voices,
    required this.voiceName,
    required this.onRate,
    required this.onPitch,
    required this.onTimbre,
    required this.onAutoNext,
    required this.onVoice,
    required this.onOpenSystemTts,
    required this.onDismiss,
    this.backgroundColor,
    this.contentColor,
  });

  final double rate;
  final double pitch;
  final TtsTimbre timbre;
  final bool autoNext;
  final List<String> voices;
  final String voiceName;
  final ValueChanged<double> onRate;
  final ValueChanged<double> onPitch;
  final ValueChanged<TtsTimbre> onTimbre;
  final ValueChanged<bool> onAutoNext;
  final ValueChanged<String> onVoice;
  final VoidCallback onOpenSystemTts;
  final VoidCallback onDismiss;
  final Color? backgroundColor;
  final Color? contentColor;

  String _timbreLabel(BuildContext context, TtsTimbre value) {
    if (value == TtsTimbre.soft) return context.t('readerTtsTimbreSoft');
    if (value == TtsTimbre.bright) return context.t('readerTtsTimbreBright');
    return context.t('readerTtsTimbreNormal');
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color fg = contentColor ?? Theme.of(context).colorScheme.onSurface;
    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.tune_outlined, size: 19, color: fg),
              const SizedBox(width: LrSpacing.xs),
              Expanded(
                  child: Text(context.t('readerTtsSettings'),
                      style: text.titleMedium?.copyWith(color: fg))),
              IconButton(
                  tooltip: context.t('uiClose'),
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, size: 18, color: fg)),
            ],
          ),
          const SizedBox(height: LrSpacing.xs),
          Text(context.t('readerTtsTimbre'),
              style: text.labelLarge?.copyWith(color: fg)),
          const SizedBox(height: LrSpacing.xs),
          Row(
            children: <Widget>[
              for (final TtsTimbre item in TtsTimbre.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: LrSpacing.xs),
                    child: ChoiceChip(
                      label: Text(_timbreLabel(context, item),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      selected: item == timbre,
                      onSelected: (bool _) => onTimbre(item),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: LrSpacing.xs),
          Text(context.t('readerTtsTimbreNote'),
              style:
                  text.labelSmall?.copyWith(color: fg.withValues(alpha: 0.7))),
          const SizedBox(height: LrSpacing.m),
          _LabeledSlider(
              label: context.t('readerTtsRate'),
              value: rate,
              min: 0.5,
              max: 2.0,
              contentColor: fg,
              onChanged: onRate),
          _LabeledSlider(
              label: context.t('readerTtsPitch'),
              value: pitch,
              min: 0.5,
              max: 2.0,
              contentColor: fg,
              onChanged: onPitch),
          const SizedBox(height: LrSpacing.xs),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: autoNext,
            onChanged: onAutoNext,
            title: Text(context.t('readerTtsAutoNext'),
                style: text.labelLarge?.copyWith(color: fg)),
          ),
          const SizedBox(height: LrSpacing.xs),
          Row(
            children: <Widget>[
              Text(context.t('readerTtsVoice'),
                  style: text.labelLarge?.copyWith(color: fg)),
              const Spacer(),
              TextButton(
                  onPressed: onOpenSystemTts,
                  child: Text(context.t('readerTtsSystemSettings'))),
            ],
          ),
          if (voices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: LrSpacing.xs),
              child: Text(context.t('readerTtsNoVoice'),
                  style: text.labelSmall
                      ?.copyWith(color: fg.withValues(alpha: 0.7))),
            )
          else
            SizedBox(
              height: 132,
              child: ListView.builder(
                itemCount: voices.length + 1,
                itemBuilder: (BuildContext context, int i) {
                  if (i == 0) {
                    return _VoiceRow(
                      label: context.t('readerTtsDefaultVoice'),
                      selected: voiceName.isEmpty,
                      onTap: () => onVoice(''),
                    );
                  }
                  final String voice = voices[i - 1];
                  return _VoiceRow(
                    label: voice,
                    selected: voice == voiceName,
                    onTap: () => onVoice(voice),
                  );
                },
              ),
            ),
          const SizedBox(height: LrSpacing.xs),
          Text(context.t('readerTtsStaticNote'),
              style:
                  text.labelSmall?.copyWith(color: fg.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.contentColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final Color contentColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          SizedBox(
              width: 48,
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: contentColor))),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(value.toStringAsFixed(1),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: contentColor)),
          ),
        ],
      );
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        trailing: selected
            ? Icon(Icons.check,
                size: 16, color: Theme.of(context).colorScheme.primary)
            : null,
        onTap: onTap,
      );
}

/// 面板入口：由阅读页调用，组件自己只弹 bottom sheet。
class TtsSettingsSheet {
  const TtsSettingsSheet._();

  static Future<void> open(
    BuildContext context, {
    required double rate,
    required double pitch,
    required TtsTimbre timbre,
    required bool autoNext,
    required List<String> voices,
    required String voiceName,
    required ValueChanged<double> onRate,
    required ValueChanged<double> onPitch,
    required ValueChanged<TtsTimbre> onTimbre,
    required ValueChanged<bool> onAutoNext,
    required ValueChanged<String> onVoice,
    required VoidCallback onOpenSystemTts,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext ctx) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: TtsSettingsPanel(
            rate: rate,
            pitch: pitch,
            timbre: timbre,
            autoNext: autoNext,
            voices: voices,
            voiceName: voiceName,
            onRate: onRate,
            onPitch: onPitch,
            onTimbre: onTimbre,
            onAutoNext: onAutoNext,
            onVoice: onVoice,
            onOpenSystemTts: onOpenSystemTts,
            onDismiss: () => Navigator.pop(ctx),
          ),
        ),
      );
}
