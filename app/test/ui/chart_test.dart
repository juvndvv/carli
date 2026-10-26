import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/ui/chart.dart';

import '../support/pump.dart';

void main() {
  test('picks round axis steps', () {
    expect(niceStep(281000), 100000);
    expect(niceStep(604000), 200000);
    expect(niceStep(119300), 50000);
    expect(niceStep(4000), 1000);
    expect(niceStep(0), 100);
  });

  testWidgets('extends the line chart below zero and thins out long label rows', (tester) async {
    await pumpUi(
      tester,
      CarliChart(
        type: CarliChartType.line,
        semanticLabel: 'Saldo',
        labels: [for (var i = 0; i < 30; i++) '$i'],
        series: [
          CarliSeries('Saldo', [for (var i = 0; i < 30; i++) -150000 + i * 1000]),
        ],
      ),
    );

    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.minY, -150000);
    expect(data.maxY, 0);
  });
}
