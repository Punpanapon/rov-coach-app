import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:rov_coach/data/models/vod_review.dart';
import 'package:rov_coach/providers/vod_review_provider.dart';
import 'package:rov_coach/presentation/vod_review/twitch_player.dart';

/// A movable, resizable PIP widget that shows a cloned Twitch player
/// offset + clipped so only the user-drawn source rectangle is visible.
///
/// The "illusion" works because we place a second TwitchPlayer inside a
/// ClipRect → Transform pipeline:
///   ClipRect clips to the container size →
///   Transform.translate shifts the iframe by -sourceRect.topLeft →
///   Transform.scale scales the iframe content to fit the container.
class ExtractedPipWidget extends ConsumerStatefulWidget {
  final ExtractedPip pip;
  final String videoId;

  const ExtractedPipWidget({
    super.key,
    required this.pip,
    required this.videoId,
  });

  @override
  ConsumerState<ExtractedPipWidget> createState() => _ExtractedPipWidgetState();
}

class _ExtractedPipWidgetState extends ConsumerState<ExtractedPipWidget> {
  static const double _handleSize = 22;
  static const double _btnSize = 24;
  static const double _pad = 14;
  static const double _minSize = 60;

  late double _x;
  late double _y;
  late double _w;
  late double _h;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _x = widget.pip.x;
    _y = widget.pip.y;
    _w = widget.pip.width;
    _h = widget.pip.height;

    // Start sync after a short delay to let the PIP player initialise.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _syncTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _syncWithMain(),
      );
    });
  }

  @override
  void didUpdateWidget(covariant ExtractedPipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pip.id != widget.pip.id ||
        oldWidget.pip.x != widget.pip.x ||
        oldWidget.pip.y != widget.pip.y ||
        oldWidget.pip.width != widget.pip.width ||
        oldWidget.pip.height != widget.pip.height) {
      _x = widget.pip.x;
      _y = widget.pip.y;
      _w = widget.pip.width;
      _h = widget.pip.height;
    }
  }

  void _commitPosition() {
    ref.read(extractedPipsProvider.notifier).move(widget.pip.id, _x, _y);
  }

  void _commitSize() {
    ref.read(extractedPipsProvider.notifier).resize(widget.pip.id, _w, _h);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  /// Synchronise playback state from the main player to this PIP clone.
  void _syncWithMain() {
    final mainId = TwitchPlayerController.elementId(widget.videoId);
    final pipId = TwitchPlayerController.elementId(widget.videoId, widget.pip.id);

    // Play / pause sync
    final mainPaused = TwitchPlayerController.isPaused(mainId);
    final pipPaused = TwitchPlayerController.isPaused(pipId);
    if (mainPaused && !pipPaused) {
      TwitchPlayerController.pause(pipId);
    } else if (!mainPaused && pipPaused) {
      TwitchPlayerController.play(pipId);
    }

    // Seek sync — only correct drift > 2 seconds
    final mainTime = TwitchPlayerController.getCurrentTime(mainId);
    final pipTime = TwitchPlayerController.getCurrentTime(pipId);
    if ((mainTime - pipTime).abs() > 2.0) {
      TwitchPlayerController.seek(pipId, mainTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelectMode =
        ref.watch(drawingToolProvider) == DrawingTool.select;
    final src = widget.pip.sourceRect;

    // Scale factor from sourceRect → current container size.
    final scaleX = _w / src.width;
    final scaleY = _h / src.height;

    return Positioned(
      left: widget.pip.visible ? _x - _pad : -9999,
      top: widget.pip.visible ? _y - _pad : -9999,
      width: _w + _pad * 2,
      height: _h + _pad * 2,
      child: Opacity(
        opacity: widget.pip.visible ? 1.0 : 0.0,
        child: IgnorePointer(
        ignoring: !isSelectMode || !widget.pip.visible,
        child: Stack(
          children: [
            // ── PIP body: drag to move ──
            Positioned(
              left: _pad,
              top: _pad,
              width: _w,
              height: _h,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  setState(() {
                    _x += d.delta.dx;
                    _y += d.delta.dy;
                  });
                },
                onPanEnd: (_) => _commitPosition(),
                onPanCancel: _commitPosition,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelectMode
                          ? Colors.orangeAccent.withAlpha(220)
                          : Colors.amber.withAlpha(120),
                      width: isSelectMode ? 2.0 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      width: _w,
                      height: _h,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          maxWidth: double.infinity,
                          maxHeight: double.infinity,
                          child: Transform.scale(
                            scale: scaleX < scaleY ? scaleX : scaleY,
                            alignment: Alignment.topLeft,
                            child: Transform.translate(
                              offset: Offset(-src.left, -src.top),
                              child: SizedBox(
                                // Full board size (same as the main player)
                                width: 1920,
                                height: 1080,
                                child: PointerInterceptor(
                                  child: IgnorePointer(
                                    ignoring: true,
                                    child: TwitchPlayer(
                                      videoId: widget.videoId,
                                      interactive: false,
                                      uniqueId: widget.pip.id,
                                      muted: true,
                                      autoplay: true,
                                      startTime: widget.pip.startTime,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Delete button (top-right) ──
            Positioned(
              top: _pad - _btnSize / 2,
              right: _pad - _btnSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref
                    .read(extractedPipsProvider.notifier)
                    .remove(widget.pip.id),
                child: Container(
                  width: _btnSize,
                  height: _btnSize,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),

            // ── PIP label (top-left) ──
            Positioned(
              top: _pad - _btnSize / 2,
              left: _pad - _btnSize / 2,
              child: Container(
                width: _btnSize,
                height: _btnSize,
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade700,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_in_picture_alt,
                    size: 14, color: Colors.white),
              ),
            ),

            // ── Resize handle (bottom-right) ──
            Positioned(
              bottom: _pad - _handleSize / 2,
              right: _pad - _handleSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  setState(() {
                    _w = (_w + d.delta.dx).clamp(_minSize, 1200.0);
                    _h = (_h + d.delta.dy).clamp(_minSize, 900.0);
                  });
                },
                onPanEnd: (_) => _commitSize(),
                onPanCancel: _commitSize,
                child: Container(
                  width: _handleSize,
                  height: _handleSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.grey, width: 0.5),
                  ),
                  child: const Icon(Icons.open_in_full,
                      size: 12, color: Colors.black54),
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
