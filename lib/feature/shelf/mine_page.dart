import 'package:Local_reader/core/ui/components/glass/Page.dart';
import 'package:flutter/material.dart';

import '../../assembly/app_scope.dart';
import '../../l10n/lr_localizations.dart';
import '../../core/ui/components/account_card.dart';
import '../../core/ui/components/menu_entry_card.dart';

/// 「我的」页（第三十轮按参考图重排，纯组件组合）。
///
/// 从上往下：Hero 头 → 账户卡 → 统计 / 书签 / 设置 / 关于 / 赞助与反馈。
/// 统计等能力**要点选才打开**；关于与各类提示统一收进「关于」子页。
/// 页面自身不持有任何跨页设置，五个入口都由 app 层注入。
class MinePage extends StatelessWidget {
  const MinePage({
    super.key,
    this.onOpenWenku8Login,
    this.onOpenStats,
    this.onOpenBookmarks,
    this.onOpenSettings,
    this.onOpenAbout,
    this.onOpenSupport,
  });

  final VoidCallback? onOpenWenku8Login;
  final VoidCallback? onOpenStats;
  final VoidCallback? onOpenBookmarks;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenAbout;
  final VoidCallback? onOpenSupport;

  @override
  Widget build(BuildContext context) {
    // 账户卡上的书库数量读全局状态；页面不缓存，导入后立刻可见。
    final AppState state = AppScope.of(context);
    final int bookCount = state.books.cached.length + state.importedCount;
    return LrPage.builder(
      header: PageScrollHeader(
        title: context.t('mineHeroTitle'),
        subtitle: context.t('mineHeroSubtitle'),
      ),
      itemCount: 6,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return AccountCard(
            accountLabel: context.t('mineAccountDemo'),
            pointsLabel: context.tArgs('minePoints', <Object?>[13]),
            levelLabel: context.t('mineLevel'),
            statusLabel: context.tArgs('mineSyncStatus', <Object?>[bookCount]),
            onTap: onOpenWenku8Login ?? () {},
          );
        }
        final _MineEntry entry = _entries(context)[index - 1];
        return MenuEntryCard(
          icon: entry.icon,
          title: entry.title,
          subtitle: entry.subtitle,
          onTap: entry.onTap,
        );
      },
    );
  }

  List<_MineEntry> _entries(BuildContext context) => <_MineEntry>[
        _MineEntry(Icons.bar_chart_outlined, context.t('mineStatsTitle'),
            context.t('mineStatsSubtitle'), onOpenStats ?? () {}),
        _MineEntry(Icons.bookmark_border, context.t('mineBookmarksTitle'),
            context.t('mineBookmarksSubtitle'), onOpenBookmarks ?? () {}),
        _MineEntry(Icons.settings_outlined, context.t('mineSettingsTitle'),
            context.t('mineSettingsSubtitle'), onOpenSettings ?? () {}),
        _MineEntry(Icons.info_outline, context.t('mineAboutTitle'),
            context.t('mineAboutSubtitle'), onOpenAbout ?? () {}),
        _MineEntry(Icons.favorite_border, context.t('mineSupportTitle'),
            context.t('mineSupportSubtitle'), onOpenSupport ?? () {}),
      ];
}

class _MineEntry {
  const _MineEntry(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// 历史类名兼容：早期轮次的文档与单测引用过这个名字。
typedef ProfilePage = MinePage;
