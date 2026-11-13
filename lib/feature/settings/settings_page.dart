import 'package:Local_reader/core/ui/components/glass/Page.dart';
import 'package:flutter/material.dart';

import '../../assembly/app_navigation.dart';
import '../../assembly/app_services.dart';
import '../../domain/usecases/import_session.dart';
import '../../domain/usecases/favorite_routes.dart';
import '../../core/model/profile_summary.dart';
import '../../core/model/app_settings.dart' show AppThemeMode;
import '../../assembly/app_scope.dart';
import '../../core/model/performance_prefs.dart';
import '../../core/model/wenku/wenku8_registry.dart';
import '../../l10n/lr_localizations.dart';
import '../../core/ui/components/section_card.dart';
import '../../core/ui/theme/performance_scope.dart';
import '../../core/common/design_tokens.dart';
import 'sqlite_toggle.dart';

/// 设置页（第三十轮）：性能与动效、常规开关、外观阅读、来源与渠道。
///
/// 「帧率 / 设备检测 / 视觉效果 / 交互动效是否减少」四项都是
/// [PerformancePrefs] 的字段；归一化与生效值分别只走
/// `normalized()` 与 `PerformanceBudget.resolve()`，页面不解释规则。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppNavigation nav = AppNavigationScope.of(context);
    final PerformanceBudget budget = PerformanceScope.of(context);
    final PerformancePrefs prefs = state.settings.performance;
    final ProfileSummary summary = state.profileSummary;

    void update(PerformancePrefs next) => state.updateSettings(
          state.settings.copyWith(performance: next),
        );

    return LrPage.builder(
      header: PageScrollHeader(
        title: context.t('settingsHeroTitle'),
        subtitle: context.t('settingsHeroSubtitle'),
      ),
      itemCount: 6,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _PerformanceCard(
            prefs: prefs,
            budget: budget,
            globalMotion: state.settings.motion,
            onUpdate: update,
          );
        }
        if (index == 1) {
          return SectionCard(
            title: context.t('settingsGeneralTitle'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: state.settings.pureLocal,
                  onChanged: state.setPureLocal,
                  title: Text(context.t('uiPureLocalMode')),
                  subtitle:
                      Text(context.t('uiWhenOnTheAppMakesNoNetworkRequests')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: state.settings.motion,
                  onChanged: state.setMotion,
                  title: Text(context.t('uiInterfaceMotion2')),
                  subtitle: Text(context.t('perfMotionMasterNote')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: state.settings.tts,
                  onChanged: state.setTts,
                  title: Text(context.t('uiTtsReadAloud')),
                ),
                // 纯本地模式不再把开关设成 null（点了没反应）。
                // 打开时由 AppState 一次完成「关 master switch + 开能力」，
                // 归一化仍只走 AppSettings.normalized()，页面不自己解释规则。
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: state.settings.onlineDirectory,
                  onChanged: (bool v) => v
                      ? state.enableOnlineDirectory()
                      : state.setOnlineDirectory(false),
                  title: Text(context.t('uiOnlineDirectoryWenku8')),
                  subtitle: Text(state.settings.pureLocal
                      ? '当前为纯本地模式，开启后将允许在线目录请求'
                      : '关闭后不产生任何在线目录请求'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: state.settings.webdav,
                  onChanged: (bool v) =>
                      v ? state.enableWebdav() : state.setWebdav(false),
                  title: Text(context.t('uiWebdavBackup')),
                  subtitle: Text(state.settings.pureLocal
                      ? '当前为纯本地模式，开启后可配置 WebDAV 备份'
                      : '可在下方配置服务器并执行备份 / 恢复'),
                ),
                // SQLite 是可选初始化：默认关闭，置 true 才建表与预热。
                const SqliteToggle(),
              ],
            ),
          );
        }
        if (index == 2) {
          return SectionCard(
            title: context.t('settingsAppearanceTitle'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('主题明暗（浅色 / 暗色）',
                      style: Theme.of(context).textTheme.labelLarge),
                ),
                const SizedBox(height: LrSpacing.xs),
                _SegmentRow<AppThemeMode>(
                  values: AppThemeMode.values,
                  selected: state.settings.themeMode,
                  labelOf: (AppThemeMode m) {
                    switch (m) {
                      case AppThemeMode.system:
                        return '跟随系统';
                      case AppThemeMode.light:
                        return '浅色';
                      case AppThemeMode.dark:
                        return '深色';
                    }
                  },
                  onSelected: (AppThemeMode m) => state.updateSettings(
                    state.settings.copyWith(themeMode: m),
                  ),
                ),
                const SizedBox(height: LrSpacing.m),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.text_format_outlined),
                  title: Text(context.t('uiReadingLayout')),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: nav.onOpenReaderStyle,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.translate_outlined),
                  title: Text(context.t('localizationTitle')),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: nav.onOpenLocalizedTexts,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: Text(context.t('uiFeatureOverview')),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: nav.onOpenFeatureMatrix,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.login_outlined),
                  title: Text(context.t('wenkuLoginTitle')),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: nav.onOpenWenku8Login,
                ),
                // WebDAV 配置：五个备份动作都从这块面板发起，不再只改状态机。
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('WebDAV 备份配置'),
                  subtitle: const Text('服务器 / 账号 / 测试连接 / 备份 / 恢复 / 导出'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: nav.onOpenWebDav,
                ),
                // R13 导入书籍：此前四条路由已注册却没有任何入口，点击永远进不去。
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_copy_outlined),
                  title: const Text('导入书籍'),
                  subtitle: const Text('目录授权 → 扫描 → 冲突合并 → 写入书库'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: nav.onOpenImportBooks,
                ),
              ],
            ),
          );
        }
        if (index == 3) {
          return SectionCard(
            title: context.t('profileSectionSources'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final BookSource s in Wenku8Registry.sources)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LrSpacing.xs),
                    child: Row(
                      children: <Widget>[
                        Icon(
                            s.isOnline
                                ? Icons.cloud_outlined
                                : Icons.folder_open_outlined,
                            size: 17),
                        const SizedBox(width: LrSpacing.xs),
                        Text(s.title,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                const SizedBox(height: LrSpacing.xs),
                Wrap(
                  spacing: LrSpacing.xs,
                  children: <Widget>[
                    for (final CloudImportChannel c
                        in CloudImportChannel.values)
                      Chip(label: Text(CloudImportLabels.names[c]!)),
                  ],
                ),
                const SizedBox(height: LrSpacing.xs),
                Text(context.t('wenkuFormatsNote'),
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          );
        }
        if (index == 4) {
          return SectionCard(
            title: context.t('settingsCacheTitle'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(context.t('wenkuCacheNote'),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: LrSpacing.xs),
                Text('${context.t('uiMinutesToday')} ${summary.todayLabel}',
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: LrSpacing.xs),
                Text(context.t('importWizardStaticNote'),
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: LrSpacing.xs),
                TextButton(
                    onPressed: nav.onOpenImportWizard,
                    child: Text(context.t('importWizardTitle'))),
              ],
            ),
          );
        }
        return SectionCard(
          title: context.t('profileSectionFavorites'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final FavoriteEntry entry in state.favorites)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.star_border, size: 18),
                  title: Text(state.resolveBook(entry.bookId)?.title ??
                      context.t('uiRemovedBook')),
                  onTap: () {
                    final FavoriteNavigation? resolved = FavoriteRouter.resolve(
                        entry, state.resolveBook(entry.bookId));
                    if (resolved != null) nav.onOpenFavorite(resolved);
                  },
                ),
              if (state.favorites.isEmpty)
                Text(context.t('favoriteEmptyBody'),
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    required this.prefs,
    required this.budget,
    required this.globalMotion,
    required this.onUpdate,
  });

  final PerformancePrefs prefs;
  final PerformanceBudget budget;
  final bool globalMotion;
  final ValueChanged<PerformancePrefs> onUpdate;

  String _frameLabel(BuildContext context, FrameRateProfile p) {
    if (p == FrameRateProfile.power30) return context.t('perfFrameRate30');
    if (p == FrameRateProfile.standard60) return context.t('perfFrameRate60');
    if (p == FrameRateProfile.high120) return context.t('perfFrameRate120');
    return context.t('perfFrameRateAuto');
  }

  String _effectLabel(BuildContext context, VisualEffectLevel v) {
    if (v == VisualEffectLevel.reduced) return context.t('perfVisualReduced');
    if (v == VisualEffectLevel.minimal) return context.t('perfVisualMinimal');
    return context.t('perfVisualFull');
  }

  String _tierLabel(BuildContext context, DeviceTier t) {
    if (t == DeviceTier.low) return context.t('perfDeviceLow');
    if (t == DeviceTier.mid) return context.t('perfDeviceMid');
    if (t == DeviceTier.high) return context.t('perfDeviceHigh');
    return context.t('perfDeviceUnknown');
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SectionCard(
      title: context.t('perfSectionTitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(context.t('perfFrameRate'), style: text.labelLarge),
          const SizedBox(height: LrSpacing.xs),
          _SegmentRow<FrameRateProfile>(
            values: FrameRateProfile.values,
            selected: prefs.frameRate,
            labelOf: (FrameRateProfile p) => _frameLabel(context, p),
            onSelected: (FrameRateProfile p) =>
                onUpdate(prefs.copyWith(frameRate: p)),
          ),
          const SizedBox(height: LrSpacing.xs),
          Text(context.t('perfFrameRateNote'), style: text.labelSmall),
          const SizedBox(height: LrSpacing.m),
          Text(context.t('perfVisualEffects'), style: text.labelLarge),
          const SizedBox(height: LrSpacing.xs),
          _SegmentRow<VisualEffectLevel>(
            values: VisualEffectLevel.values,
            selected: prefs.visualEffects,
            labelOf: (VisualEffectLevel v) => _effectLabel(context, v),
            onSelected: (VisualEffectLevel v) =>
                onUpdate(prefs.copyWith(visualEffects: v)),
          ),
          const SizedBox(height: LrSpacing.m),
          Text(context.t('perfDeviceDetection'), style: text.labelLarge),
          const SizedBox(height: LrSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${_tierLabel(context, prefs.device.tier)}  ·  '
                  '${prefs.device.ramMB} MB  ·  '
                  '${prefs.device.cores}  ·  '
                  '${prefs.device.maxRefreshHz} Hz',
                  style: text.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final DeviceCapability detected =
                      await AppServices.of(context).device.detectCapability();
                  onUpdate(prefs.copyWith(device: detected));
                },
                child: Text(context.t('perfDeviceRedetect')),
              ),
            ],
          ),
          const SizedBox(height: LrSpacing.xs),
          Text(context.t('perfDeviceStaticNote'), style: text.labelSmall),
          if (budget.autoDegraded) ...<Widget>[
            const SizedBox(height: LrSpacing.xs),
            Text(context.t('perfDegradedNote'), style: text.labelSmall),
          ],
          const SizedBox(height: LrSpacing.m),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: prefs.reduceInteractionMotion || !globalMotion,
            onChanged: globalMotion
                ? (bool v) =>
                    onUpdate(prefs.copyWith(reduceInteractionMotion: v))
                : null,
            title: Text(context.t('perfReduceMotion')),
            subtitle: Text(context.t('perfReduceMotionNote')),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: prefs.autoDegradeByDevice,
            onChanged: (bool v) =>
                onUpdate(prefs.copyWith(autoDegradeByDevice: v)),
            title: Text(context.t('perfAutoDegrade')),
            subtitle: Text(context.t('perfAutoDegradeNote')),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: prefs.immersiveReading,
            onChanged: (bool v) =>
                onUpdate(prefs.copyWith(immersiveReading: v)),
            title: Text(context.t('perfImmersive')),
            subtitle: Text(context.t('perfImmersiveNote')),
          ),
        ],
      ),
    );
  }
}

class _SegmentRow<T> extends StatelessWidget {
  const _SegmentRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SegmentedButton<T>(
        segments: <ButtonSegment<T>>[
          for (final T v in values)
            ButtonSegment<T>(value: v, label: Text(labelOf(v))),
        ],
        selected: <T>{selected},
        onSelectionChanged: (Set<T> s) => onSelected(s.first),
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
      );
}
