import 'package:flutter/material.dart';

import '../../assembly/app_scope.dart';
import '../../core/model/stats/excerpt_capture.dart';
import '../../core/model/stats/reading_stats.dart';
import '../../core/common/design_tokens.dart';
import '../../core/ui/components/glass/Nav.dart';
import '../../l10n/lr_localizations.dart';

/// 摘录采集面板：预览选中的正文、选划线色、写批注、保存。
///
/// 与 `ReaderStyleSheet` 同属 reader feature，阅读器直接调用（同 feature 内允许）；
/// 「我的」页 / 统计页若要用，仍须经 AppShell 注入，保持跨 feature 零依赖。
class ExcerptCaptureSheet extends StatefulWidget {
  const ExcerptCaptureSheet({
    super.key,
    required this.selection,
    required this.bookTitle,
    required this.chapterTitle,
  });

  final SelectionDraft selection;
  final String bookTitle;
  final String chapterTitle;

  /// 返回写入的 Excerpt；重复或校验不通过时返回 null。
  static Future<Excerpt?> open(
    BuildContext context, {
    required SelectionDraft selection,
    required String bookTitle,
    required String chapterTitle,
  }) =>
      showModalBottomSheet<Excerpt>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext ctx) => ExcerptCaptureSheet(
          selection: selection,
          bookTitle: bookTitle,
          chapterTitle: chapterTitle,
        ),
      );

  @override
  State<ExcerptCaptureSheet> createState() => _ExcerptCaptureSheetState();
}

class _ExcerptCaptureSheetState extends State<ExcerptCaptureSheet> {
  HighlightColor _color = HighlightColor.amber;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final SelectionDraft selection = widget.selection;
    final String preview = selection.normalizedText();
    final String? invalid = selection.validationMessage;
    final bool duplicated = state.hasSignature(selection.signature());
    final bool canSave = invalid == null && !duplicated;

    return GlassPanel(
      padding: EdgeInsets.fromLTRB(
        LrSpacing.l,
        LrSpacing.l,
        LrSpacing.l,
        LrSpacing.l + MediaQuery.of(context).viewInsets.bottom,
      ),
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
                  Icon(Icons.format_quote_outlined,
                      size: 20, color: HighlightPalette.spine(_color)),
                  const SizedBox(width: LrSpacing.xs),
                  Text(context.t('uiCaptureThisPassage'),
                      style: text.headlineMedium),
                  const Spacer(),
                  Text(
                      context.tArgs('uiLinesChars',
                          <Object?>[selection.count, preview.length]),
                      style: text.labelSmall),
                ],
              ),
              const SizedBox(height: LrSpacing.m),

              // 预览：左侧色条即所选划线色，所见即所得
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(LrSpacing.m),
                decoration: BoxDecoration(
                  color: HighlightPalette.lineTint(_color),
                  borderRadius: BorderRadius.circular(LrRadius.card),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 3,
                      height: 44,
                      decoration: BoxDecoration(
                        color: HighlightPalette.spine(_color),
                        borderRadius: BorderRadius.circular(LrRadius.pill),
                      ),
                    ),
                    const SizedBox(width: LrSpacing.m),
                    Expanded(
                      child: Text(
                        preview.isEmpty
                            ? context.t('uiNoTextAvailableToCapture')
                            : preview,
                        style: text.bodyLarge?.copyWith(height: 1.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LrSpacing.xs),
              Text(
                context.tArgs('uiExcerptCaptureSource', <Object?>[
                  widget.bookTitle,
                  widget.chapterTitle,
                  selection.spansParagraphs ? lrText('uiSpreads') : '',
                ]),
                style: text.labelSmall,
              ),

              const SizedBox(height: LrSpacing.m),
              Text(context.t('uiHighlightColor'), style: text.labelSmall),
              const SizedBox(height: LrSpacing.xs),
              Wrap(
                spacing: LrSpacing.xs,
                runSpacing: LrSpacing.xs,
                children: <Widget>[
                  for (final HighlightColor c in HighlightColor.values)
                    _ColorChip(
                      color: c,
                      selected: _color == c,
                      onTap: () => setState(() => _color = c),
                    ),
                ],
              ),

              const SizedBox(height: LrSpacing.m),
              TextField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: context.t('uiNoteOptional'),
                  hintText: context.t('uiWriteSomethingToAppendToTheExcerpt'),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LrRadius.card)),
                ),
              ),

              if (selection.spansParagraphs) ...<Widget>[
                const SizedBox(height: LrSpacing.xs),
                Text(
                  context.t('uiSpreadsLinesSentencesLines'),
                  style: text.bodySmall,
                ),
              ],
              if (invalid != null) ...<Widget>[
                const SizedBox(height: LrSpacing.xs),
                Text(invalid,
                    style: text.bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error)),
              ],
              if (duplicated) ...<Widget>[
                const SizedBox(height: LrSpacing.xs),
                Text(context.t('uiStatsPages'), style: text.bodySmall),
              ],

              const SizedBox(height: LrSpacing.m),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(context.t('excerptLocalNote'),
                            style: text.labelSmall),
                        const SizedBox(height: 4),
                        Text(context.t('excerptAnchorRestoreNote'),
                            style: text.labelSmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: LrSpacing.m),
                  FilledButton.icon(
                    onPressed: canSave ? _save : null,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: Text(context.t('uiSaveExcerpt')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final SelectionDraft selection = widget.selection;
    if (selection.validationMessage != null) return;
    final ExcerptDraft draft = selection.toDraft(
      highlight: _color,
      note: _noteController.text,
    );
    // 面板直接写全局状态（同 feature 内的 ReaderStyleSheet 也是这个口径），
    // 去重结果通过 pop 回传给阅读器做提示。
    final AppState state = AppScope.of(context);
    final Excerpt? saved = state.addExcerpt(
      draft,
      bookTitle: widget.bookTitle,
      chapterTitle: widget.chapterTitle,
    );
    if (mounted) Navigator.of(context).pop(saved);
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip(
      {required this.color, required this.selected, required this.onTap});

  final HighlightColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color c = HighlightPalette.colors[color]!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.m, vertical: LrSpacing.xs),
        decoration: BoxDecoration(
          color: HighlightPalette.lineTint(color),
          borderRadius: BorderRadius.circular(LrRadius.pill),
          border:
              Border.all(color: selected ? c : Colors.transparent, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              selected ? Icons.check_circle : Icons.circle,
              size: 14,
              color: c,
            ),
            const SizedBox(width: LrSpacing.xs),
            Text(HighlightPalette.labels[color]!,
                style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
