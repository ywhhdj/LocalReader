import 'package:flutter/material.dart';

import '../../common/design_tokens.dart';
import 'glass.dart';

/// 参考图顶部账户卡：左侧证件图标、居中的大号账号、积分 / 等级 / 同步状态、右箭头。
/// 数值全部由调用方传入，组件自己不读 AppState。
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.accountLabel,
    required this.pointsLabel,
    required this.levelLabel,
    required this.statusLabel,
    required this.onTap,
  });

  final String accountLabel;
  final String pointsLabel;
  final String levelLabel;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LrSpacing.l),
      child: GlassPanel(
        padding: const EdgeInsets.all(LrSpacing.l),
        child: InkWell(
          borderRadius: BorderRadius.circular(LrRadius.panel),
          onTap: onTap,
          child: Row(
            children: <Widget>[
              Icon(Icons.contact_page_outlined, size: 48, color: scheme.onSurface),
              const SizedBox(width: LrSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(accountLabel, style: text.displaySmall),
                    const SizedBox(height: LrSpacing.xs),
                    Text('$pointsLabel  ·  $levelLabel', style: text.bodyMedium),
                    const SizedBox(height: LrSpacing.xs),
                    Text(statusLabel, style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 22, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
