import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/format/money.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'pressable.dart';

enum CarliChartType { bar, line, donut }

double niceStep(int maxCents, {int ticks = 4}) {
  if (maxCents <= 0) return 100;
  final raw = maxCents / ticks;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final factor in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (factor * magnitude >= raw) return factor * magnitude;
  }
  return 10 * magnitude;
}

class CarliSeries {
  const CarliSeries(this.name, this.values);

  final String name;
  final List<int> values;
}

class CarliChart extends StatefulWidget {
  const CarliChart({
    super.key,
    required this.type,
    required this.labels,
    required this.series,
    required this.semanticLabel,
    this.height = 200,
    this.formatValue = formatMoneyCompact,
    this.formatDetail = formatMoney,
    this.colors,
    this.showLegend = true,
    this.centerLabel,
  });

  final CarliChartType type;
  final List<String> labels;
  final List<CarliSeries> series;
  final String semanticLabel;
  final double height;
  final String Function(int) formatValue;
  final String Function(int) formatDetail;
  final List<Color>? colors;
  final bool showLegend;
  final String? centerLabel;

  @override
  State<CarliChart> createState() => _CarliChartState();
}

class _CarliChartState extends State<CarliChart> {
  var _table = false;

  List<String> get _legendNames =>
      widget.type == CarliChartType.donut ? widget.labels : [for (final s in widget.series) s.name];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = widget.colors ?? colors.chart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s12,
      children: [
        if (_table)
          _ChartTable(labels: widget.labels, series: widget.series, formatDetail: widget.formatDetail)
        else
          Semantics(
            label: widget.semanticLabel,
            hint: 'Usa "Ver tabla" para leer los datos',
            child: ExcludeSemantics(
              child: SizedBox(height: widget.height, child: _chart(colors, palette)),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: !widget.showLegend
                  ? const SizedBox.shrink()
                  : Wrap(
                      spacing: CarliSpace.s12,
                      runSpacing: CarliSpace.s4,
                      children: [
                        for (final (index, name) in _legendNames.indexed)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 6,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: palette[index % palette.length],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              Text(name, style: CarliType.caption.copyWith(color: colors.text2)),
                            ],
                          ),
                      ],
                    ),
            ),
            Semantics(
              button: true,
              child: Pressable(
                onTap: () => setState(() => _table = !_table),
                child: Text(
                  _table ? 'Ver gráfico' : 'Ver tabla',
                  style: CarliType.caption.copyWith(color: colors.brandInk, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chart(CarliColors colors, List<Color> palette) {
    final axisStyle = CarliType.caption.copyWith(fontSize: 11, color: colors.text3);
    final maxValue = widget.series.expand((s) => s.values).fold<int>(0, math.max);
    final minValue = widget.series.expand((s) => s.values).fold<int>(0, math.min);
    final interval = niceStep(math.max(maxValue, -minValue));
    final top = maxValue <= 0 ? (minValue < 0 ? 0.0 : interval) : (maxValue / interval).ceil() * interval;
    final bottom = minValue < 0 ? (minValue / interval).floor() * interval : 0.0;
    final labelEvery = math.max(1, (widget.labels.length / 6).ceil());
    final grid = FlGridData(
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (_) => FlLine(color: colors.border, strokeWidth: 1),
    );
    final titles = FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: interval,
          getTitlesWidget: (value, meta) => Text(widget.formatValue(value.round()), style: axisStyle),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= widget.labels.length || value != index || index % labelEvery != 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(widget.labels[index], style: axisStyle),
            );
          },
        ),
      ),
    );
    final tooltipStyle = CarliType.caption.copyWith(color: colors.surface, fontWeight: FontWeight.w600);

    return switch (widget.type) {
      CarliChartType.bar => BarChart(
        BarChartData(
          gridData: grid,
          titlesData: titles,
          borderData: FlBorderData(show: false),
          maxY: top,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => colors.text,
              tooltipBorderRadius: BorderRadius.circular(CarliRadius.chip),
              getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                '${widget.series[rodIndex].name}\n${widget.formatDetail(rod.toY.round())}',
                tooltipStyle,
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < widget.labels.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  for (final (index, series) in widget.series.indexed)
                    BarChartRodData(
                      toY: series.values[i].toDouble(),
                      color: palette[index % palette.length],
                      width: widget.series.length > 1 ? 8 : 14,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                ],
              ),
          ],
        ),
      ),
      CarliChartType.line => LineChart(
        LineChartData(
          gridData: grid,
          titlesData: titles,
          borderData: FlBorderData(show: false),
          minY: bottom,
          maxY: top,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => colors.text,
              tooltipBorderRadius: BorderRadius.circular(CarliRadius.chip),
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${widget.series[spot.barIndex].name}: ${widget.formatDetail(spot.y.round())}',
                    tooltipStyle,
                  ),
              ],
            ),
          ),
          lineBarsData: [
            for (final (index, series) in widget.series.indexed)
              LineChartBarData(
                spots: [for (final (i, v) in series.values.indexed) FlSpot(i.toDouble(), v.toDouble())],
                color: palette[index % palette.length],
                barWidth: 2.5,
                isCurved: true,
                preventCurveOverShooting: true,
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
      CarliChartType.donut => Stack(
        alignment: Alignment.center,
        children: [
          if (widget.centerLabel case final label?)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: CarliType.caption.copyWith(color: colors.text3)),
                Text(
                  widget.formatValue(widget.series.first.values.fold(0, (sum, value) => sum + value)),
                  style: CarliType.money(CarliType.body).copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
              ],
            ),
          PieChart(
            PieChartData(
              centerSpaceRadius: widget.height * 0.28,
              sectionsSpace: 2,
              sections: [
                for (final (index, value) in widget.series.first.values.indexed)
                  PieChartSectionData(
                    value: value.toDouble(),
                    color: palette[index % palette.length],
                    radius: widget.height * 0.16,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ],
      ),
    };
  }
}

class _ChartTable extends StatelessWidget {
  const _ChartTable({required this.labels, required this.series, required this.formatDetail});

  final List<String> labels;
  final List<CarliSeries> series;
  final String Function(int) formatDetail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final head = CarliType.caption.copyWith(color: colors.text2, fontWeight: FontWeight.w600);
    final cell = CarliType.money(CarliType.small).copyWith(color: colors.text);
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.2)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CarliSpace.s8),
              child: Text('', style: head),
            ),
            for (final s in series) Text(s.name, textAlign: TextAlign.end, style: head),
          ],
        ),
        for (final (i, label) in labels.indexed)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(label, style: CarliType.small.copyWith(color: colors.text2)),
              ),
              for (final s in series) Text(formatDetail(s.values[i]), textAlign: TextAlign.end, style: cell),
            ],
          ),
      ],
    );
  }
}
