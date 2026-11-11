import 'package:flutter/material.dart';

import '../../../common/design_tokens.dart';
import '../glass/Nav.dart';

/// 阅读页的三块热区
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
              top: LrSpacing.xs,
              left: 0,
              right: 0,
              child: Center(
                child: GlassPanel(
                  borderRadius: LrRadius.pill,
                  padding: const EdgeInsets.symmetric(
                      horizontal: LrSpacing.xs, vertical: 2),
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
