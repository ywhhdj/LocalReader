import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/wenku8_detail_sheet.dart';
import '../../core/wenku/wenku8_compliance.dart';
import '../../core/wenku/wenku8_models.dart';
import '../../core/wenku/wenku8_registry.dart';
import '../../core/wenku/wenku8_source.dart';
import '../../core/content/lr_localizations.dart';

/// 书架页「云端来源」子视图（第二十二轮）。
///
/// 用户要求书架页有「本地 / 云端（云端来源）」导航；云端这一侧先列**来源**，
/// 再进该来源的目录。来源固定为 Wenku8 与本地导入两项，**不提供添加书源**。
///
/// 状态口径：`pureLocal` master switch 锁定时连演示数据源都不读，页面显示
/// 解锁卡；开启后走 `AppState.refreshWenku8()`，状态机覆盖
/// rateLimited / unavailable / upstreamChanged 三种第三方常态。
/// 列表出口一律过 `Wenku8Compliance.withoutWithdrawn()`，下架内容不展示。
class CloudShelfView extends StatefulWidget {
  const CloudShelfView({super.key, this.onImport});

  /// 「本地导入」来源的向导入口，由书架页透传（app 层注入）。
  final VoidCallback? onImport;

  @override
  State<CloudShelfView> createState() => _CloudShelfViewState();
}

