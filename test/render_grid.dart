import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_spring/flower.dart';

/// Renders rest -> stretched to verify the tips extend while the body/centre
/// stay fixed.  flutter test test/render_grid.dart
void main() {
  testWidgets('render flower tip stretch', (tester) async {
    const tile = 380.0;
    // (label, stretch, twist) mirroring the app's coupling.
    final states = <(String, double, double)>[
      ('rest 0.98', 0.98, 0.03),
      ('wind 1.5', 1.5, 0.6),
      ('wind 2.2', 2.2, 1.4),
      ('flare 0.6', 0.6, 0.0),
    ];

    final cols = states.length;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final totalW = cols * tile;
    const totalH = tile;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, totalW, totalH), Paint()..color = Colors.black);
    final label = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < states.length; i++) {
      final (name, stretch, twist) = states[i];
      canvas.save();
      canvas.translate(i * tile, 0);
      paintFlower(canvas, const Size(tile, tile), stretch, twist);
      label.text = TextSpan(
          text: name,
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 18));
      label.layout();
      label.paint(canvas, const Offset(12, 12));
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(totalW.toInt(), totalH.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final out = File('test_out/flower.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('WROTE ${out.absolute.path}');
  });
}
