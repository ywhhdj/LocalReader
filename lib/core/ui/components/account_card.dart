import 'package:Local_reader/core/ui/components/menu_entry_card.dart';
import 'package:flutter/material.dart';

/// 参考图顶部账户卡：左侧证件图标、居中的大号账号、积分 / 等级 / 同步状态、右箭头。
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
    return MenuEntryCard(
        icon: Icons.contact_page_outlined,
        title: accountLabel,
        onTap: onTap,
        subtitle: "$pointsLabel  ·  $levelLabel\n$statusLabel");
  }
}
