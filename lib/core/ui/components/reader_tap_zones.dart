import 'package:flutter/material.dart';

import '../../common/design_tokens.dart';
import 'glass.dart';

/// 第三十轮：阅读页的三块热区。
///
/// 用户要求「点击中间收起按钮之类的，不应该占用阅读，左下角和右下角热区」。
/// 所以这里**不铺满整页**：只在左右下角各放 68×68 的透明热区（上一页 / 下一页），
/// 正文区域完全不拦截点选；中间只保留一枚可收起的小胶囊按钮（顶栏显隐）。
/// 章节底栏在热区下方 68px，不会被吞掉。
class ReaderTapZones extends StatelessWidget {
  const ReaderTapZones({
    super.key,
    required this.chromeVisible,
    required this.onToggleChrome,
    required this.onPrevious,
    required this.onNext,
    required this.toggleLabel,
    required this.previousLabel,
    required this.nextLabel,
  });

  final bool chromeVisible;
  final VoidCallback onToggleChrome;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final String toggleLabel;
  final String previousLabel;
  final String nextLabel;

  @override
  Widget build(BuildContext context) => Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            bottom: 76,
            width: 68,
            height: 68,
            child: Semantics(
              label: previousLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPrevious,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 76,
            width: 68,
            height: 68,
            child: Semantics(
              label: nextLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onNext,
              ),
            ),
          ),
          if (chromeVisible)
            Positioned(
              top: LrSpacing.s,
              left: 0,
              right: 0,
              child: Center(
                child: GlassPanel(
                  borderRadius: LrRadius.pill,
                  padding: const EdgeInsets.symmetric(
                      horizontal: LrSpacing.s, vertical: 2),
                  child: InkWell(
                    onTap: onToggleChrome,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.expand_less, size: 16),
                        const SizedBox(width: LrSpacing.xs),
                        Text(toggleLabel,
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}
