import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/ui/select.dart';

import '../support/pump.dart';

void main() {
  testWidgets('lets a null option be picked', (tester) async {
    String? value = 'a';
    await pumpUi(
      tester,
      StatefulBuilder(
        builder: (context, setState) => CarliSelect<String?>(
          title: 'Cuenta',
          value: value,
          options: const [CarliOption('a', 'Una'), CarliOption(null, 'Ninguna')],
          onChanged: (picked) => setState(() => value = picked),
        ),
      ),
    );

    await tester.tap(find.text('Una'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ninguna'));
    await tester.pumpAndSettle();

    expect(value, isNull);
    expect(find.text('Ninguna'), findsOneWidget);
  });
}
