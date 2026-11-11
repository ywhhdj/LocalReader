import 'package:flutter/material.dart';

import '../../../core/common/design_tokens.dart';
import '../../../core/ui/components/glass/Nav.dart';

/// 参考用户给出的项目页左下角朗读悬浮球
///
/// 交互契约：
///   * 未朗读时右下角只有一颗「朗读」圆球 [TtsFab]；
///   * 开始朗读后换成左下角 [DraggableTtsProgressOrb]；
///   * 进度球可拖动、拖到左右 15% / 85% 边缘会贴边隐藏，留 24px 把手点开；
///   * 旋转封面 7 秒一圈，暂停时停在原地，减少交互动效时**不起无限 Ticker**。
/// 所有文案由调用页通过 ARB 传入，组件本身不读 locale、不读 AppState。

const double _orbWidth = 208;
const double _orbHeight = 64;
const double _edge = 12;
const double _peek = 24;

enum _OrbSide { left, right }

class TtsFab extends StatelessWidget {
  const TtsFab({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: GlassPanel(
          borderRadius: LrRadius.pill,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 50,
            height: 50,
            child: IconButton(
              tooltip: label,
              onPressed: onTap,
              icon: Icon(Icons.record_voice_over_outlined,
                  size: 26, color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
      );
}

class DraggableTtsProgressOrb extends StatefulWidget {
  const DraggableTtsProgressOrb({
    super.key,
    required this.title,
    required this.coverPath,
    required this.progress,
    required this.playing,
    required this.animationsEnabled,
    required this.snapDuration,
    required this.onTogglePlay,
    required this.onClose,
    required this.onOpenSettings,
    required this.pauseLabel,
    required this.resumeLabel,
    required this.closeLabel,
    required this.settingsLabel,
    required this.expandLabel,
    this.visible = true,
  });

  final String title;
  final String? coverPath;
  final double progress;
  final bool playing;
  final bool animationsEnabled;
  final Duration snapDuration;
  final VoidCallback onTogglePlay;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;
  final String pauseLabel;
  final String resumeLabel;
  final String closeLabel;
  final String settingsLabel;
  final String expandLabel;
  final bool visible;

  @override
  State<DraggableTtsProgressOrb> createState() =>
      _DraggableTtsProgressOrbState();
}

class _DraggableTtsProgressOrbState extends State<DraggableTtsProgressOrb> {
  Offset? _pos;
  _OrbSide? _hidden;
  bool _dragging = false;

  Offset _bottomLeft(Size parent) =>
      Offset(_edge, parent.height - _orbHeight - _edge - 76);

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size parent = Size(constraints.maxWidth, constraints.maxHeight);
        _pos ??= _bottomLeft(parent);
        final double minX = -_orbWidth + _peek;
        final double maxX = parent.width - _peek;
        final double maxY = parent.height - _orbHeight;
        final Offset target = _hidden == null
            ? _pos!
            : Offset(
                _hidden == _OrbSide.left
                    ? -_orbWidth + _peek
                    : parent.width - _peek,
                _pos!.dy.clamp(0.0, maxY < 0 ? 0.0 : maxY));

        return Stack(
          children: <Widget>[
            AnimatedPositioned(
              duration: _dragging ? Duration.zero : widget.snapDuration,
              curve: Curves.fastOutSlowIn,
              left: target.dx,
              top: target.dy.clamp(0.0, maxY < 0 ? 0.0 : maxY),
              child: AnimatedOpacity(
                duration: widget.animationsEnabled
                    ? const Duration(milliseconds: 160)
                    : Duration.zero,
                opacity: _hidden == null ? 1 : 0,
                child: IgnorePointer(
                  ignoring: _hidden != null,
                  child: GestureDetector(
                    onPanStart: (_) => setState(() => _dragging = true),
                    onPanUpdate: (DragUpdateDetails d) {
                      if (_hidden != null) return;
                      setState(() {
                        _pos = Offset(
                          (_pos!.dx + d.delta.dx).clamp(minX, maxX),
                          (_pos!.dy + d.delta.dy)
                              .clamp(0.0, maxY < 0 ? 0.0 : maxY),
                        );
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _dragging = false;
                        final double centerX = _pos!.dx + _orbWidth / 2;
                        if (centerX < parent.width * 0.15) {
                          _hidden = _OrbSide.left;
                        } else if (centerX > parent.width * 0.85) {
                          _hidden = _OrbSide.right;
                        } else {
                          _hidden = null;
                        }
                        if (_hidden == _OrbSide.left) {
                          _pos = Offset(_edge, _pos!.dy);
                        } else if (_hidden == _OrbSide.right) {
                          _pos = Offset(
                              parent.width - _orbWidth - _edge, _pos!.dy);
                        }
                      });
                    },
                    onPanCancel: () => setState(() => _dragging = false),
                    child: TtsProgressOrb(
                      title: widget.title,
                      coverPath: widget.coverPath,
                      progress: widget.progress,
                      playing: widget.playing,
                      animationsEnabled: widget.animationsEnabled,
                      onTogglePlay: widget.onTogglePlay,
                      onClose: widget.onClose,
                      onOpenSettings: widget.onOpenSettings,
                      pauseLabel: widget.pauseLabel,
                      resumeLabel: widget.resumeLabel,
                      closeLabel: widget.closeLabel,
                      settingsLabel: widget.settingsLabel,
                    ),
                  ),
                ),
              ),
            ),
            if (_hidden != null)
              Positioned(
                left: _hidden == _OrbSide.left ? 0 : parent.width - _peek,
                top: (_pos!.dy + (_orbHeight - 56) / 2)
                    .clamp(0.0, parent.height - 56),
                child: Semantics(
                  label: widget.expandLabel,
                  child: GestureDetector(
                    onTap: () => setState(() => _hidden = null),
                    child: Container(
                      width: _peek,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.94),
                        borderRadius: BorderRadius.horizontal(
                          left: _hidden == _OrbSide.right
                              ? const Radius.circular(16)
                              : Radius.zero,
                          right: _hidden == _OrbSide.left
                              ? const Radius.circular(16)
                              : Radius.zero,
                        ),
                      ),
                      child: Icon(
                        _hidden == _OrbSide.left
                            ? Icons.keyboard_arrow_right
                            : Icons.keyboard_arrow_left,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class TtsProgressOrb extends StatelessWidget {
  const TtsProgressOrb({
    super.key,
    required this.title,
    required this.coverPath,
    required this.progress,
    required this.playing,
    required this.animationsEnabled,
    required this.onTogglePlay,
    required this.onClose,
    required this.onOpenSettings,
    required this.pauseLabel,
    required this.resumeLabel,
    required this.closeLabel,
    required this.settingsLabel,
  });

  final String title;
  final String? coverPath;
  final double progress;
  final bool playing;
  final bool animationsEnabled;
  final VoidCallback onTogglePlay;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;
  final String pauseLabel;
  final String resumeLabel;
  final String closeLabel;
  final String settingsLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: LrRadius.pill,
      padding: const EdgeInsets.symmetric(
          horizontal: LrSpacing.xs, vertical: LrSpacing.xs),
      child: SizedBox(
        width: _orbWidth,
        height: _orbHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SpinningCover(
              title: title,
              coverPath: coverPath,
              spinning: playing,
              animationsEnabled: animationsEnabled,
            ),
            const SizedBox(width: LrSpacing.xs),
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 3,
                    color: scheme.primary,
                    backgroundColor: scheme.primary.withValues(alpha: 0.18),
                  ),
                  IconButton(
                    tooltip: playing ? pauseLabel : resumeLabel,
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onPressed: onTogglePlay,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                        color: scheme.primary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: settingsLabel,
              padding: EdgeInsets.zero,
              iconSize: 18,
              onPressed: onOpenSettings,
              icon: const Icon(Icons.tune_outlined),
            ),
            IconButton(
              tooltip: closeLabel,
              padding: EdgeInsets.zero,
              iconSize: 18,
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

/// 旋转封面：无封面时用书名首字 + 渐变填充。
/// 静态阶段不解码图片（页像素由 BookRenderBridge 提供，❄️ 冻结），
/// 所以 `coverPath` 只作为「是否有封面」的判据，不读文件系统。
class SpinningCover extends StatefulWidget {
  const SpinningCover({
    super.key,
    required this.title,
    required this.coverPath,
    required this.spinning,
    required this.animationsEnabled,
  });

  final String title;
  final String? coverPath;
  final bool spinning;
  final bool animationsEnabled;

  @override
  State<SpinningCover> createState() => _SpinningCoverState();
}

class _SpinningCoverState extends State<SpinningCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SpinningCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    // 减少交互动效时连 Ticker 都不起；暂停时停在当前角度，不回零。
    if (widget.spinning && widget.animationsEnabled) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
      if (!widget.animationsEnabled) _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.25)),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF8A6A4F), Color(0xFFC99AA6)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: RotationTransition(
          turns: _controller,
          child: Center(
            child: Text(
              widget.title.trim().isEmpty
                  ? 'B'
                  : widget.title.trim().substring(0, 1),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ),
      );
}
