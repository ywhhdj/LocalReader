import 'package:flutter/material.dart';

import '../../domain/repositories/book_repository.dart';
import '../../l10n/lr_localizations.dart';
import '../../core/common/design_tokens.dart';
import '../../core/ui/components/glass/Nav.dart';

/// 第三十轮：详情页拆成一组可复用组件，页面只做拼装。
/// 参考图的结构是「圆角返回 / 居中标题 / 右上来源动作 → 封面 + 书名 +
/// 作者 + 状态 + 编号 + 缓存提示 → 标签 → 进度 → 简介 → 底部玻璃操作条」。
/// 组件不持有跨页设置，不构造路由，所有文案走 ARB。

/// 顶部条：云端显示云下载，本地显示删除 / 重置进度的菜单。
class DetailTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DetailTopBar({
    super.key,
    required this.isCloud,
    required this.onCloudCache,
    required this.onDelete,
    required this.onResetProgress,
  });

  final bool isCloud;
  final VoidCallback onCloudCache;
  final VoidCallback onDelete;
  final VoidCallback onResetProgress;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(),
        title: Text(context.t('detailTitle'),
            style: Theme.of(context).textTheme.titleLarge),
        actions: <Widget>[
          if (isCloud)
            IconButton(
              tooltip: context.t('detailCloudDownload'),
              icon: const Icon(Icons.cloud_download_outlined),
              onPressed: onCloudCache,
            )
          else
            PopupMenuButton<String>(
              tooltip: context.t('detailLocalActions'),
              onSelected: (String v) {
                if (v == 'delete') onDelete();
                if (v == 'reset') onResetProgress();
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(context.t('detailDeleteBook'))),
                PopupMenuItem<String>(
                    value: 'reset',
                    child: Text(context.t('detailResetProgress'))),
              ],
              icon: const Icon(Icons.more_horiz),
            ),
        ],
      );
}

/// 封面 + 书名 / 作者 / 状态 / 编号 / 缓存失败提示 / 标签。
class DetailCoverInfo extends StatelessWidget {
  const DetailCoverInfo({
    super.key,
    required this.book,
    required this.isCloud,
    required this.onAuthorTap,
    required this.onRetryCache,
  });

  final BookSummary book;
  final bool isCloud;
  final VoidCallback onAuthorTap;
  final VoidCallback onRetryCache;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _DetailCover(book: book),
        const SizedBox(width: LrSpacing.l),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(book.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.25)),
              const SizedBox(height: LrSpacing.xs),
              InkWell(
                onTap: onAuthorTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(book.author, style: text.titleMedium),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: LrSpacing.m),
              Text(
                  '${context.t('detailStatusOngoing')}  ·  ${context.t('detailCached')}',
                  style: text.bodyMedium),
              const SizedBox(height: LrSpacing.xs),
              Text('${context.t('detailUpdatedOn')} 2026-11-07',
                  style: text.bodyMedium),
              const SizedBox(height: LrSpacing.m),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: LrSpacing.xs, vertical: LrSpacing.xs),
                color: const Color(0xFF17181C),
                child: Text(
                    isCloud
                        ? 'WK-01973'
                        : 'LB-${book.id.hashCode.abs() % 10000}',
                    style: text.labelMedium?.copyWith(color: Colors.white)),
              ),
              const SizedBox(height: LrSpacing.xs),
              InkWell(
                onTap: onRetryCache,
                child: Text(context.t('detailCacheFailed'),
                    style: text.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailCover extends StatelessWidget {
  const _DetailCover({required this.book});

  final BookSummary book;

  @override
  Widget build(BuildContext context) => Container(
        width: 116,
        height: 176,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(4, 6)),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              book.spineColor,
              Color.lerp(book.spineColor, Colors.black, 0.35)!,
            ],
          ),
        ),
        padding: const EdgeInsets.all(LrSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(book.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: LrSpacing.xs),
            Text(book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      );
}

/// 标签行：演示书籍的题材标签，组件只负责排版。
class DetailTagRow extends StatelessWidget {
  const DetailTagRow({super.key, required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: LrSpacing.xs,
        runSpacing: LrSpacing.xs,
        children: <Widget>[
          for (final String tag in tags)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: LrSpacing.m, vertical: LrSpacing.xs),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LrRadius.card / 2),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.45)),
              ),
              child: Text(tag, style: Theme.of(context).textTheme.bodyMedium),
            ),
        ],
      );
}

/// 进度卡：**只有存在阅读进度时才由页面构建**，没读过不显示。
class DetailProgressCard extends StatelessWidget {
  const DetailProgressCard({
    super.key,
    required this.chapterTitle,
    required this.progress,
  });

