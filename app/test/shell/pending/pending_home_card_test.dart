import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/pending/pending_models.dart';
import 'package:carli/shell/pending/pending_badge.dart';
import 'package:carli/shell/pending/pending_home_card.dart';

import '../../core/pending/pending_fixtures.dart';
import '../../support/fake_api.dart';
import '../../support/finance_app.dart';

Widget _card(List<PendingFilter> opened) => Scaffold(
  body: ListView(
    children: [
      const PendingBadge(),
      PendingHomeCard(onOpen: opened.add),
    ],
  ),
);

void main() {
  testWidgets('summarises each pending type and opens it filtered', (tester) async {
    final opened = <PendingFilter>[];
    final api = FakeApi({'GET /v1/pending/summary': (_) => (200, pendingSummaryJson(uncategorized: 7))});
    await pumpFinance(tester, _card(opened), api);

    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.text('8 elementos por revisar'), findsOneWidget);
    expect(find.text('7 movimientos por categorizar'), findsOneWidget);
    expect(find.text('1 recurrente por confirmar'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);

    await tester.tap(find.text('7 movimientos por categorizar'));
    await tester.tap(find.text('Revisar'));
    expect(opened, [const PendingFilter(module: 'finance', type: 'uncategorized_transaction'), PendingFilter.all]);
  });

  testWidgets('renders nothing when there is nothing pending', (tester) async {
    final api = FakeApi({'GET /v1/pending/summary': (_) => (200, pendingSummaryJson(uncategorized: 0, recurring: 0))});
    await pumpFinance(tester, _card([]), api);

    expect(find.text('Pendientes'), findsNothing);
    expect(find.text('Revisar'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('renders nothing when the summary cannot be loaded', (tester) async {
    final api = FakeApi({
      'GET /v1/pending/summary': (_) => (500, {'message': 'boom'}),
    });
    await pumpFinance(tester, _card([]), api);

    expect(find.text('Pendientes'), findsNothing);
  });

  test('caps the badge label', () {
    expect(pendingBadgeLabel(7), '7');
    expect(pendingBadgeLabel(120), '99+');
  });
}
