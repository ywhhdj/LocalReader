import 'package:flutter/material.dart';

/// 「可进入下一级」的通用列表行。
///
/// 固定 `trailing` 为 chevron 图标，向用户传达「点击进入」的语义。
/// leading 只收 [IconData]，若某处需要完全自定义 Icon widget，
/// 再单独走 ListTile 而不是加参数把这里塞厚。
class ChevronListTile extends StatelessWidget {
  const ChevronListTile({
    super.key,
    required this.icon,
    required this.title,
    this.desc,
    this.onTap,
    this.iconColor,
  });

  /// 左侧主图标。
  final IconData icon;

  /// 主标题（通常是 `context.t(...)` 的返回值）。
  final String title;

  /// 描述
  final String? desc;

  /// 点击回调。为 null 时 ListTile 自动降级为禁用态（不响应点击）。
  final VoidCallback? onTap;

  /// 图标颜色；不传则跟随 `colorScheme.primary`。
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme text = theme.textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor ?? theme.colorScheme.primary),
      title: Text(title, style: text.titleMedium),
      subtitle:
          desc == null ? null : Text(desc!, style: text.bodySmall),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}