  final String chapterTitle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final int percent = (progress * 100).round();
    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${context.t('detailReadTo')} $chapterTitle',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.titleLarge),
          const SizedBox(height: LrSpacing.m),
          ClipRRect(
            borderRadius: BorderRadius.circular(LrRadius.pill),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          const SizedBox(height: LrSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${context.t('detailChapterPercent')} $percent%',
                style: text.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// 简介：`01 / SYNOPSIS` + 细线 + 标题 + 折叠正文 + 展开全部。
class DetailSynopsis extends StatefulWidget {
  const DetailSynopsis({super.key, required this.paragraphs});

  final List<String> paragraphs;

  @override
  State<DetailSynopsis> createState() => _DetailSynopsisState();
}

class _DetailSynopsisState extends State<DetailSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> visible =
        _expanded ? widget.paragraphs : widget.paragraphs.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(context.t('detailSynopsisIndex'), style: text.labelSmall),
            const SizedBox(width: LrSpacing.xs),
            Expanded(
                child: Divider(
                    color: Theme.of(context).colorScheme.outline, height: 1)),
            const SizedBox(width: 2),
            Container(
                width: 4,
                height: 4,
                color: Theme.of(context).colorScheme.onSurface),
          ],
        ),
        const SizedBox(height: LrSpacing.m),
        Text(context.t('detailSynopsisTitle'), style: text.headlineMedium),
        const SizedBox(height: LrSpacing.m),
        for (final String paragraph in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: LrSpacing.m),
            child: Text(paragraph, style: text.bodyLarge),
          ),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                  _expanded
                      ? context.t('detailCollapse')
                      : context.t('detailExpandAll'),
                  style: text.titleMedium),
              const SizedBox(width: LrSpacing.xs),
              Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20),
            ],
          ),
        ),
      ],
    );
  }
}

/// 底部玻璃操作条：云端「加入书架 / 云端收藏 / 评论 / 继续阅读」，
/// 本地「本地收藏 / 分组 / 继续阅读」。语义由 `isCloud` 一处裁决。
class DetailActionBar extends StatelessWidget {
  const DetailActionBar({
    super.key,
    required this.isCloud,
    required this.started,
    required this.onPrimary,
    required this.onSecondary,
    required this.onRead,
  });

  final bool isCloud;
  final bool started;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) => GlassPanel(
        borderRadius: LrRadius.pill,
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.xs, vertical: LrSpacing.xs),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextButton.icon(
                onPressed: onPrimary,
                icon: const Icon(Icons.bookmark_add_outlined, size: 19),
                label: Text(isCloud
                    ? context.t('detailAddToShelf')
                    : context.t('detailLocalFavorite')),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: onSecondary,
                icon: Icon(
                    isCloud
                        ? Icons.comment_outlined
                        : Icons.dashboard_customize_outlined,
                    size: 19),
                label: Text(isCloud
                    ? context.t('detailComments')
                    : context.t('detailGrouping')),
              ),
            ),
            const SizedBox(width: LrSpacing.xs),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onRead,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(started
                    ? context.t('detailContinueReading')
                    : context.t('detailStartReading')),
              ),
            ),
          ],
        ),
      );
}

/// 「这本书的摘录」入口：组件只显示条数与引导，深链只回传 bookId。
class DetailExcerptEntry extends StatelessWidget {
  const DetailExcerptEntry({
    super.key,
    required this.count,
    required this.onOpen,
  });

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassPanel(
      child: Row(
        children: <Widget>[
          Icon(Icons.format_quote_outlined,
              size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: LrSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.t('bookExcerptTitle'), style: text.titleMedium),
                const SizedBox(height: 2),
                Text(context.tArgs('uiItems2', <Object?>[count]),
                    style: text.labelSmall),
              ],
            ),
          ),
          TextButton(onPressed: onOpen, child: Text(context.t('uiViewAll'))),
        ],
      ),
    );
  }
}

/// 本地书籍的元数据编辑面板（书名 / 作者 / 封面色 / 卷序）。
/// 写的是内存覆盖层，页面常驻说明，不伪装成持久化。
class DetailMetaEditorSheet extends StatefulWidget {
  const DetailMetaEditorSheet({
    super.key,
    required this.book,
    required this.onSave,
  });

  final BookSummary book;

  /// 由页面注入：core/ui 组件不读 AppScope，依赖方向保持向下。
  final void Function(
      String title, String author, Color spineColor, int volumeOrder) onSave;

  @override
  State<DetailMetaEditorSheet> createState() => _DetailMetaEditorSheetState();
}

class _DetailMetaEditorSheetState extends State<DetailMetaEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _author;
  late Color _color;
  late int _volume;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.book.title);
    _author = TextEditingController(text: widget.book.author);
    _color = widget.book.spineColor;
    _volume = widget.book.volumeOrder;
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(
          LrSpacing.l, LrSpacing.l, LrSpacing.l, LrSpacing.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(context.t('uiEditBookInfo'), style: text.headlineMedium),
            const SizedBox(height: LrSpacing.m),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                  labelText: context.t('uiTitle'),
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: LrSpacing.m),
            TextField(
              controller: _author,
              decoration: InputDecoration(
                  labelText: context.t('uiAuthor'),
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: LrSpacing.m),
            Text(context.t('uiVolumeOrder'), style: text.titleMedium),
            DropdownButton<int>(
              value: _volume,
              items: <DropdownMenuItem<int>>[
                for (int i = 0; i <= 6; i++)
                  DropdownMenuItem<int>(
                      value: i,
                      child: Text(i == 0
                          ? context.t('uiNoVolume')
                          : context.tArgs('uiVolume2', <Object?>[i]))),
              ],
              onChanged: (int? v) => setState(() => _volume = v ?? 0),
            ),
            const SizedBox(height: LrSpacing.xs),
            Text(context.t('uiStaticDemoSaveSampleData'),
                style: text.bodySmall),
            const SizedBox(height: LrSpacing.m),
            Row(
              children: <Widget>[
                Expanded(
                    child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.t('uiCancel')))),
                const SizedBox(width: LrSpacing.xs),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      final String title = _title.text.trim();
                      if (title.isEmpty) return;
                      widget.onSave(
                          title, _author.text.trim(), _color, _volume);
                      Navigator.pop(context);
                    },
                    child: Text(context.t('uiSave')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
