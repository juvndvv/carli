import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/format/dates.dart';
import 'package:carli/core/theme/tokens.dart';
import 'package:carli/modules/finance/data/json.dart';
import 'package:carli/modules/finance/screens/goals/goal_detail_screen.dart';
import 'package:carli/modules/finance/screens/goals/goals_screen.dart';
import 'package:carli/ui/button.dart';
import 'package:carli/ui/progress.dart';

import '../../../support/fake_api.dart';
import '../../../support/finance_app.dart';
import '../../../support/finance_fixtures.dart';

const nbsp = '\u00A0';

Json goalJson({
  String id = 'goal-trip',
  String name = 'Viaje a Japón',
  int target = 300000,
  int saved = 75000,
  String? targetDate = '2027-04-30',
  String? accountId,
  String? accountName,
  String icon = 'plane',
  bool achieved = false,
  int? monthly = 15000,
  int? monthsLeft = 6,
}) => {
  'id': id,
  'name': name,
  'target_cents': target,
  'target_date': targetDate,
  'account_id': accountId,
  'account': accountId == null ? null : {'id': accountId, 'name': accountName ?? 'Ahorro', 'type': 'savings'},
  'icon': icon,
  'color': null,
  'achieved': achieved,
  'achieved_at': achieved ? '2026-10-01T10:00:00+02:00' : null,
  'saved_cents': saved,
  'remaining_cents': target - saved < 0 ? 0 : target - saved,
  'progress_bp': saved >= target ? 10000 : saved * 10000 ~/ target,
  'months_left': monthsLeft,
  'monthly_needed_cents': monthly,
  'contributions_count': 2,
  'created_at': null,
  'updated_at': null,
};

Json contributionJson({String id = 'c-1', int amount = 50000, String date = '2026-10-01', String? note}) => {
  'id': id,
  'goal_id': 'goal-trip',
  'amount_cents': amount,
  'date': date,
  'note': note,
  'transaction_id': null,
  'created_at': null,
};

Map<String, FakeRoute> goalRoutes({Json? goal, List<Json>? contributions}) => {
  ...financeBaseRoutes(
    accounts: [
      accountJson(),
      accountJson(id: 'acc-save', name: 'Ahorro', type: 'savings'),
    ],
  ),
  'GET /v1/finance/goals/goal-trip': (_) => (200, {'data': goal ?? goalJson()}),
  'GET /v1/finance/goals/goal-trip/contributions': (_) => (
    200,
    {
      'data': contributions ?? [contributionJson(), contributionJson(id: 'c-2', amount: 25000, date: '2026-10-10')],
    },
  ),
};

Finder iconButton(String label) =>
    find.byWidgetPredicate((widget) => widget is CarliButton && widget.semanticLabel == label);

Json lastBody(FakeApi api, String method, [String? path]) =>
    api.requests.lastWhere((r) => r.method == method && (path == null || r.path == path)).data as Json;

