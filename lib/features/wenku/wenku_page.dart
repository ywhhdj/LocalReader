import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/router/route_args.dart';
import '../../core/state/app_scope.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass.dart';
import 'wenku_login_sheet.dart';
import '../../core/content/lr_localizations.dart';

/// 轻小说文库：默认关闭的在线目录 + 本地导入入口。
/// 设计要点：LocalReader 原定位是「纯本地、无联网、无广告」，
/// 因此在线能力必须是显式开关；开关关闭时本页与全应用都不产生任何网络请求。
///
/// 在线开关不存页面局部状态，只读 AppState.onlineEnabled：
/// 「我的」页的 pureLocal 是 master switch，两处必须说同一句话。
class WenkuPage extends StatelessWidget {
  const WenkuPage({super.key, this.onImport});

  /// 与书架 / 搜索页共用同一个 core 导入说明弹窗，由 AppShell 注入。
  final ShowImport? onImport;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final bool onlineEnabled = state.onlineEnabled;
    final bool pureLocal = state.settings.pureLocal;
    final TextTheme text = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final SeasonPalette palette =
        Theme.of(context).extension<LrSeasonTheme>()?.palette ??
            SeasonPalette.all[isDark ? SeasonStyle.winter : SeasonStyle.paper]!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? <Color>[const Color(0xFF15171C), const Color(0xFF1D2027)]
              : <Color>[
                  palette.seed,
                  Color.lerp(palette.seed, Colors.white, 0.5)!
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              LrSpacing.l, LrSpacing.xl, LrSpacing.l, 120),
          children: <Widget>[
            Text(context.t('uiLightNovels'), style: text.displayMedium),
            const SizedBox(height: LrSpacing.xs),
            Text(context.t('uiOnlineDirectoryAndLocalLibraryStayIndependent'),
                style: text.bodyMedium),
            const SizedBox(height: LrSpacing.l),

            // 显式开关：默认关闭 = 零网络请求。
            // 纯本地模式开启时开关禁用，并引导到「我的」页先关 master switch，
            // 避免出现「我的页显示纯本地、文库页却能发请求」的自相矛盾状态。
            GlassPanel(
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: onlineEnabled,
                onChanged:
                    pureLocal ? null : (bool v) => state.setOnlineDirectory(v),
                title: Text(context.t('uiEnableOnlineDirectoryWenku8'),
                    style: text.titleMedium),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: LrSpacing.xs),
                  child: Text(
                    pureLocal
                        ? context.t(
                                'uiPureLocalModeIsOnTheAppMakesNoNetworkRequests') +
                            context.t(
                                'uiTurnOffPureLocalModeOnTheProfilePageFirst')
                        : context.t(
                                'uiWhenOffTheAppStaysFullyLocalAndMakesNoNetworkR') +
                            context.t(
                                'uiWhenOnOnlyWenku8ListingsAndTocMetadataAreRead'),
                    style: text.bodySmall,
                  ),
                ),
              ),
            ),
            const SizedBox(height: LrSpacing.m),
            _ActionCard(
              icon: Icons.login_outlined,
              title: context.t('wenkuLoginTitle'),
              subtitle: context.t('uiItemsShelfSource'),
              onTap: () => unawaited(Wenku8LoginSheet.open(context)),
            ),
            const SizedBox(height: LrSpacing.l),

            if (!onlineEnabled) ...<Widget>[
              _ActionCard(
                icon: Icons.folder_open_outlined,
                title: context.t('uiImportIntoLocalLibrary'),
                subtitle: context.t('uiTxtEpubCbzPdfImageFolders'),
                onTap: () => _showImport(context),
              ),
              const SizedBox(height: LrSpacing.l),
              _ComplianceCard(),
            ] else ...<Widget>[
              GlassPanel(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline,
                        size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: LrSpacing.s),
                    Expanded(
                      child: Text(
                        context.t('onlineAvailability'),
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LrSpacing.m),
              ..._demoEntries.map<Widget>((Map<String, String> e) => Padding(
                    padding: const EdgeInsets.only(bottom: LrSpacing.s),
                    child: _EntryCard(
                        entry: e, onTap: () => _showEntry(context, e)),
                  )),
              const SizedBox(height: LrSpacing.l),
              _ComplianceCard(),
            ],
          ],
        ),
      ),
    );
  }

  // 演示条目：仅元数据与目录，不内置任何小说正文文件。
  static List<Map<String, String>> get _demoEntries => <Map<String, String>>[
        <String, String>{
          'title': lrText('uiSampleWorkTocPreview'),
          'author': lrText('uiSampleData2'),
          'tag': lrText('uiContents')
        },
        <String, String>{
          'title': lrText('uiSampleWorkVolumeList'),
          'author': lrText('uiSampleData2'),
          'tag': lrText('uiContents')
        },
        <String, String>{
          'title': lrText('uiSampleWorkDetail'),
          'author': lrText('uiSampleData2'),
          'tag': lrText('uiMetadata')
        },
      ];

  void _showImport(BuildContext context) {
    final ShowImport? show = onImport;
    if (show == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.t('uiImportEntryIsNotWiredIntoThisPage'))));
      return;
    }
    show();
  }

  void _showEntry(BuildContext context, Map<String, String> e) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => GlassPanel(
        padding: const EdgeInsets.fromLTRB(
            LrSpacing.l, LrSpacing.l, LrSpacing.l, LrSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(e['title'] ?? '',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: LrSpacing.m),
            Text(context.t('onlineEntryNote'),
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: LrSpacing.m),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.t('uiGotIt'))),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        child: Row(
          children: <Widget>[
            Icon(icon, size: 26, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: LrSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});
  final Map<String, String> entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        borderRadius: LrRadius.card,
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: <Color>[
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.75),
                    Theme.of(context).colorScheme.primary,
                  ],
                ),
              ),
            ),
            const SizedBox(width: LrSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(entry['title'] ?? '',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      context
                          .tArgs('uiSampleDataN1', <Object?>[entry['author']]),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Text(entry['tag'] ?? '',
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// 合规说明：产品内常驻，不只在 README 里写。
class _ComplianceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.gavel_outlined,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: LrSpacing.s),
              Text(context.t('uiAboutContentAndSources'),
                  style: text.titleMedium),
            ],
          ),
          const SizedBox(height: LrSpacing.m),
          ...<String>[
            context.t('appDisclaimer'),
            context.t('sources'),
            context.t('contentRights'),
            context.t('freeStatement'),
            context.t('nonOfficial'),
            context.t('issueGuidance'),
            context.t('thirdPartyService'),
          ].map<Widget>((String s) => Padding(
                padding: const EdgeInsets.only(bottom: LrSpacing.s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('·  ', style: TextStyle(fontSize: 14)),
                    Expanded(child: Text(s, style: text.bodySmall)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
