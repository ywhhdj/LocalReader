import 'package:flutter/material.dart';

import '../../../assembly/app_scope.dart';
import '../../../core/model/stats/excerpt_capture.dart';
import '../../../core/model/stats/reading_stats.dart';
import '../../../core/common/design_tokens.dart';
import '../../../core/ui/components/glass/Nav.dart';
import '../../../l10n/lr_localizations.dart';

/// 编辑摘录的批注与划线色。
///
/// 只允许编辑 `isUserAdded=true` 的条目；演示种子由调用方禁用入口，
/// `AppState.updateExcerpt` 里还有一道 `isUserAdded` 守卫，双保险。
class ExcerptEditSheet extends StatefulWidget {
  const ExcerptEditSheet({super.key, required this.excerpt});

  final Excerpt excerpt;

  static Future<bool> open(BuildContext context, Excerpt excerpt) async {
    if (!excerpt.isUserAdded) return false;
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ExcerptEditSheet(excerpt: excerpt),
    );
    return saved ?? false;
  }

  @override
  State<ExcerptEditSheet> createState() => _ExcerptEditSheetState();
}

class _ExcerptEditSheetState extends State<ExcerptEditSheet> {
  late final TextEditingController _note;
  late HighlightColor _color;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.excerpt.note);
    _color = widget.excerpt.highlight;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassPanel(
      padding: EdgeInsets.fromLTRB(
        LrSpacing.l,
        LrSpacing.l,
        LrSpacing.l,
        LrSpacing.l + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(context.t('uiEditExcerpt'), style: text.headlineMedium),
              const SizedBox(height: LrSpacing.m),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(LrSpacing.m),
                decoration: BoxDecoration(
                  color: HighlightPalette.lineTint(_color),
                  borderRadius: BorderRadius.circular(LrRadius.card),
                ),
                child: Text(widget.excerpt.text,
                    style: text.bodyLarge?.copyWith(height: 1.7)),
              ),
              const SizedBox(height: LrSpacing.xs),
              Text(
                  '《${widget.excerpt.bookTitle}》· ${widget.excerpt.chapterTitle}',
                  style: text.labelSmall),
              const SizedBox(height: LrSpacing.m),
              Text(context.t('uiHighlightColor'), style: text.labelSmall),
              const SizedBox(height: LrSpacing.xs),
              Wrap(
                spacing: LrSpacing.xs,
                runSpacing: LrSpacing.xs,
                children: <Widget>[
                  for (final HighlightColor c in HighlightColor.values)
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: LrSpacing.m, vertical: LrSpacing.xs),
                        decoration: BoxDecoration(
                          color: HighlightPalette.lineTint(c),
                          borderRadius: BorderRadius.circular(LrRadius.pill),
                          border: Border.all(
                            color: _color == c
                                ? HighlightPalette.spine(c)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              _color == c ? Icons.check_circle : Icons.circle,
                              size: 14,
                              color: HighlightPalette.spine(c),
                            ),
                            const SizedBox(width: LrSpacing.xs),
                            Text(HighlightPalette.labels[c]!,
                                style: text.labelLarge),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: LrSpacing.m),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: context.t('uiNote'),
                  hintText: context.t('uiClearTheFieldToRemoveTheNote'),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(LrRadius.card)),
                ),
              ),
              const SizedBox(height: LrSpacing.xs),
              Text(context.t('excerptLocalNote'), style: text.labelSmall),
              const SizedBox(height: LrSpacing.m),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(context.t('uiSaveChanges')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final AppState state = AppScope.of(context);
    final bool changed = state.updateExcerpt(
      widget.excerpt.id,
      note: _note.text.trim(),
      highlight: _color,
    );
    if (mounted) Navigator.of(context).pop(changed);
  }
}
