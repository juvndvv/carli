import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/dev/catalog_screen.dart';

import '../support/pump.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('renders every component without layout errors in ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(402 * 3, 874 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await pumpUi(tester, const CatalogScreen(), brightness: brightness);
      await tester.pump(const Duration(milliseconds: 300));

      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 12; i++) {
        await tester.drag(scrollable, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(find.text('Avisos y hojas'), findsOneWidget);
    });
  }
}
