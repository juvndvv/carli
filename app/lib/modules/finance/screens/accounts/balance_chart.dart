import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/chart.dart';
import '../../data/accounts_admin.dart';

const _labelEvery = 15;

({double min, double max, double step}) balanceAxis(List<BalancePoint> points) {
  final values = [for (final point in points) point.balanceCents];
  final low = values.fold<int>(0, math.min);
  final high = values.fold<int>(0, math.max);
  final step = niceStep(math.max(high - low, 1));
  final min = low >= 0 ? 0.0 : (low / step).floor() * step;
  final max = high <= 0 ? 0.0 : (high / step).ceil() * step;
  return (min: min, max: max == min ? min + step : max, step: step);
}

class BalanceChart extends StatelessWidget {
  const BalanceChart({super.key, required this.points, this.height = 220});

  final List<BalancePoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final axisStyle = CarliType.caption.copyWith(fontSize: 11, color: colors.text3);
    final tooltipStyle = CarliType.caption.copyWith(color: colors.surface, fontWeight: FontWeight.w600);
    final axis = balanceAxis(points);
    final last = points.isEmpty ? null : points.last;
    return Semantics(
      label: 'Evolución del saldo en los últimos 90 días',
      value: last == null ? null : 'Saldo hoy ${formatMoney(last.balanceCents)}',
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            minY: axis.min,
            maxY: axis.max,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: axis.step,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: value == 0 ? colors.text3 : colors.border, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  interval: axis.step,
                  getTitlesWidget: (value, meta) => Text(formatMoneyCompact(value.round()), style: axisStyle),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    final fromEnd = points.length - 1 - index;
                    if (value != index || index < 0 || index >= points.length || fromEnd % _labelEvery != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(formatShortDate(points[index].date), style: axisStyle),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => colors.text,
                tooltipBorderRadius: BorderRadius.circular(CarliRadius.chip),
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${formatShortDate(points[spot.x.round()].date)}: ${formatMoney(spot.y.round())}',
                      tooltipStyle,
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final (index, point) in points.indexed) FlSpot(index.toDouble(), point.balanceCents.toDouble()),
                ],
                color: colors.chart.first,
                barWidth: 2.5,
                isCurved: true,
                preventCurveOverShooting: true,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
