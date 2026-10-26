import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/ui/money_input.dart';

import '../support/pump.dart';

class _Harness extends StatefulWidget {
  const _Harness({this.initial, this.allowNegative = false, required this.values});

  final int? initial;
  final bool allowNegative;
  final List<int?> values;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late int? value = widget.initial;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CarliMoneyInput(
        value: value,
        allowNegative: widget.allowNegative,
        onChanged: (next) {
          widget.values.add(next);
          setState(() => value = next);
        },
      ),
      const TextField(key: Key('other')),
    ],
  );
}

String fieldText(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField).first).controller!.text;

void main() {
  testWidgets('shows the value grouped while not editing', (tester) async {
    await pumpUi(tester, _Harness(initial: 123456, values: []));

    expect(fieldText(tester), '1.234,56');
    expect(find.text('€'), findsOneWidget);
  });

  testWidgets('switches to an editable value on focus and back on blur', (tester) async {
    await pumpUi(tester, _Harness(initial: 123456, values: []));

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(fieldText(tester), '1234,56');

    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();
    expect(fieldText(tester), '1.234,56');
  });

  testWidgets('emits cents with comma decimals', (tester) async {
    final values = <int?>[];
    await pumpUi(tester, _Harness(values: values));

    await tester.enterText(find.byType(TextField).first, '42,5');

    expect(values.last, 4250);
  });

  testWidgets('drops characters that are not part of an amount', (tester) async {
    final values = <int?>[];
    await pumpUi(tester, _Harness(values: values));

    await tester.enterText(find.byType(TextField).first, '12a,3€');

    expect(fieldText(tester), '12,3');
    expect(values.last, 1230);
  });

  testWidgets('marks malformed amounts as invalid and emits null', (tester) async {
    final values = <int?>[];
    await pumpUi(tester, _Harness(initial: 100, values: values));

    await tester.enterText(find.byType(TextField).first, '1,2,3');
    await tester.pump();

    expect(values.last, isNull);
    expect(tester.state<CarliMoneyInputState>(find.byType(CarliMoneyInput)).invalid, isTrue);
  });

  testWidgets('rejects negative amounts unless allowed', (tester) async {
    final values = <int?>[];
    await pumpUi(tester, _Harness(values: values));
    await tester.enterText(find.byType(TextField).first, '-5');
    expect(fieldText(tester), '5');

    final allowed = <int?>[];
    await pumpUi(tester, _Harness(values: allowed, allowNegative: true));
    await tester.enterText(find.byType(TextField).first, '-5');
    expect(allowed.last, -500);
  });
}