void main() {
  testWidgets('lists goals with goal-toned progress and achieved ones last', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/goals': (_) => (
        200,
        {
          'data': [
            goalJson(id: 'goal-done', name: 'Fondo de emergencia', saved: 300000, achieved: true, icon: 'shield'),
            goalJson(),
            goalJson(
              id: 'goal-house',
              name: 'Entrada piso',
              targetDate: null,
              monthly: null,
              accountId: 'acc-save',
              icon: 'house',
            ),
          ],
        },
      ),
    });
    await pumpFinance(tester, const GoalsScreen(), api);

    expect(find.text('Objetivos de ahorro'), findsWidgets);
    expect(find.text('Viaje a Japón'), findsOneWidget);
    expect(find.text('750,00$nbsp€'), findsWidgets);
    expect(find.text('de 3.000,00$nbsp€'), findsWidgets);
    expect(find.text('25 %'), findsWidgets);
    expect(find.text('Meta: abr 2027 · aporta 150,00$nbsp€/mes', findRichText: true), findsOneWidget);
    expect(find.text('Sin fecha límite', findRichText: true), findsOneWidget);
    expect(find.text('Vinculado a la cuenta Ahorro'), findsOneWidget);
    expect(find.text('Ver cuenta'), findsOneWidget);

    final progress = tester.widgetList<CarliProgress>(find.byType(CarliProgress)).toList();
    expect(progress, hasLength(3));
    expect(progress.every((bar) => bar.tone == ProgressTone.goal), isTrue);
    final fill = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: find.byType(CarliProgress).first, matching: find.byType(DecoratedBox)),
        )
        .map((box) => (box.decoration as BoxDecoration).color);
    expect(fill, contains(CarliColors.light.primaryStrong));

    await tester.scrollUntilVisible(find.text('Objetivo conseguido', findRichText: true), 300);
    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((data) => const ['Fondo de emergencia', 'Viaje a Japón', 'Entrada piso'].contains(data))
        .toList();
    expect(names, ['Viaje a Japón', 'Entrada piso', 'Fondo de emergencia']);
  });

  testWidgets('shows the empty state and retries after an error', (tester) async {
    var fail = true;
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/goals': (_) => fail ? (500, {'message': 'boom'}) : (200, {'data': <Json>[]}),
    });
    await pumpFinance(tester, const GoalsScreen(), api);

    expect(find.text('No se han podido cargar los objetivos'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Reintentar'));
    await settle(tester);

    expect(find.text('Aún no tienes objetivos'), findsOneWidget);
    expect(find.text('Nuevo objetivo'), findsOneWidget);
  });

  testWidgets('validates and creates a goal with the Angular payload', (tester) async {
    final api = FakeApi({
      ...goalRoutes(),
      'GET /v1/finance/goals': (_) => (200, {'data': <Json>[]}),
      'POST /v1/finance/goals': (_) => (201, {'data': goalJson()}),
    });
    await pumpFinance(tester, const GoalsScreen(), api);

    await tester.tap(find.text('Nuevo objetivo'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo objetivo'), findsWidgets);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Indica cuánto quieres ahorrar.'), findsOneWidget);
    expect(find.text('Ponle un nombre al objetivo.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '3000');
    await tester.enterText(find.byType(TextField).at(1), '  Viaje a Japón ');
    await tester.tap(find.text('Viaje'));
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(lastBody(api, 'POST'), {
      'name': 'Viaje a Japón',
      'target_cents': 300000,
      'target_date': isoDate(addMonths(today(), 12)),
      'account_id': null,
      'icon': 'plane',
    });
    expect(find.text('Objetivo creado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('renders the goal detail with stats and contributions', (tester) async {
    final api = FakeApi(goalRoutes());
    await pumpFinance(tester, const GoalDetailScreen(goalId: 'goal-trip'), api);

    expect(find.text('Viaje a Japón'), findsWidgets);
    expect(find.text('Ahorrado'), findsOneWidget);
    expect(find.text('25 %'), findsOneWidget);
    expect(find.text('Te falta'), findsOneWidget);
    expect(find.text('2.250,00$nbsp€'), findsOneWidget);
    expect(find.text('150,00$nbsp€/mes'), findsOneWidget);
    expect(find.text('Durante 6 meses'), findsOneWidget);
    expect(find.text('abr 2027'), findsOneWidget);
    expect(find.text('30 abr 2027'), findsOneWidget);
    expect(tester.widget<CarliProgress>(find.byType(CarliProgress)).tone, ProgressTone.goal);

    await tester.scrollUntilVisible(find.text('Aportaciones'), 300);
    expect(find.text('+500,00$nbsp€'), findsOneWidget);
    expect(find.text('+250,00$nbsp€'), findsOneWidget);
    final rows = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((data) => data == '+500,00$nbsp€' || data == '+250,00$nbsp€')
        .toList();
    expect(rows, ['+250,00$nbsp€', '+500,00$nbsp€']);
  });

  testWidgets('shows the linked account and hides contributions for account goals', (tester) async {
    final api = FakeApi(
      goalRoutes(
        goal: goalJson(accountId: 'acc-save', accountName: 'Ahorro', saved: 300000, achieved: true),
      ),
    );
    await pumpFinance(tester, const GoalDetailScreen(goalId: 'goal-trip'), api);

    expect(find.text('Saldo de Ahorro'), findsOneWidget);
    expect(find.text('Conseguido'), findsOneWidget);
    expect(find.text('Nada, ¡lo tienes!'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(
      find.text('El progreso es el saldo de Ahorro. Para aportar, haz una transferencia a esa cuenta.'),
      findsOneWidget,
    );
    expect(find.text('Aportaciones'), findsNothing);
    expect(iconButton('Aportar'), findsNothing);
  });

  testWidgets('shows a not found state for a missing goal', (tester) async {
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/goals/goal-trip': (_) => (404, {'message': 'Not found'}),
    });
    await pumpFinance(tester, const GoalDetailScreen(goalId: 'goal-trip'), api);

    expect(find.text('No encontramos este objetivo'), findsOneWidget);
    expect(find.text('Volver a objetivos'), findsOneWidget);
  });

  testWidgets('withdraws money from a goal with a negative contribution', (tester) async {
    final api = FakeApi({
      ...goalRoutes(),
      'POST /v1/finance/goals/goal-trip/contributions': (_) => (
        201,
        {
          'data': contributionJson(id: 'c-3', amount: -15000),
          'meta': {'goal': goalJson(saved: 60000)},
        },
      ),
    });
    await pumpFinance(tester, const GoalDetailScreen(goalId: 'goal-trip'), api);

    await tester.tap(iconButton('Aportar'));
    await tester.pumpAndSettle();
    expect(find.text('Viaje a Japón · 750,00$nbsp€ de 3.000,00$nbsp€'), findsOneWidget);

    await tester.tap(find.text('Retirar'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Billetes');
    await tester.tap(find.widgetWithText(CarliButton, 'Retirar'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(lastBody(api, 'POST'), {'amount_cents': -15000, 'date': isoDate(today()), 'note': 'Billetes'});
    expect(find.text('−150,00$nbsp€ · Viaje a Japón al 20 %'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('celebrates when a contribution reaches the target', (tester) async {
    final api = FakeApi({
      ...goalRoutes(),
      'POST /v1/finance/goals/goal-trip/contributions': (_) => (
        201,
        {
          'data': contributionJson(id: 'c-3', amount: 225000),
          'meta': {'goal': goalJson(saved: 300000, achieved: true)},
        },
      ),
    });
    await pumpFinance(tester, const GoalDetailScreen(goalId: 'goal-trip'), api);

    await tester.tap(iconButton('Aportar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '2250');
    await tester.tap(find.widgetWithText(CarliButton, 'Aportar'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(lastBody(api, 'POST'), {'amount_cents': 225000, 'date': isoDate(today()), 'note': null});
    expect(find.text('¡Objetivo conseguido! Viaje a Japón al 100 %'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('deletes a contribution and restores it on undo', (tester) async {
    final api = FakeApi({
      ...goalRoutes(contributions: [contributionJson(note: 'Paga extra')]),
      'DELETE /v1/finance/goals/goal-trip/contributions/c-1': (_) => (204, null),
      'POST /v1/finance/goals/goal-trip/contributions': (_) => (
        201,
        {
          'data': contributionJson(id: 'c-9', note: 'Paga extra'),
          'meta': {'goal': goalJson()},
        },
      ),
    });
    await pumpFinance(tester, const GoalDetailScreen(goalId: 'goal-trip'), api);

    await tester.scrollUntilVisible(find.text('Paga extra'), 300);
    await tester.tap(iconButton('Borrar aportación del 1 oct'));
    await settle(tester);

    expect(api.requests.where((r) => r.method == 'DELETE'), hasLength(1));
    expect(find.text('Aportación borrada'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await settle(tester);

    expect(lastBody(api, 'POST'), {'amount_cents': 50000, 'date': '2026-10-01', 'note': 'Paga extra'});
  });

  testWidgets('edits a goal to follow an account balance', (tester) async {
    final api = FakeApi({
      ...goalRoutes(),
      'PATCH /v1/finance/goals/goal-trip': (_) => (200, {'data': goalJson(accountId: 'acc-save')}),
    });
    await pumpFinance(tester, const GoalDetailScreen(goalId: 'goal-trip'), api);

    await tester.tap(iconButton('Editar objetivo'));
    await tester.pumpAndSettle();
    expect(find.text('Editar objetivo'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Saldo de una cuenta'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Saldo de una cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(lastBody(api, 'PATCH'), {
      'name': 'Viaje a Japón',
      'target_cents': 300000,
      'target_date': '2027-04-30',
      'account_id': 'acc-save',
      'icon': 'plane',
    });
    expect(find.text('Objetivo actualizado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('deletes a goal after confirming', (tester) async {
    final api = FakeApi({...goalRoutes(), 'DELETE /v1/finance/goals/goal-trip': (_) => (204, null)});
    await pumpFinance(tester, const GoalDetailScreen(goalId: 'goal-trip'), api);

    await tester.tap(iconButton('Editar objetivo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(CarliButton, 'Eliminar'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(CarliButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar Viaje a Japón?'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Eliminar'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(api.requests.where((r) => r.method == 'DELETE' && r.path == '/v1/finance/goals/goal-trip'), hasLength(1));
    expect(find.text('Viaje a Japón eliminado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
