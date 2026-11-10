import 'package:flutter/material.dart';

import '../../core/platform/render_bridge.dart';
import '../../core/widgets/glass.dart';
import '../../core/content/lr_localizations.dart';

/// 固定版式页（PDF / 漫画 / 图片型 EPUB）的展示壳。
/// 连续翻页走 Texture(textureId)；单页快照走编码位图；两者都由 BookRenderBridge 提供。
class NativePageView extends StatefulWidget {
  const NativePageView({
    super.key,
    required this.bridge,
    required this.handle,
    required this.pageIndex,
    required this.targetSize,
  });

  final BookRenderBridge bridge;
  final int handle;
  final int pageIndex;
  final Size targetSize;

  @override
  State<NativePageView> createState() => _NativePageViewState();
}

class _NativePageViewState extends State<NativePageView> {
  late Future<RenderedPage> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant NativePageView old) {
    super.didUpdateWidget(old);
    if (old.pageIndex != widget.pageIndex || old.targetSize != widget.targetSize) {
      _future = _load();
    }
  }

  Future<RenderedPage> _load() =>
      widget.bridge.render(widget.handle, widget.pageIndex, widget.targetSize);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RenderedPage>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<RenderedPage> snap) {
        if (snap.hasError) {
          return GlassPanel(
            child: Text(
              context.tArgs('uiPagesCurrent', <Object?>[snap.error]),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        if (!snap.hasData) {
          return AspectRatio(
            aspectRatio: widget.targetSize.width / widget.targetSize.height,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final RenderedPage page = snap.data!;
        if (page.textureId != null) {
          return AspectRatio(
            aspectRatio: page.aspectRatio,
            child: Texture(textureId: page.textureId!),
          );
        }
        return Image.memory(
          page.imageBytes!,
          width: widget.targetSize.width,
          height: widget.targetSize.height,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
      },
    );
  }
}
