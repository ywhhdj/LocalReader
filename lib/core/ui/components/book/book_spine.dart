import 'package:flutter/material.dart';

import '../../../common/design_tokens.dart';

/// 立体书架上的单本书：透视倾角 + 书脊渐变高光 + 书页侧边 + 层板投影 + 阅读进度。
/// 参考仓库的「three-dimensional bookshelf」，这里用纯 Flutter Transform 重实现。
class BookSpine extends StatelessWidget {
  const BookSpine({
    super.key,
    required this.title,
    required this.author,
    required this.spineColor,
    this.progress = 0,
    this.height = 188,
    this.width = 38,
    this.tilt = -0.12,
    this.onTap,
  });

  final String title;
  final String author;
  final Color spineColor;
  final double progress;
  final double height;
  final double width;
  final double tilt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.96);

    return GestureDetector(
      onTap: onTap,
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012) // 透视深度
          ..rotateY(tilt),
        alignment: FractionalOffset.centerLeft,
        child: Container(
          width: width + 6,
          height: height,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(LrRadius.spine),
              right: Radius.circular(2),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.24),
                blurRadius: 10,
                offset: const Offset(5, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 书脊
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(LrRadius.spine)),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        spineColor.withValues(alpha: 0.72),
                        spineColor,
                        Color.lerp(spineColor, Colors.black, 0.28)!,
                      ],
                      stops: const <double>[0, 0.28, 1],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 12, 4, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 竖排书名（按码点切分，避免中文/emoji 被拆坏）
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Wrap(
                            direction: Axis.vertical,
                            spacing: 2,
                            runSpacing: 5,
                            children: title.runes
                                .take(9)
                                .map<Widget>((int r) => Text(
                                      String.fromCharCode(r),
                                      style: TextStyle(
                                        fontFamily: 'Noto Serif SC',
                                        fontFamilyFallback: const <String>[
                                          'Songti SC',
                                          'SimSun',
                                          'serif'
                                        ],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: ink,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 烫金细线
                      Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.45)),
                      const SizedBox(height: 6),
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 8.5, color: ink.withValues(alpha: 0.75)),
                      ),
                      if (progress > 0) ...<Widget>[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(LrRadius.pill),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 2.5,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.22),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.9)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 书页侧边
              Container(
                width: 6,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(2)),
                  gradient: LinearGradient(
                    colors: <Color>[
                      const Color(0xFFEFE9DC),
                      Color.lerp(const Color(0xFFEFE9DC), Colors.black, 0.18)!,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 层板：书架的横向木纹与投影，书籍排在其上。
class ShelfBoard extends StatelessWidget {
  const ShelfBoard({super.key, required this.colors, this.height = 12});

  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(3),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 8,
              offset: const Offset(0, 5)),
        ],
      ),
    );
  }
}
