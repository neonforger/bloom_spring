import 'dart:math' as math;
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'flower.dart';
import 'petal_editor.dart';

void main() => runApp(
      DevicePreview(
        // Wrap the app in a selectable device frame (pick an iPhone in the
        // toolbar) so it looks like it's running on a phone, as in the video.
        enabled: true,
        // Black canvas around the device, like the video.
        backgroundColor: Colors.black,
        builder: (context) => const MaurerApp(),
      ),
    );

class MaurerApp extends StatelessWidget {
  const MaurerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloom Spring',
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const MaurerHome(),
    );
  }
}

class MaurerHome extends StatefulWidget {
  const MaurerHome({super.key});

  @override
  State<MaurerHome> createState() => _MaurerHomeState();
}

class _MaurerHomeState extends State<MaurerHome>
    with SingleTickerProviderStateMixin {
  // Resting knob position: horizontally centred, ~30% down the editor so the
  // handle sits below the top of the line with headroom to stretch up.
  static const Offset _homeKnob = Offset(0, -0.43);

  // Normalized knob position in [-1, 1]^2. y -> petal stretch (up = contracted,
  // down = stretched), x -> extra twist/lean.
  Offset _knob = _homeKnob;

  late final AnimationController _spring;
  Offset _springFrom = Offset.zero;
  Offset _springTo = Offset.zero;

  // Radial petal length: contracted near the top, stretched toward the bottom.
  double get _stretch => 0.5 + (_knob.dy + 1) / 2 * 1.7; // 0.5 .. 2.2

  // Spiral twist, coupled to the stretch (no spiral at rest), plus lean.
  // Uses a smooth "soft positive" ramp so there is no derivative kink as the
  // bounce oscillates through rest (otherwise the settle feels like a jerk).
  double get _twist {
    final x = _stretch - 0.98;
    const k = 0.0025;
    final softPos = 0.5 * (x + math.sqrt(x * x + k)) - 0.5 * math.sqrt(k);
    return softPos * 1.25 + _knob.dx * 0.55;
  }

  @override
  void initState() {
    super.initState();
    _spring = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() {
          _knob = Offset.lerp(_springFrom, _springTo, _spring.value)!;
        });
      });
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _animateKnobTo(Offset target, {required bool bouncy}) {
    _spring.stop();
    _springFrom = _knob;
    _springTo = target;
    // Bouncy: strongly underdamped -> overshoots past rest and oscillates
    // several times (the "boing" of the video). Smooth: overdamped, no bounce.
    final spring = SpringDescription(
      mass: bouncy ? 1.8 : 2.2,
      stiffness: bouncy ? 75 : 55,
      damping: bouncy ? 4.5 : 30,
    );
    _spring.animateWith(SpringSimulation(spring, 0, 1, 0));
  }

  void _reset() => _animateKnobTo(_homeKnob, bouncy: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: FlowerPainter(stretch: _stretch, twist: _twist),
                ),
              ),
            ),
            _controlBar(),
          ],
        ),
      ),
    );
  }

  Widget _controlBar() {
    return Container(
      height: 264,
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
      child: Row(
        children: [
          // Draggable petal editor: vertical dotted axis -> d, horizontal -> n.
          _PetalEditor(
            knob: _knob,
            onStart: () => _spring.stop(),
            onDelta: (norm) {
              setState(() {
                // Accumulate each incremental drag delta onto the knob.
                _knob = Offset(
                  (_knob.dx + norm.dx).clamp(-1.0, 1.0),
                  (_knob.dy + norm.dy).clamp(-1.0, 1.0),
                );
              });
            },
            // Released petal stays where you leave it; the buttons animate
            // the return.
            onEnd: () {},
          ),
          const Spacer(),
          // Radios.
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RadioRow(
                label: 'Bounce Back',
                selected: false,
                onTap: () => _animateKnobTo(_homeKnob, bouncy: true),
              ),
              const SizedBox(height: 18),
              _RadioRow(
                label: 'Reset',
                selected: false,
                onTap: _reset,
              ),
            ],
          ),
        ],
      ),
    );
  }

}

/// The bottom-left teardrop control with a draggable handle on a dotted axis.
class _PetalEditor extends StatelessWidget {
  const _PetalEditor({
    required this.knob,
    required this.onStart,
    required this.onDelta,
    required this.onEnd,
  });

  final Offset knob; // [-1,1]^2
  final VoidCallback onStart;
  final ValueChanged<Offset> onDelta;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    const w = 160.0, h = 240.0;
    return GestureDetector(
      onPanStart: (_) => onStart(),
      onPanUpdate: (d) {
        // Match the handle's pixel range so it tracks the finger ~1:1.
        onDelta(Offset(d.delta.dx / 68.0, d.delta.dy / 111.0));
      },
      onPanEnd: (_) => onEnd(),
      child: CustomPaint(
        size: const Size(w, h),
        painter: _PetalEditorPainter(knob: knob),
      ),
    );
  }
}

class _PetalEditorPainter extends CustomPainter {
  _PetalEditorPainter({required this.knob});
  final Offset knob;

  @override
  void paint(Canvas canvas, Size size) =>
      paintPetalEditor(canvas, size, knob);

  @override
  bool shouldRepaint(covariant _PetalEditorPainter old) => old.knob != knob;
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white60, width: 1.4),
              color: selected ? Colors.white : Colors.transparent,
            ),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }
}
