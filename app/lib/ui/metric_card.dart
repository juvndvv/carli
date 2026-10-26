import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'card.dart';
import 'icon.dart';
import 'icon_names.dart';
import 'stat.dart';

/// Fitness-style metric tile: label, big figure, a short note and an optional mini bar chart
/// of recent values (three or more; neutral bars, the last one in `text`). The tone colours only the figure.
class CarliMetricCard extends StatelessWidget {
  const CarliMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.tone = CarliTone.normal,
    this.note,
    this.noteIcon,
    this.noteTone = CarliTone.muted,
    this.trend = const [],
    this.onTap,
    this.semanticLabel,
  });

  final String label;
  final String value;
  final CarliTone tone;
  final String? note;
  final CarliIconData? noteIcon;
  final CarliTone noteTone;
  final List<int> trend;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final noteColor = noteTone.resolve(colors);
    return Semantics(
      label: semanticLabel ?? [label, value, ?note].join(', '),
      button: onTap != null,
      excludeSemantics: true,
      child: CarliCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: CarliSpace.s4,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CarliType.bodyStrong.copyWith(color: colors.text2),
                  ),
                ),
                if (onTap != null) CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: CarliType.metric.copyWith(color: tone.resolve(colors))),
            ),
            if (note case final note?)
              Row(
                spacing: CarliSpace.s4,
                children: [
                  if (noteIcon case final icon?) CarliIcon(icon, size: 14, color: noteColor, strokeWidth: 2),
                  Flexible(
                    child: Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.small.copyWith(color: noteColor),
                    ),
                  ),
                ],
              ),
            if (trend.length > 2) ...[
              const SizedBox(height: CarliSpace.s8),
              SizedBox(
                height: 36,
                width: double.infinity,
                child: CustomPaint(
                  painter: _MiniBarsPainter(trend, base: colors.text3.withValues(alpha: 0.35), last: colors.text),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniBarsPainter extends CustomPainter {
  _MiniBarsPainter(this.values, {required this.base, required this.last});

  final List<int> values;
  final Color base;
  final Color last;

  @override
  void paint(Canvas canvas, Size size) {
    final peak = values.map((value) => value.abs()).fold<int>(0, math.max);
    if (peak == 0) return;
    const barWidth = 5.0;
    final step = math.min(14.0, (size.width - barWidth) / (values.length - 1));
    for (final (index, value) in values.indexed) {
      final height = math.max(barWidth, value.abs() / peak * size.height);
      final left = index * step;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          const Radius.circular(barWidth / 2),
        ),
        Paint()..color = index == values.length - 1 ? last : base,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniBarsPainter oldDelegate) =>
      oldDelegate.base != base || oldDelegate.last != last || !_sameValues(oldDelegate.values, values);

  static bool _sameValues(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
