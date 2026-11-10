import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_reader/ui/components/SettingComponent.dart';

import '../../core/data/book_repository.dart';
import '../../core/favorites/favorite_routes.dart';
import '../../core/import/import_session.dart';
import '../../core/profile/profile_summary.dart';
import '../../core/state/app_scope.dart';
import '../../core/state/reader_style.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/wenku/wenku8_compliance.dart';
import '../../core/wenku/wenku8_registry.dart';
import '../../core/widgets/glass.dart';
import 'feedback_sheet.dart';
import '../../core/content/lr_localizations.dart';

/// 「我的」页（第二十二轮按 Wenku8_Flutter 的视觉气质重构）。
///
/// 参考仓库的气质是 **milky glass + editorial typography**：大留白、衬线大标题、
/// 细分隔线、分组小标题、玻璃卡片里的逐行设置。本页保留前二十一轮全部开关与
/// 入口，只重排信息架构：阅读摘要 hero → 外观与阅读 → 来源与在线 → 书库与导入
/// → 收藏 → 支持与反馈 → 关于。
///
/// 状态纪律不变：所有开关读写 `AppState`，`pureLocal` 是 master switch；
/// 页面不持有 `AppSettings` / `ReaderStyle` 的影子副本，跨页入口由 app 层注入。
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    this.onOpenReaderStyle,
    this.onOpenFavorite,
    this.onOpenImportWizard,
    this.onOpenLocalizedTexts,
    this.onOpenFeatureMatrix,
    this.onOpenWenku8Login,
  });

  /// 排版面板由 AppShell 注入：feature 之间不互相依赖。
  final VoidCallback? onOpenReaderStyle;

  /// 收藏项跳转由 AppShell 注入：本页只产出 FavoriteNavigation，不构造路由。
  final OpenFavorite? onOpenFavorite;

  /// 导入向导入口由 AppShell 注入。
  final VoidCallback? onOpenImportWizard;

  /// 文案表与语言预览入口由 AppShell 注入。
  final VoidCallback? onOpenLocalizedTexts;

  /// 功能总览入口由 AppShell 注入（第二十四轮）。
  final VoidCallback? onOpenFeatureMatrix;

  /// Wenku8 登录面板由 AppShell 注入（第二十五轮）：feature 之间不互相依赖。
  final VoidCallback? onOpenWenku8Login;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ReaderStyle reader = state.settings.reader;
    final TextTheme text = Theme.of(context).textTheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final SeasonPalette palette = Theme.of(context).extension<LrSeasonTheme>()?.palette ??
        SeasonPalette.all[isDark ? SeasonStyle.winter : SeasonStyle.paper]!;
    final bool pureLocal = state.settings.pureLocal;
    final List<FavoriteEntry> favorites = state.favorites;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? <Color>[const Color(0xFF15171C), const Color(0xFF1D2027)]
              : <Color>[palette.seed, Color.lerp(palette.seed, Colors.white, 0.5)!],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(LrSpacing.l, LrSpacing.xl, LrSpacing.l, 120),
          children: <Widget>[
            // ---------------------------------------------------------------- hero
            HeroHeader(
                title: context.t('profileHeroTitle'),
                subtitle: context.t('profileHeroSubtitle'),
            ),
            GlassPanel(
              padding: const EdgeInsets.symmetric(
                  horizontal: LrSpacing.m, vertical: LrSpacing.m),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _Stat(text: text, value: '${state.books.cached.length + state.importedCount}', label: context.t('uiLocalBooks')),
                  _Stat(text: text, value: '${state.favoriteCount}', label: context.t('uiFavorites')),
                  _Stat(text: text, value: '${Wenku8Registry.count}', label: context.t('uiSource')),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.s),
            // 第二十四轮：阅读摘要接 StatsSnapshot 真实聚合，不页
            Builder(builder: (BuildContext context) {
              final ProfileSummary summary = state.profileSummary;
              return GlassPanel(
                padding: const EdgeInsets.symmetric(
                    horizontal: LrSpacing.m, vertical: LrSpacing.s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _Stat(text: text, value: summary.todayLabel, label: context.t('uiMinutesToday')),
                    _Stat(text: text, value: summary.weekLabel, label: context.t('uiThisWeek')),
                    _Stat(text: text, value: summary.streakLabel, label: context.t('uiStreak')),
                    _Stat(text: text, value: summary.booksLabel, label: context.t('uiLibrary')),
                  ],
                ),
              );
            }),
            const SizedBox(height: LrSpacing.l),

            // ------------------------------------------------ 外观与阅读
            _SectionTitle(context.t('profileSectionAppearance'), text),
            GlassPanel(
              child: Column(
                children: <Widget>[
                  _SettingTile(
                    title: context.t('uiPureLocalMode'),
                    subtitle: context.t('uiWhenOnTheAppMakesNoNetworkRequests'),
                    value: pureLocal,
                    onChanged: state.setPureLocal,
                  ),
                  _divider(context),
                  _SettingTile(
                    title: context.t('uiInterfaceMotion2'),
                    subtitle: context.t('uiPageTurnAnimationShelfParallaxGlassTransitions'),
                    value: state.settings.motion,
                    onChanged: state.setMotion,
                  ),
                  _divider(context),
                  _SettingTile(
                    title: context.t('uiTtsReadAloud'),
                    subtitle: context.t('uiSentenceQueueRatePitchAutoNextChapter'),
                    value: state.settings.tts,
                    onChanged: state.setTts,
                  ),
                  _divider(context),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.text_format_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(context.t('uiReadingLayout'), style: text.titleMedium),
                    subtitle: Text(
                      context.tArgs('uiPtPages', <Object?>[reader.fontSize.round(), reader.backgroundLabel, reader.pageTurnLabel]) +
                      context.tArgs('uiContrast12', <Object?>[reader.bodyContrast.toStringAsFixed(1)]),
                      style: text.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: onOpenReaderStyle,
                  ),
                  _divider(context),
                  ChevronListTile(
                    icon: Icons.translate_outlined,
                    title: context.t('localizationTitle'),
                    desc: context.t('localizationDefaultNote'),
                    onTap: onOpenLocalizedTexts,
                  )
                  _divider(context),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.dashboard_customize_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(context.t('uiFeatureOverview'), style: text.titleMedium),
                    subtitle: Text(
                      context.t('uiPerBookLayoutFontsReportsBackupPermissions'),
                      style: text.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: onOpenFeatureMatrix,
                  ),
                  _divider(context),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.login_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(
                        context.t('wenkuLoginTitle'), 
                        style: text.titleMedium
                    ),
                    subtitle: Text(
                      context.t('uiFormLoginBookcaseSessionSourceDomain'),
                      style: text.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: onOpenWenku8Login,
                  ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.l),

            // ------------------------------------------------ 来源与在线
            _SectionTitle(context.t('profileSectionSources'), text),
            GlassPanel(
              child: Column(
                children: <Widget>[
                  _SettingTile(
                    title: context.t('uiOnlineDirectoryWenku8'),
                    subtitle: pureLocal
                        ? context.t('uiLockedByPureLocalMode')
                        : context.t('uiListingsAndTocMetadataOnlyNoBundledNovels'),
                    value: state.settings.onlineDirectory,
                    enabled: !pureLocal,
                    onChanged: state.setOnlineDirectory,
                  ),
                  _divider(context),
                  _SettingTile(
                    title: context.t('uiWebdavBackup'),
                    subtitle: context.t('uiLibraryMetadataProgressGroupsSessions'),
                    value: state.settings.webdav,
                    enabled: !pureLocal,
                    onChanged: state.setWebdav,
                  ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.s),
            GlassPanel(
              padding: const EdgeInsets.all(LrSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(context.t('wenkuSourceNavTitle'), style: text.titleMedium),
                  const SizedBox(height: LrSpacing.s),
                  ...Wenku8Registry.sources.map<Widget>(
                    (BookSource s) => Padding(
                      padding: const EdgeInsets.only(bottom: LrSpacing.s),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            s.isOnline
                                ? Icons.cloud_outlined
                                : Icons.folder_open_outlined,
                            size: 17,
                          ),
                          const SizedBox(width: LrSpacing.s),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(s.title, style: text.titleMedium),
                                Text(s.subtitle, style: text.labelSmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: LrSpacing.xs),
                  Text(context.t('wenkuCustomSourceNote'), style: text.labelSmall),
                  const SizedBox(height: LrSpacing.xs),
                  Text(context.t('wenkuOnlySources'), style: text.labelSmall),
                  if (pureLocal) ...<Widget>[
                    const SizedBox(height: LrSpacing.s),
                    Text(
                      context.t('uiPureLocalMode2'),
                      style: text.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.l),

            // ------------------------------------------------ 书库与导入
            _SectionTitle(context.t('profileSectionLibrary'), text),
            GlassPanel(
              child: Column(
                children: <Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_open_outlined, size: 18),
                    title: Text(context.t('importWizardTitle'), style: text.titleMedium),
                    subtitle: Text(context.t('uiFormatsAuthorizationScanConflicts'),
                        style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: onOpenImportWizard,
                  ),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.s),
            GlassPanel(
              padding: const EdgeInsets.all(LrSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(context.t('cloudChannelsTitle'), style: text.titleMedium),
                  const SizedBox(height: LrSpacing.s),
                  Wrap(
                    spacing: LrSpacing.xs,
                    runSpacing: LrSpacing.xs,
                    children: <Widget>[
                      for (final CloudImportChannel c in CloudImportChannel.values)
                        Chip(
                          label: Text(CloudImportLabels.names[c]!,
                              style: text.labelSmall),
                        ),
                    ],
                  ),
                  const SizedBox(height: LrSpacing.s),
                  Text(context.t('cloudChannelsNote'), style: text.labelSmall),
                  const SizedBox(height: LrSpacing.s),
                  Text(context.t('mergeRecordsNote'), style: text.labelSmall),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.s),
            GlassPanel(
              padding: const EdgeInsets.all(LrSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(context.t('uiImportFormats'), style: text.titleMedium),
                  const SizedBox(height: LrSpacing.s),
                  Text(context.t('wenkuFormatsNote'), style: text.labelSmall),
                  const SizedBox(height: LrSpacing.s),
                  Text('${context.t('importFormats')}\n${context.t('archiveNotice')}',
                      style: text.bodySmall),
                  const SizedBox(height: LrSpacing.s),
                  Text(context.t('permissionNotice'), style: text.labelSmall),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.l),

            // ------------------------------------------------ 收藏
            _SectionTitle(context.t('profileSectionFavorites'), text),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(context.tArgs('uiItems8', <Object?>[favorites.length]), style: text.labelSmall),
                      const Spacer(),
                      Text(context.t('favoriteLocalNote'), style: text.labelSmall),
                    ],
                  ),
                  const SizedBox(height: LrSpacing.s),
                  if (favorites.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: LrSpacing.s),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(context.t('favoriteEmptyTitle'), style: text.bodyMedium),
                          const SizedBox(height: LrSpacing.xs),
                          Text(context.t('favoriteEmptyBody'), style: text.bodySmall),
                        ],
                      ),
                    )
                  else
                    ...favorites.map<Widget>((FavoriteEntry entry) {
                      final BookSummary? book = state.resolveBook(entry.bookId);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.star, size: 18),
                        title: Text(book?.title ?? context.t('uiRemovedBook'), style: text.titleMedium),
                        subtitle: Text(
                          context.tArgs('uiTapToOpen', <Object?>[FavoriteTargetLabels.labels[entry.target]]),
                          style: text.labelSmall,
                        ),
                        trailing: IconButton(
                          tooltip: context.t('uiRemoveFavorite'),
                          icon: const Icon(Icons.star_border, size: 18),
                          onPressed: () => state.removeFavorite(entry.bookId),
                        ),
                        onTap: () {
                          final FavoriteNavigation? nav = FavoriteRouter.resolve(entry, book);
                          if (nav != null) onOpenFavorite?.call(nav);
                        },
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.l),

            // ------------------------------------------------ 支持与反馈
            _SectionTitle(context.t('profileSectionSupport'), text),
            GlassPanel(
              padding: const EdgeInsets.all(LrSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.volunteer_activism_outlined, size: 19,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: LrSpacing.s),
                      Text(context.t('supportTitle'), style: text.titleMedium),
                    ],
                  ),
                  const SizedBox(height: LrSpacing.s),
                  Text(context.t('supportBody'), style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: LrSpacing.s),
            GlassPanel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bug_report_outlined, size: 18),
                title: Text(context.t('feedbackTitle'), style: text.titleMedium),
                subtitle: Text(context.t('feedbackSubtitle'), style: text.bodySmall),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => unawaited(FeedbackSheet.open(context)),
              ),
            ),
            const SizedBox(height: LrSpacing.l),

            // ------------------------------------------------ 关于
            _SectionTitle(context.t('profileSectionAbout'), text),
            GlassPanel(
              padding: const EdgeInsets.all(LrSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ...context.tList('aboutParagraphs').map<Widget>(
                    (String paragraph) => Padding(
                      padding: const EdgeInsets.only(bottom: LrSpacing.s),
                      child: Text(paragraph, style: text.bodySmall),
                    ),
                  ),
                  const SizedBox(height: LrSpacing.xs),
                  ...Wenku8Compliance.rules.map<Widget>(
                    (String rule) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('· $rule', style: text.labelSmall),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: LrSpacing.xs),
    child: Divider(color: Theme.of(context).dividerTheme.color, height: 1),
);
}

/// 编辑式分组小标题：小字距、细线，和参考仓库的 editorial typography 对齐。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, this.text);

  final String label;
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: LrSpacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: text.labelLarge?.copyWith(letterSpacing: 1.4),
            ),
            const SizedBox(height: 4),
            Divider(color: Theme.of(context).dividerTheme.color, height: 1),
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.text, required this.value, required this.label});

  final TextTheme text;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Text(value, style: text.headlineMedium),
          const SizedBox(height: 2),
          Text(label, style: text.labelSmall),
        ],
      );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: enabled ? value : false,
      onChanged: enabled ? onChanged : null,
      title: Text(title, style: text.titleMedium?.copyWith(color: enabled ? null : text.bodySmall?.color)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle, style: text.bodySmall),
      ),
    );
  }
}
