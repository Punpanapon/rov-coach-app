import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:rov_coach/data/models/vod_review.dart';

/// Paints all strokes (permanent + active + ephemeral) onto the canvas.
///
/// Rendering order:
///  1. `saveLayer` so partial eraser (`BlendMode.clear`) only affects the
///     drawing layer and does NOT punch through to the video iframe behind it.
///  2. Permanent strokes (pen, shapes, partial-eraser).
///  3. Active (in-progress) stroke preview.
///  4. `restore` to composite the drawing layer.
///  5. Ephemeral (laser) stroke drawn on top with a glow effect.
class DrawingPainter extends CustomPainter {
  final List<Stroke> permanentStrokes;
  final Stroke? activeStroke;
  final Stroke? ephemeralStroke;

  DrawingPainter({
    required this.permanentStrokes,
    this.activeStroke,
    this.ephemeralStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Save a layer so partial-eraser BlendMode.clear only clears drawing pixels
    canvas.saveLayer(Offset.zero & size, Paint());

    // Draw committed permanent strokes
    for (final stroke in permanentStrokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw the in-progress permanent stroke
    if (activeStroke != null) {
      _drawStroke(canvas, activeStroke!);
    }

    canvas.restore();

    // Draw the ephemeral (laser) glow stroke on TOP of the composited layer
    if (ephemeralStroke != null) {
      _drawLaser(canvas, ephemeralStroke!);
    }
  }

  // ── Stroke dispatcher ─────────────────────────────────────────────────
  void _drawStroke(Canvas canvas, Stroke stroke) {
    switch (stroke.toolType) {
      case DrawingTool.pen:
        _drawFreehand(canvas, stroke);
      case DrawingTool.rectangle:
        _drawRect(canvas, stroke);
      case DrawingTool.circle:
        _drawCircle(canvas, stroke);
      case DrawingTool.eraserPartial:
        _drawPartialEraser(canvas, stroke);
      case DrawingTool.arrow:
        _drawArrow(canvas, stroke);
      case DrawingTool.highlighter:
        _drawHighlighter(canvas, stroke);
      case DrawingTool.ruler:
        _drawRuler(canvas, stroke);
      // laser & whole-eraser are handled differently
      case DrawingTool.laser:
      case DrawingTool.eraserWhole:
      case DrawingTool.select:
      case DrawingTool.zoomArea:
      case DrawingTool.extractVideo:
        break;
      case DrawingTool.ephemeralPen:
        _drawFreehand(canvas, stroke);
    }
  }

  // ── Freehand pen ──────────────────────────────────────────────────────
  void _drawFreehand(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (var i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  // ── Rectangle shape ───────────────────────────────────────────────────
  void _drawRect(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;
    final rect = stroke.boundingRect;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect, paint);
  }

  // ── Circle / Ellipse shape ────────────────────────────────────────────
  void _drawCircle(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;
    final rect = stroke.boundingRect;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..style = PaintingStyle.stroke;

    canvas.drawOval(rect, paint);
  }

  // ── Partial eraser (BlendMode.clear) ──────────────────────────────────
  void _drawPartialEraser(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = ui.BlendMode.clear;

    final path = Path()
      ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (var i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  // ── Arrow (freehand line + arrowhead) ──────────────────────────────────
  void _drawArrow(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (var i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }
    canvas.drawPath(path, paint);

    // Draw arrowhead at the tip using the last two points for direction
    final tip = stroke.points.last;
    final prev = stroke.points[stroke.points.length - 2];
    final angle = (tip - prev).direction;
    const headLength = 18.0;
    const headAngle = 0.5; // ~28 degrees

    final left = tip - Offset.fromDirection(angle - headAngle, headLength);
    final right = tip - Offset.fromDirection(angle + headAngle, headLength);

    final headPaint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill;

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(headPath, headPaint);
  }

  // ── Highlighter (thick translucent stroke) ────────────────────────────
  void _drawHighlighter(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.color.withAlpha(90)
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (var i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  // ── Ruler / Range ring (hollow circle from origin to current) ─────────
  void _drawRuler(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;

    final center = stroke.points.first;
    final edge = stroke.points.last;
    final radius = (edge - center).distance;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, paint);

    // Draw a dashed radial line from center to edge
    final linePaint = Paint()
      ..color = stroke.color.withAlpha(150)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(center, edge, linePaint);

    // Display the radius as text
    final mid = Offset((center.dx + edge.dx) / 2, (center.dy + edge.dy) / 2);
    final label = '${radius.round()}px';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: stroke.color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, mid - Offset(tp.width / 2, tp.height + 2));
  }

  // ── Laser with glow ──────────────────────────────────────────────────
  void _drawLaser(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;

    final path = Path()
      ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (var i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }

    // Outer glow
    final glowPaint = Paint()
      ..color = stroke.color.withAlpha(80)
      ..strokeWidth = stroke.width + 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawPath(path, glowPaint);

    // Core line
    final corePaint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
