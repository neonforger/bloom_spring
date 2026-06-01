import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The approved layered-petal flower. At rest each petal is the exact broad
/// almond from before. Stretching does NOT scale the whole flower: the inner
/// half (base -> belly) stays anchored, and only the OUTER half (the tip) thins
/// and extends, curling into a spiral — the "static body + stretching tip"
/// mechanic of the petal editor. The central flower barely changes.
///
/// [stretch] drives the tip extension (rest == 0.98), [twist] curls the tips.
class _Layer {
  const _Layer({
    required this.count,
    required this.offset,
    required this.innerR,
    required this.baseLen, // rest petal length (fraction of R)
    required this.width, // full belly width (fraction of R)
    required this.belly, // 0..1 position of the widest point
    required this.inwardK, // how far the tip winds inward when stretched
    required this.thinPmax, // taper sharpness at full stretch (thinner tail)
    required this.twistK, // how strongly the tip curls
  });
  final int count;
  final double offset;
  final double innerR;
  final double baseLen;
  final double width;
  final double belly;
  final double inwardK;
  final double thinPmax;
  final double twistK;
}

// Holographic palette.
const _lineColor = Color(0xFFDDFFF4);
const _glowColor = Color(0x557FFFE6);

void paintFlower(Canvas canvas, Size size, double stretch, double twist) {
  final center = Offset(size.width / 2, size.height / 2);
  final R = math.min(size.width, size.height) * 0.46;

  // ext: 0 at rest (stretch 0.98). Positive -> tips wind INWARD (spiral, same
  // size). Negative -> tips flare OUTWARD (the "out" half of the bounce).
  final ext = ((stretch - 0.98) / 1.22).clamp(-0.6, 1.2);

  const layers = <_Layer>[
    // Outer broad petals (approved rest shape); tips wind inward when stretched.
    _Layer(
        count: 8,
        offset: 0,
        innerR: 0.05,
        baseLen: 0.80,
        width: 0.42,
        belly: 0.44,
        inwardK: 0.92,
        thinPmax: 2.6,
        twistK: 1.0),
    // Central flower, tier 1 (stays as the core).
    _Layer(
        count: 8,
        offset: 0,
        innerR: 0.045,
        baseLen: 0.26,
        width: 0.18,
        belly: 0.5,
        inwardK: 0.22,
        thinPmax: 1.0,
        twistK: 0.4),
    // Central flower, tier 2 (smaller, interleaved).
    _Layer(
        count: 8,
        offset: math.pi / 8,
        innerR: 0.025,
        baseLen: 0.15,
        width: 0.115,
        belly: 0.5,
        inwardK: 0.13,
        thinPmax: 1.0,
        twistK: 0.3),
  ];

  final glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 9.0
    ..strokeJoin = StrokeJoin.round
    ..color = _glowColor
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.6
    ..strokeJoin = StrokeJoin.round
    ..color = _lineColor;

  for (final layer in layers) {
    final innerR = R * layer.innerR;
    final l0 = R * layer.baseLen; // rest length
    final maxWidth = R * layer.width;
    final p = 0.85 + (layer.thinPmax - 0.85) * math.max(0.0, ext);
    final petalTwist = twist * layer.twistK; // gentle curl; motion is inward
    for (int i = 0; i < layer.count; i++) {
      final baseAngle = 2 * math.pi * i / layer.count + layer.offset;
      final petal = _petalPath(center, baseAngle, innerR, l0, layer.belly,
          maxWidth, ext, layer.inwardK, p, petalTwist);
      canvas.drawPath(petal, glow);
      canvas.drawPath(petal, line);
    }
  }

  // Clean central void.
  canvas.drawCircle(center, R * 0.022, Paint()..color = Colors.black);
}

/// One closed petal. Parametrised by t in [0,1]. The inner half (0 -> belly) is
/// the fixed almond rise. On the outer half, the radial fraction is pulled
/// inward by [ext] (so the tip winds toward the centre instead of growing
/// outward) and the angle sweeps by [twist] (the spiral). At rest (ext == 0,
/// p == 0.85, twist == 0) this is exactly the original almond.
Path _petalPath(
  Offset center,
  double baseAngle,
  double innerR,
  double l0,
  double belly,
  double maxWidth,
  double ext,
  double inwardK,
  double p,
  double twist,
) {
  const seg = 48;
  final left = <Offset>[];
  final right = <Offset>[];
  for (int i = 0; i <= seg; i++) {
    final t = i / seg;
    final outerT = ((t - belly) / (1 - belly)).clamp(0.0, 1.0);
    final sm = outerT * outerT * (3 - 2 * outerT); // smoothstep

    // Radial fraction: outer part winds inward (ext>0) or flares out (ext<0).
    final rf = (t - ext * inwardK * sm).clamp(0.02, 1.7);
    final r = innerR + l0 * rf;

    // Width: almond rise to the belly, taper (thinner when stretched) after.
    double w;
    if (t <= belly) {
      w = maxWidth *
          math.pow(math.sin((t / belly) * math.pi / 2), 0.85).toDouble();
    } else {
      w = maxWidth * math.pow(math.cos(outerT * math.pi / 2), p).toDouble();
    }

    final ang = baseAngle + twist * math.pow(outerT, 1.3).toDouble();
    final dir = Offset(math.cos(ang), math.sin(ang));
    final pt = center + dir * r;
    final perp = Offset(-dir.dy, dir.dx);
    left.add(pt + perp * (w / 2));
    right.add(pt - perp * (w / 2));
  }

  final outline = Path()..moveTo(left.first.dx, left.first.dy);
  for (final pt in left) {
    outline.lineTo(pt.dx, pt.dy);
  }
  for (int i = right.length - 1; i >= 0; i--) {
    outline.lineTo(right[i].dx, right[i].dy);
  }
  outline.close();
  return outline;
}

class FlowerPainter extends CustomPainter {
  FlowerPainter({required this.stretch, required this.twist});
  final double stretch;
  final double twist;

  @override
  void paint(Canvas canvas, Size size) =>
      paintFlower(canvas, size, stretch, twist);

  @override
  bool shouldRepaint(covariant FlowerPainter old) =>
      old.stretch != stretch || old.twist != twist;
}
