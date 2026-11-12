import 'package:flutter/material.dart';

import 'package:Local_reader/core/model/book_identity.dart';
import 'package:Local_reader/core/ui/components/book/book_cover_card.dart';

/// 立体书架上的一本书（截图里的玻璃书脊）。
class ShelfSpineBook {
  const ShelfSpineBook({
    required this.id,
    required this.title,
    this.author = '',
    this.number = '',
    this.sourceBadge = '本地',
    this.code = '',
    this.tint = const Color(0xFF2A2F38),
    this.progress = 0,
    this.type = CoverBookType.novel,
    this.origin = CoverBookOrigin.local,
  });

  final String id;
  final String title;
  final String author;
  final String number;

  /// 兼容旧调用的角标文案；展示口径已由 [originLabel] 统一裁决。
  final String sourceBadge;
  final String code;
  final Color tint;
  final double progress;
  final CoverBookType type;

  /// 来源：决定右上角「本地 / 云端」与展示编号前缀。
  final CoverBookOrigin origin;

  String get originLabel => BookIdentity.originLabel(
        origin == CoverBookOrigin.cloud ? BookOrigin.cloud : BookOrigin.local,
      );

  /// 展示编号：本地 `LR-<bookid>`，云端 `WK-<bookid>`。
  /// 与书架列表、详情页共用 BookIdentity，一处改口径全端生效。
  String get displayId => BookIdentity.displayId(
        origin == CoverBookOrigin.cloud ? BookIdentity.cloudId(id) : id,
      );
}

/// 网格背景（截图里的细线 + 十字准星），自绘，不用图片资源。
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    const double step = 64;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    // 四角十字准星
    final Paint cross = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    for (final Offset o in <Offset>[
      const Offset(24, 24),
      Offset(size.width - 24, 24),
      Offset(24, size.height - 24),
      Offset(size.width - 24, size.height - 24),
    ]) {
      canvas.drawLine(Offset(o.dx - 6, o.dy), Offset(o.dx + 6, o.dy), cross);
      canvas.drawLine(Offset(o.dx, o.dy - 6), Offset(o.dx, o.dy + 6), cross);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color;
}

/// 单本斜置玻璃书脊：透视倾角 + 书页侧边 + 阴影 + 编号 / 书名 / 来源角标。
///
/// 所有文字、边线、图标都取 `Theme.colorScheme.onSurface` 及其透明度变体，
/// 浅色 / 暗色切换时一起改变；浅色主题把书脊底色向主题底色混合，
/// 保证深色文字压在彩色书脊上仍有足够对比。
class GlassSpine extends StatelessWidget {
  const GlassSpine({
    super.key,
    required this.book,
    required this.pulledOut,
    this.height = 300,
    this.width = 150,
    this.tilt = -0.22,
    this.onTap,
  });

  final ShelfSpineBook book;
  final bool pulledOut;