class _CloudShelfViewState extends State<CloudShelfView> {
  String _sourceId = Wenku8Compliance.wenku8SourceId;
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool locked = state.wenku8Locked;
    final BookSource source =
        Wenku8Registry.byId(_sourceId) ?? Wenku8Registry.sources.first;
    final Wenku8Listing? listing = state.wenku8Listing;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          LrSpacing.l, LrSpacing.s, LrSpacing.l, 140),
      children: <Widget>[
        Text(context.t('wenkuCloudTitle'), style: text.headlineMedium),
        const SizedBox(height: LrSpacing.xs),
        Text(context.t('wenkuCloudSubtitle'), style: text.bodyMedium),
        const SizedBox(height: LrSpacing.m),

        // 来源导航：固定两项，没有「添加书源」按钮。
        Text(context.t('wenkuSourceNavTitle'), style: text.labelSmall),
        const SizedBox(height: LrSpacing.xs),
        Wrap(
          spacing: LrSpacing.s,
          children: <Widget>[
            for (final BookSource s in Wenku8Registry.sources)
              ChoiceChip(
                avatar: Icon(
                  s.isOnline ? Icons.cloud_outlined : Icons.folder_open_outlined,
                  size: 16,
                ),
                label: Text(s.title, style: text.labelLarge),
                selected: s.id == _sourceId,
                onSelected: (bool _) => setState(() => _sourceId = s.id),
              ),
          ],
        ),
        const SizedBox(height: LrSpacing.s),
        GlassPanel(
          padding: const EdgeInsets.all(LrSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(source.title, style: text.titleMedium),
              const SizedBox(height: 4),
              Text(source.subtitle, style: text.bodySmall),
              const SizedBox(height: LrSpacing.s),
              Text(source.note, style: text.labelSmall),
            ],
          ),
        ),
        const SizedBox(height: LrSpacing.m),
        Text(context.t('wenkuCustomSourceNote'), style: text.labelSmall),
        const SizedBox(height: LrSpacing.l),

        if (!source.isOnline) ...<Widget>[
          _localImportCard(context, text, state),
        ] else if (locked) ...<Widget>[
          _lockedCard(context, text, state),
        ] else ...<Widget>[
          _statusCard(context, text, state),
          const SizedBox(height: LrSpacing.m),
          _feedChips(context, text, state),
          const SizedBox(height: LrSpacing.s),
          _searchField(context, text, state),
          const SizedBox(height: LrSpacing.m),
          if (listing == null || !listing.hasBooks)
            _emptyCard(context, text)
          else
            ...listing.books.map<Widget>(
              (Wenku8Book b) => _WenkuBookCard(
                book: b,
                added: state.isWenku8BookAdded(b.id),
                onTap: () => _openDetail(context, state, b),
              ),
            ),
        ],
        const SizedBox(height: LrSpacing.l),
        _complianceCard(context, text),
      ],
    );
  }

  Widget _localImportCard(BuildContext context, TextTheme text, AppState state) =>
      GlassPanel(
        padding: const EdgeInsets.all(LrSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(lrText('wenkuLocalSourceNote'), style: text.bodySmall),
            const SizedBox(height: LrSpacing.s),
            Text(lrText('cloudChannelsTitle'), style: text.titleMedium),
            const SizedBox(height: 4),
            Text(lrText('cloudChannelsNote'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.m),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: widget.onImport,
                icon: const Icon(Icons.file_download_outlined, size: 17),
                label: Text(lrText('importWizardEntry'),
                    style: text.labelLarge),
              ),
            ),
          ],
        ),
      );

  Widget _lockedCard(BuildContext context, TextTheme text, AppState state) =>
      GlassPanel(
        padding: const EdgeInsets.all(LrSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.lock_outline, size: 30,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: LrSpacing.m),
            Text(lrText('wenkuLockedTitle'), style: text.headlineMedium),
            const SizedBox(height: LrSpacing.s),
            Text(lrText('wenkuLockedBody'), style: text.bodySmall),
            const SizedBox(height: LrSpacing.m),
            FilledButton.icon(
              onPressed: state.enableOnlineDirectory,
              icon: const Icon(Icons.cloud_outlined, size: 18),
              label: Text(lrText('wenkuUnlockButton'),
                  style: text.labelLarge),
            ),
          ],
        ),
      );

  Widget _statusCard(BuildContext context, TextTheme text, AppState state) {
    final Wenku8Status s = state.wenku8Status;
    return GlassPanel(
      padding: const EdgeInsets.all(LrSpacing.m),
      child: Row(
        children: <Widget>[
          Icon(
            Wenku8StatusLabels.isUsable(s)
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: LrSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(Wenku8StatusLabels.titles[s]!, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(Wenku8StatusLabels.hints[s]!, style: text.labelSmall),
              ],
            ),
          ),
          IconButton(
            tooltip: context.t('wenkuRefresh'),
            onPressed: () => state.refreshWenku8(),
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _feedChips(BuildContext context, TextTheme text, AppState state) =>
      Wrap(
        spacing: LrSpacing.s,
        runSpacing: LrSpacing.xs,
        children: <Widget>[
          for (final Wenku8FeedKind f in Wenku8FeedKind.values)
            if (f != Wenku8FeedKind.search)
              ChoiceChip(
                label: Text(Wenku8FeedLabels.labels[f]!, style: text.labelLarge),
                selected: state.wenku8Query.feed == f,
                onSelected: (bool _) => state.setWenku8Feed(f),
              ),
        ],
      );

  Widget _searchField(BuildContext context, TextTheme text, AppState state) =>
      GlassPanel(
        borderRadius: LrRadius.pill,
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.m, vertical: LrSpacing.xs),
        child: Row(
          children: <Widget>[
            Icon(Icons.search, size: 18, color: text.bodySmall?.color),
            const SizedBox(width: LrSpacing.s),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: state.setWenku8Keyword,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: lrText('wenkuSearchHint'),
                  hintStyle: text.bodySmall,
                ),
                style: text.bodySmall,
              ),
            ),
            if (_search.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _search.clear();
                  state.setWenku8Keyword('');
                },
                child: const Icon(Icons.close, size: 16),
              ),
          ],
        ),
      );

  Widget _emptyCard(BuildContext context, TextTheme text) => GlassPanel(
        padding: const EdgeInsets.all(LrSpacing.l),
        child: Column(
          children: <Widget>[
            Icon(Icons.inbox_outlined, size: 34,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: LrSpacing.m),
            Text(lrText('wenkuEmptyTitle'), style: text.titleMedium),
            const SizedBox(height: LrSpacing.s),
            Text(lrText('wenkuEmptyBody'), style: text.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _complianceCard(BuildContext context, TextTheme text) => GlassPanel(
        padding: const EdgeInsets.all(LrSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(lrText('wenkuOnlySources'), style: text.labelSmall),
            const SizedBox(height: LrSpacing.s),
            ...Wenku8Compliance.rules.map<Widget>(
              (String rule) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $rule', style: text.labelSmall),
              ),
            ),
          ],
        ),
      );

  Future<void> _openDetail(
      BuildContext context, AppState state, Wenku8Book book) async {
    final Wenku8Detail? detail = await state.wenku8Detail(book.id);
    if (detail == null || !context.mounted) return;
    await Wenku8DetailSheet.open(
      context,
      detail: detail,
      added: state.isWenku8BookAdded(book.id),
      onAdd: (Wenku8Book b) {
        final bool ok = state.addWenku8BookToLibrary(b);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? context.t('wenkuAddedNote')
                : context.t('wenkuBookAdded')),
          ),
        );
      },
    );
  }
}

class _WenkuBookCard extends StatelessWidget {
  const _WenkuBookCard({
    required this.book,
    required this.added,
    required this.onTap,
  });

  final Wenku8Book book;
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LrSpacing.s),
      child: GlassPanel(
        padding: const EdgeInsets.all(LrSpacing.m),
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: <Color>[
                      book.coverColor,
                      Color.lerp(book.coverColor, Colors.black, 0.3)!,
                    ],
                  ),
                ),
              ),
              const SizedBox(width: LrSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(book.title, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(context.tArgs('uiVolumes', <Object?>[book.author, book.volumeCount]),
                        style: text.bodySmall),
                    const SizedBox(height: 2),
                    Text(book.latestChapter, style: text.labelSmall),
                  ],
                ),
              ),
              Icon(added ? Icons.check_circle_outline : Icons.chevron_right,
                  size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
