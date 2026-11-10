import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../wenku/wenku8_models.dart';
import 'glass.dart';
import '../content/lr_localizations.dart';

/// Wenku8 书籍详情面板（core 层，供书架云端 tab 与文库页共用，避免跨 feature import）。
///
/// 只展示**元数据**：书名 / 作者 / 标签 / 简介 / 卷章目录。
/// 章节正文由 Wenku8 在使用时提供，这里不下载、不缓存、不打包。
class Wenku8DetailSheet extends StatelessWidget {
  const Wenku8DetailSheet({
    super.key,
    required this.detail,
    required this.added,
    required this.onAdd,
  });

  static Future<void> open(
    BuildContext context, {
    required Wenku8Detail detail,
    required bool added,
    required ValueChanged<Wenku8Book> onAdd,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Wenku8DetailSheet(
            detail: detail,
            added: added,
            onAdd: onAdd,
          ),
        ),
      );

  final Wenku8Detail detail;
  final bool added;
  final ValueChanged<Wenku8Book> onAdd;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Wenku8Book book = detail.book;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(
          LrSpacing.l, LrSpacing.l, LrSpacing.l, LrSpacing.xl),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: <Color>[
                        book.coverColor,
                        Color.lerp(book.coverColor, Colors.black, 0.25)!,
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: LrSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(context.t('wenkuDetailTitle'),
                          style: text.labelSmall),
                      Text(book.title, style: text.headlineMedium),
                      Text(book.author, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: LrSpacing.m),
            Wrap(
              spacing: LrSpacing.s,
              children: <Widget>[
                for (final String tag in book.tags)
                  Chip(label: Text(tag, style: text.labelSmall)),
              ],
            ),
            const SizedBox(height: LrSpacing.s),
            Text(context.t('wenkuStatusNote'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.m),
            Text(context.t('wenkuDetailSynopsis'), style: text.titleMedium),
            const SizedBox(height: LrSpacing.xs),
            Text(detail.synopsis, style: text.bodySmall),
            const SizedBox(height: LrSpacing.m),
            Text(
              context.tArgs('uiVolumesChapters', <Object?>[
                context.t('wenkuDetailToc'),
                detail.volumes.length,
                detail.chapterCount
              ]),
              style: text.titleMedium,
            ),
            const SizedBox(height: LrSpacing.xs),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (final Wenku8Volume v in detail.volumes)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(v.title, style: text.titleMedium),
                      subtitle: Text(
                          context
                              .tArgs('uiChapters', <Object?>[v.chapterCount]),
                          style: text.labelSmall),
                      children: <Widget>[
                        for (final Wenku8Chapter c in v.chapters)
                          ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.only(left: LrSpacing.m),
                            title: Text(c.title, style: text.bodySmall),
                            trailing: Text(
                              context.t('wenkuDetailChapterNote'),
                              style: text.labelSmall,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.s),
            Text(context.t('wenkuDetailStaticNote'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.m),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: added
                    ? null
                    : () {
                        onAdd(book);
                        Navigator.of(context).pop();
                      },
                icon: Icon(
                    added
                        ? Icons.check_circle_outline
                        : Icons.library_add_outlined,
                    size: 18),
                label: Text(
                  added
                      ? context.t('wenkuBookAdded')
                      : context.t('wenkuBookAdd'),
                  style: text.labelLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
