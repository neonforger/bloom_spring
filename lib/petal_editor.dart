import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Computes the geometry of a Maurer rose.
///
/// A Maurer rose is built from a "rose" curve `r = sin(n * theta)` by walking
/// 361 points where the angle advances by a fixed step `d` (in degrees) each
/// step, and joining consecutive points with straight lines. The smooth rose
/// is the same `r = sin(n * theta)` sampled finely (step of 1 degree).
class MaurerRose {
  const MaurerRose({required this.n, required this.d});

  /// Petal parameter. Even -> 2n petals, odd -> n petals.
  final double n;

  /// Angular step (degrees) of the Maurer walk. Drives the "web"/twist.
  final double d;

  static const double _deg2rad = math.pi / 180.0;

  /// The 361-point walk (the angular straight-line web).
  Path walkPath(Offset center, double radius) {
    final path = Path();
    for (int k = 0; k <= 360; k++) {
      final theta = k * d * _deg2rad;
      final r = math.sin(n * theta);
      final x = center.dx + radius * r * math.cos(theta);
      final y = center.dy + radius * r * math.sin(theta);
      if (k == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  /// The smooth underlying rose `r = sin(n * theta)` (rounded petals).
  Path rosePath(Offset center, double radius) {
    final path = Path();
    for (int k = 0; k <= 360; k++) {
      final theta = k * _deg2rad;
      final r = math.sin(n * theta);
      final x = center.dx + radius * r * math.cos(theta);
      final y = center.dy + radius * r * math.sin(theta);
      if (k == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }
}

class MaurerRosePainter extends CustomPainter {
  MaurerRosePainter({
    required this.n,
    required this.d,
    this.showRose = true,
    this.glow = true,
  });

  final double n;
  final double d;
  final bool showRose;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;
    final rose = MaurerRose(n: n, d: d);

    // Smooth rose underneath: dimmer.
    if (showRose) {
      final rosePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.35);
      canvas.drawPath(rose.rosePath(center, radius), rosePaint);
    }

    // Optional soft glow pass for the neon look.
    if (glow) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawPath(rose.walkPath(center, radius), glowPaint);
    }

    // The Maurer walk: crisp white lines.
    final walkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawPath(rose.walkPath(center, radius), walkPaint);
  }

  @override
  bool shouldRepaint(covariant MaurerRosePainter old) =>
      old.n != n ||
      old.d != d ||
      old.showRose != showRose ||
      old.glow != glow;
}

/// Paints the bottom-left petal editor: a wide, short teardrop whose rounded
/// lower body is fixed while only the top third stretches toward the draggable
/// handle (the top vertex / axis end). [knob] is normalized in [-1, 1]^2
/// (x -> n / horizontal skew, y -> d / vertical stretch).
void paintPetalEditor(Canvas canvas, Size size, Offset knob) {
  final cx = size.width / 2;

  // STATIC lower body: wide, short, rounded. Shoulders + bottom tip never move.
  const halfW = 52.0;
  final bulgeY = size.height * 0.66; // widest line (shoulders), sits low
  final anchor = Offset(cx, size.height - 16); // bottom tip (static)
  final shoulderR = Offset(cx + halfW, bulgeY); // static
  final shoulderL = Offset(cx - halfW, bulgeY); // static

  // Draggable top vertex with full free movement across the pad. The lower
  // body stays static; only the upper two lines (shoulder -> handle) stretch.
  final handleX = cx + knob.dx * (cx - 12);
  final handleY = 9 + (knob.dy + 1) / 2 * (size.height - 18);
  final handle = Offset(handleX, handleY);

  final petal = Path()
    ..moveTo(handle.dx, handle.dy)
    // upper-right: handle -> shoulderR (DEFORMS with the handle)
    ..quadraticBezierTo(
      shoulderR.dx, handle.dy + (shoulderR.dy - handle.dy) * 0.45,
      shoulderR.dx, shoulderR.dy,
    )
    // lower-right: shoulderR -> anchor (STATIC)
    ..cubicTo(
      shoulderR.dx, bulgeY + (anchor.dy - bulgeY) * 0.55,
      cx + 28, anchor.dy,
      anchor.dx, anchor.dy,
    )
    // lower-left: anchor -> shoulderL (STATIC)
    ..cubicTo(
      cx - 28, anchor.dy,
      shoulderL.dx, bulgeY + (anchor.dy - bulgeY) * 0.55,
      shoulderL.dx, shoulderL.dy,
    )
    // upper-left: shoulderL -> handle (DEFORMS with the handle)
    ..quadraticBezierTo(
      shoulderL.dx, handle.dy + (shoulderL.dy - handle.dy) * 0.45,
      handle.dx, handle.dy,
    );
  canvas.drawPath(
    petal,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.8
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white70,
  );

  // Static dashed vertical reference line through the centre of the pad.
  final dotted = Paint()
    ..strokeWidth = 4.0
    ..color = Colors.white38;
  const dash = 5.0, gap = 4.0;
  for (double y = 10; y < size.height - 10; y += dash + gap) {
    canvas.drawLine(
      Offset(cx, y),
      Offset(cx, math.min(y + dash, size.height - 10)),
      dotted,
    );
  }

  // Three lateral dots: light up by proximity of the axis, fade out smoothly.
  final dotX = cx + 63;
  const levels = [0.32, 0.50, 0.68];
  const band = 26.0;
  for (final lv in levels) {
    final dy = lv * size.height;
    final dist = (handle.dy - dy).abs();
    final t = (1 - dist / band).clamp(0.0, 1.0);
    final it = t * t * (3 - 2 * t); // smoothstep
    final c = Offset(dotX, dy);
    canvas.drawCircle(
      c,
      9.0,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..color = Colors.white.withValues(alpha: 0.30),
    );
    if (it > 0) {
      canvas.drawCircle(
        c,
        12 + 12 * it,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.30 * it)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawCircle(
        c,
        10.0,
        Paint()..color = Colors.white.withValues(alpha: it),
      );
    }
  }

  // The draggable handle (top vertex of the axis).
  canvas.drawCircle(handle, 8, Paint()..color = Colors.white);
  canvas.drawCircle(
    handle,
    12,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white54,
  );
}

/// Renders a Maurer rose to a PNG (used for offline tuning/verification).
Future<ui.Image> renderMaurerRose({
  required double n,
  required double d,
  double size = 800,
  bool showRose = true,
  bool glow = true,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size, size),
    Paint()..color = Colors.black,
  );
  MaurerRosePainter(n: n, d: d, showRose: showRose, glow: glow)
      .paint(canvas, Size(size, size));
  final picture = recorder.endRecording();
  return picture.toImage(size.toInt(), size.toInt());
}
