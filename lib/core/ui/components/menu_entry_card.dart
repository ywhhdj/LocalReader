import 'package:flutter/material.dart';

import '../../common/design_tokens.dart';
import './glass/CornerBox.dart'; 

/// 参考图里「统计 / 书签 / 设置 / 关于 / 赞助与反馈」那一行行大卡片。
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
    final theme = Theme.of(context);
    final TextTheme text = theme.textTheme;
    final ColorScheme scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: LrSpacing.m),
      child: CornerBox(
        // 1. 取消 CornerBox 自带的内边距，把空间留给 InkWell 内部，保证点击热区和波纹范围完整
        padding: EdgeInsets.zero,

        // 2. 背景色：替换掉之前的毛玻璃，使用卡片底色（可根据你的主题改为 Colors.white 等）
        backgroundColor: theme.cardColor,

        // 3. 外边框：极淡的描边，配合四角框显得更精致
        borderColor: scheme.outlineVariant.withValues(alpha: 0.3),

        // 4. 四角颜色：使用主色或深色，让角标更醒目
        cornerColor: scheme.primary,

        // 可选：稍微给一点圆角，如果喜欢纯直角可以把这行删掉（默认是 0.0）
        borderRadius: 4.0,

        child: Material(
          color: Colors.transparent, // 透明 Material 用于承载水波纹
          borderRadius: BorderRadius.circular(4.0),
          clipBehavior: Clip.antiAlias, // 如果切了圆角，必须裁剪水波纹
          child: InkWell(
            onTap: onTap,
            child: Padding(
              // 将原来的 padding 移到这里
              padding: const EdgeInsets.symmetric(
                  horizontal: LrSpacing.m, vertical: LrSpacing.m),
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
                        Text(
                          subtitle,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
