import 'package:Local_reader/feature/profile/pages/about_page.dart';
import 'package:flutter/material.dart';

import '../../../../../assembly/route_args.dart';
import '../../../../../l10n/lr_localizations.dart';
import 'bookmarks_page.dart';
import 'support_page.dart';

class MineSectionPage extends StatelessWidget {
  const MineSectionPage({
    super.key,
    required this.args,
    this.statsBuilder,
    this.settingsBuilder,
  });

  final MineSectionArgs args;

  /// 统计页与设置页由路由装配层注入：feature 之间不互相 import。
  final WidgetBuilder? statsBuilder;
  final WidgetBuilder? settingsBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(_title(context)),
      ),
      body: _body(context),
    );
  }

  String _title(BuildContext context) {
    if (args.section == MineSection.stats) return context.t('mineStatsTitle');
    if (args.section == MineSection.bookmarks) {
      return context.t('mineBookmarksTitle');
    }
    if (args.section == MineSection.settings) {
      return context.t('mineSettingsTitle');
    }
    if (args.section == MineSection.about) return context.t('mineAboutTitle');
    return context.t('mineSupportTitle');
  }

  Widget _body(BuildContext context) {
    if (args.section == MineSection.stats) {
      return statsBuilder?.call(context) ?? _fallback(context);
    }
    if (args.section == MineSection.bookmarks) return const BookmarksPage();
    if (args.section == MineSection.settings) {
      return settingsBuilder?.call(context) ?? _fallback(context);
    }
    if (args.section == MineSection.about) return const AboutPage();
    return const SupportPage();
  }

  /// 路由没注入 builder 时也不留白屏：给一句明确提示，文字仍随主题变化。
  Widget _fallback(BuildContext context) => Center(
        child: Text('页面内容暂不可用',
            style: Theme.of(context).textTheme.bodyMedium),
      );
}
