import 'package:flutter_test/flutter_test.dart';

import 'package:carli/ui/chart.dart';

void main() {
  test('picks round axis steps', () {
    expect(niceStep(281000), 100000);
    expect(niceStep(604000), 200000);
    expect(niceStep(119300), 50000);
    expect(niceStep(4000), 1000);
    expect(niceStep(0), 100);
  });
}