  /// 被「抽出」的书向前抬起 + 轻微放大；对应截图里可滑动抽出的交互。
  final double height;
  final double width;
  final double tilt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color fg = scheme.onSurface;
    // 浅色主题把书脊调浅，暗色主题保留书目封面色：文字统一用 onSurface。
    final Color spineBase =
        Color.lerp(book.tint, scheme.surface, isDark ? 0.12 : 0.55)!;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: pulledOut ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 220),
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(tilt)
            ..translate(0.0, pulledOut ? -18.0 : 0.0, pulledOut ? 24.0 : 0.0),
          alignment: FractionalOffset.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(4),
                right: Radius.circular(2),
              ),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  spineBase.withValues(alpha: 0.72),
                  spineBase,
                  Color.lerp(spineBase, fg, 0.12)!,
                ],
              ),
              border: Border.all(
                color: fg.withValues(alpha: pulledOut ? 0.32 : 0.14),
                width: 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.42),
                  blurRadius: pulledOut ? 24 : 12,
                  offset: const Offset(8, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (book.number.isNotEmpty)
                        Text(book.number,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: fg.withValues(alpha: 0.72))),
                      const Spacer(),
                      Text(book.originLabel,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: fg.withValues(alpha: 0.72))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (book.code.isNotEmpty)
                    Text('NO. ${book.code}',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: fg.withValues(alpha: 0.55),
                            letterSpacing: 1.4)),
                  const Spacer(),
                  // 竖排观感的斜置书名（截图里书名沿书脊排布）
                  Text(
                    book.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const Spacer(),
                  Text(book.displayId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: fg.withValues(alpha: 0.62))),
                  const SizedBox(height: 8),
                  if (book.progress > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: LinearProgressIndicator(
                        value: book.progress.clamp(0.0, 1.0).toDouble(),
                        minHeight: 3,
                        backgroundColor: fg.withValues(alpha: 0.24),
                      ),
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

/// 立体书架主体：横向滑动「抽出」书本，底部显示当前选中的书名与元信息。
///
/// 说明：截图右上三个圆形按钮（历史 / 导入 / 搜索）由页面通过 `topActions`
/// 注入，组件本身不读 Navigator、不 import assembly；这样「轻小说文库
/// HeaderNav 右侧只放搜索」的既定口径仍成立。
class Wenku3dShelf extends StatefulWidget {
  const Wenku3dShelf({
    super.key,
    required this.books,
    this.topActions = const <Widget>[],
    this.onExtract,
    this.onSelectionChanged,
    this.height = 520,
    this.pullOutOnSwipe = true,
  });

  final List<ShelfSpineBook> books;
  final List<Widget> topActions;
  final ValueChanged<ShelfSpineBook>? onExtract;
  final ValueChanged<ShelfSpineBook>? onSelectionChanged;
  final double height;

  /// 滑动即视为抽出当前书（默认开启）；关闭时只有点右上箭头才抽出。
  final bool pullOutOnSwipe;

  @override
  State<Wenku3dShelf> createState() => _Wenku3dShelfState();
}

class _Wenku3dShelfState extends State<Wenku3dShelf> {
  int _selected = 0;
  bool _pulledOut = false;

  ShelfSpineBook? get _current => widget.books.isEmpty
      ? null
      : widget.books[_selected.clamp(0, widget.books.length - 1)];

  void _onPageChanged(int i) {
    setState(() {
      _selected = i;
      _pulledOut = widget.pullOutOnSwipe;
    });
    final ShelfSpineBook? b = _current;
    if (b != null) widget.onSelectionChanged?.call(b);
  }

  /// 点书脊 / 抽出箭头都走这里：一定给出可见反馈，绝不静默失效。
  void _openAt(int index) {
    if (widget.books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书架还是空的，先去文库收藏一本书吧')),
      );
      return;
    }
    final int i = index.clamp(0, widget.books.length - 1);
    final ShelfSpineBook b = widget.books[i];
    setState(() {
      _selected = i;
      _pulledOut = true;
    });
    final ValueChanged<ShelfSpineBook>? onExtract = widget.onExtract;
    if (onExtract == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('《${b.title}》· ${b.displayId}')),
      );
      return;
    }
    onExtract(b);
  }

  void _extract() => _openAt(_selected);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color fg = scheme.onSurface;
    // 书架卡片背景随明暗切换：浅色用浅底，暗色用深底，文字始终取 onSurface。
    final Color background = isDark
        ? const Color(0xFF15171C)
        : Color.lerp(scheme.surface, Colors.white, 0.35)!;
    final ShelfSpineBook? current = _current;
    return SizedBox(
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: fg.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(
                      color: fg.withValues(alpha: isDark ? 0.08 : 0.10)),
                ),
              ),
              // 左上标题区（截图：书架 / 立体书架 + 英文副题）
              Positioned(
                left: 20,
                top: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('立体书架',
                        style: theme.textTheme.headlineSmall?.copyWith(
                            color: fg, fontWeight: FontWeight.w700)),
                    Text('COLLECTION / REGION  ·  PERSONAL ARCHIVE',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: fg.withValues(alpha: 0.45),
                            letterSpacing: 1.6)),
                  ],
                ),
              ),
              // 右上三个圆形工具按钮（由页面注入）
              if (widget.topActions.isNotEmpty)
                Positioned(
                  right: 16,
                  top: 16,
                  child: Row(children: widget.topActions),
                ),
              // 横向滑动抽出书本
              Positioned(
                left: 0,
                right: 0,
                top: 90,
                height: widget.height - 190,
                child: widget.books.isEmpty
                    ? Center(
                        child: Text('书架空空，去轻小说文库收藏吧',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: fg.withValues(alpha: 0.62))),
                      )
                    : PageView.builder(
                        controller: PageController(viewportFraction: 0.46),
                        itemCount: widget.books.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (BuildContext context, int i) => Center(
                          child: GlassSpine(
                            book: widget.books[i],
                            pulledOut: _pulledOut && i == _selected,
                            tilt: -0.22 + (i % 3) * 0.05,
                            onTap: () => _openAt(i),
                          ),
                        ),
                      ),
              ),
              // 底部当前选中书 + 抽出箭头（截图底部）
              Positioned(
                left: 20,
                right: 16,
                bottom: 18,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(current?.title ?? '轻小说文库',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                  color: fg, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            current == null
                                ? '本地书籍 · 云端书单'
                                : '${current.originLabel} · ${current.author.isEmpty ? '轻小说' : current.author}',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: fg.withValues(alpha: 0.58)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _extract,
                      tooltip: '抽出阅读',
                      icon: Icon(Icons.north_east, color: fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}