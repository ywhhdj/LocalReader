import 'package:flutter/material.dart';

import '../../common/design_tokens.dart';
import 'glass/Nav.dart';

/// 带编辑式小标题的玻璃分区卡：小字距 + 细分隔线 + 内容插槽。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LrSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: text.labelLarge?.copyWith(letterSpacing: 1.4)),
          const SizedBox(height: LrSpacing.xs),
          Divider(color: Theme.of(context).dividerTheme.color, height: 1),
          const SizedBox(height: LrSpacing.xs),
          GlassPanel(child: child),
        ],
      ),
    );
  }
}

/// 通用空状态：标题 / 说明 / 可选动作，避免每个页面手写一份 EmptyState。
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LrSpacing.l),
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: text.titleMedium),
            const SizedBox(height: LrSpacing.xs),
            Text(body, style: text.bodySmall),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: LrSpacing.m),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
