import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';

/// One ring of [CarliRings]: [progress] is 0–1 for a partial ring and keeps
/// going past 1 (a second lap drawn over the first), as in Apple's activity rings.
/// A null progress draws only the track.
class CarliRingValue {
  const CarliRingValue(this.progress, this.color);

  final double? progress;
  final Color color;
}

/// Concentric activity rings, outer to inner, filling up on first build.
class CarliRings extends StatefulWidget {
  const CarliRings({
    super.key,
    required this.rings,
    this.size = 140,
    this.stroke = 16,
    this.gap = 3,
    required this.semanticLabel,
  });

  final List<CarliRingValue> rings;
  final double size;
  final double stroke;
  final double gap;
  final String semanticLabel;

  @override
  State<CarliRings> createState() => _CarliRingsState();
}

class _CarliRingsState extends State<CarliRings> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: CarliMotion.ring);
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  List<double?> _from = const [];

  @override
  void initState() {
    super.initState();
    _from = [for (final _ in widget.rings) 0];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(CarliRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = [
      for (var i = 0; i < widget.rings.length; i++)
        i >= oldWidget.rings.length || oldWidget.rings[i].progress != widget.rings[i].progress,
    ].any((value) => value);
    if (!changed) return;
    _from = [for (var i = 0; i < widget.rings.length; i++) _current(oldWidget.rings, i)];
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  double? _current(List<CarliRingValue> rings, int index) {
    if (index >= rings.length) return 0;
    final target = rings[index].progress;
    final from = index < _from.length ? (_from[index] ?? 0) : 0.0;
    if (target == null) return null;
    return from + (target - from) * _curve.value;
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = context.colors;
    return Semantics(
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, _) => CustomPaint(
            painter: _RingsPainter(
              rings: [
                for (var i = 0; i < widget.rings.length; i++)
                  CarliRingValue(_current(widget.rings, i), widget.rings[i].color),
              ],
              stroke: widget.stroke,
              gap: widget.gap,
              shadow: track.bg,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.rings, required this.stroke, required this.gap, required this.shadow});

  final List<CarliRingValue> rings;
  final double stroke;
  final double gap;
  final Color shadow;

  static const _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final (index, ring) in rings.indexed) {
      final radius = size.shortestSide / 2 - stroke / 2 - index * (stroke + gap);
      if (radius <= stroke / 2) break;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = ring.color.withValues(alpha: 0.2),
      );

      final progress = ring.progress;
      if (progress == null || progress <= 0) continue;
      paint.color = ring.color;
      if (progress < 1) {
        canvas.drawArc(rect, _start, progress * 2 * math.pi, false, paint);
        continue;
      }

      // Past a full lap: a full ring, then the overlap with a soft shadow under its rounded end.
      canvas.drawCircle(center, radius, paint..strokeCap = StrokeCap.butt);
      final sweep = (progress - 1).clamp(0.0, 1.0) * 2 * math.pi;
      final endAngle = _start + math.max(sweep, 0.0001);
      final end = center + Offset(math.cos(endAngle), math.sin(endAngle)) * radius;
      canvas.drawCircle(
        end + Offset(math.cos(endAngle + math.pi / 2), math.sin(endAngle + math.pi / 2)) * (stroke * 0.12),
        stroke / 2,
        Paint()
          ..color = shadow.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.18),
      );
      canvas.drawArc(rect, _start, math.max(sweep, 0.0001), false, paint..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) =>
      oldDelegate.stroke != stroke ||
      oldDelegate.gap != gap ||
      oldDelegate.shadow != shadow ||
      oldDelegate.rings.length != rings.length ||
      [
        for (var i = 0; i < rings.length; i++)
          oldDelegate.rings[i].progress != rings[i].progress || oldDelegate.rings[i].color != rings[i].color,
      ].any((value) => value);
}
