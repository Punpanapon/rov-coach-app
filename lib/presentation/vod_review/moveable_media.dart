import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/data/models/vod_review.dart';
import 'package:rov_coach/providers/vod_review_provider.dart';

/// A widget that displays an inserted image/video on the VOD canvas.
/// Uses local state for smooth 60fps dragging/resizing, only syncing
/// back to Riverpod on pan end.
class MoveableResizableMedia extends ConsumerStatefulWidget {
  final InsertedMedia media;
  const MoveableResizableMedia({super.key, required this.media});

  @override
  ConsumerState<MoveableResizableMedia> createState() =>
      _MoveableResizableMediaState();
}

class _MoveableResizableMediaState
    extends ConsumerState<MoveableResizableMedia> {
  static const double _handleSize = 22;
  static const double _btnSize = 24;
  static const double _pad = 14;
  static const double _minSize = 40;

  late double _x;
  late double _y;
  late double _w;
  late double _h;

  @override
  void initState() {
    super.initState();
    _x = widget.media.x;
    _y = widget.media.y;
    _w = widget.media.width;
    _h = widget.media.height;
  }

  @override
  void didUpdateWidget(covariant MoveableResizableMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.id != widget.media.id ||
        oldWidget.media.x != widget.media.x ||
        oldWidget.media.y != widget.media.y ||
        oldWidget.media.width != widget.media.width ||
        oldWidget.media.height != widget.media.height) {
      _x = widget.media.x;
      _y = widget.media.y;
      _w = widget.media.width;
      _h = widget.media.height;
    }
  }

  void _commitPosition() {
    ref.read(insertedMediaProvider.notifier).updateMedia(
          widget.media.copyWith(x: _x, y: _y),
        );
  }

  void _commitSize() {
    ref.read(insertedMediaProvider.notifier).updateMedia(
          widget.media.copyWith(width: _w, height: _h),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isSelectMode =
        ref.watch(drawingToolProvider) == DrawingTool.select;

    return Positioned(
      left: _x - _pad,
      top: _y - _pad,
      width: _w + _pad * 2,
      height: _h + _pad * 2,
      child: IgnorePointer(
        ignoring: !isSelectMode,
        child: Stack(
          children: [
            // ── Image body: drag to move ──
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
                          ? Colors.lightBlueAccent.withAlpha(200)
                          : Colors.white.withAlpha(100),
                      width: isSelectMode ? 2.0 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.memory(
                      widget.media.assetBytes,
                      width: _w,
                      height: _h,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            ),

            // ── Delete button (top-right of image) ──
            Positioned(
              top: _pad - _btnSize / 2,
              right: _pad - _btnSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref
                    .read(insertedMediaProvider.notifier)
                    .remove(widget.media.id),
                child: Container(
                  width: _btnSize,
                  height: _btnSize,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      size: 14, color: Colors.white),
                ),
              ),
            ),

            // ── Layer toggle button (top-left of image) ──
            Positioned(
              top: _pad - _btnSize / 2,
              left: _pad - _btnSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref
                    .read(insertedMediaProvider.notifier)
                    .toggleLayer(widget.media.id),
                child: Container(
                  width: _btnSize,
                  height: _btnSize,
                  decoration: BoxDecoration(
                    color: widget.media.isBackground
                        ? Colors.blueGrey
                        : Colors.amber.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.media.isBackground
                        ? Icons.flip_to_back
                        : Icons.flip_to_front,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // ── Resize handle (bottom-right of image) ──
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
    );
  }
}
