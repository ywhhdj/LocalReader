import 'package:flutter/material.dart';

import '../../common/design_tokens.dart';
import 'glass/Nav.dart';

/// 参考图里「统计 / 书签 / 设置 / 关于 / 赞助与反馈」那一行行大卡片。
/// 图标 + 主标题 + 副标题 + 右侧 chevron，整卡可点；组件不持有任何业务状态。
class MenuEntryCard extends StatelessWidget {
  const MenuEntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LrSpacing.m),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(
            horizontal: LrSpacing.m, vertical: LrSpacing.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(LrRadius.panel),
          onTap: onTap,
          child: Row(
            children: <Widget>[
              Icon(icon, size: 30, color: scheme.onSurface),
              const SizedBox(width: LrSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: text.titleLarge),
                    const SizedBox(height: LrSpacing.xs),
                    Text(subtitle, style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right, size: 20,
                  color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
