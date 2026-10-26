import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/modules/finance/data/json.dart';
import 'package:carli/modules/finance/screens/categories/categories_screen.dart';
import 'package:carli/modules/finance/screens/categories/category_form_sheet.dart';

import '../../../support/fake_api.dart';
import '../../../support/finance_app.dart';
import '../../../support/finance_fixtures.dart';

Json adminCategoryJson(
  String id,
  String name, {
  String kind = 'expense',
  String? parentId,
  String? icon,
  String? color,
  bool opensPeriod = false,
  bool archived = false,
  List<Json> children = const [],
}) => {
  'id': id,
  'name': name,
  'kind': kind,
  'parent_id': parentId,
  'icon': icon,
  'color': color,
  'sort_order': 0,
  'opens_period': opensPeriod,
  'archived': archived,
  'children': children,
};

List<Json> defaultTree() => [
  adminCategoryJson(
    'cat-home',
    'Casa',
    icon: 'house',
    color: 'c2',
    children: [
      adminCategoryJson('cat-rent', 'Alquiler', parentId: 'cat-home', icon: 'key-round'),
      adminCategoryJson('cat-power', 'Luz', parentId: 'cat-home'),
      adminCategoryJson('cat-old', 'Antigua', parentId: 'cat-home', archived: true),
    ],
  ),
  adminCategoryJson('cat-food', 'Comida', icon: 'utensils'),
  adminCategoryJson('cat-salary', 'Nómina', kind: 'income', icon: 'wallet', opensPeriod: true),
];

FakeApi categoriesApi({List<Json>? tree, List<Json>? tags, Map<String, FakeRoute> extra = const {}}) => FakeApi({
  ...financeBaseRoutes(),
  'GET /v1/finance/categories': (_) => (200, {'data': tree ?? defaultTree()}),
  if (tags != null) 'GET /v1/finance/tags': (_) => (200, {'data': tags}),
  ...extra,
});

Json tagJson(String id, String name, int count) => {'id': id, 'name': name, 'color': null, 'transactions_count': count};

Future<void> step(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await settle(tester);
}

Future<void> openMenu(WidgetTester tester, String name) async {
  await tester.tap(find.bySemanticsLabel('Opciones de $name'));
  await step(tester);
}

Finder formScrollable() => find.descendant(of: find.byType(CategoryFormSheet), matching: find.byType(Scrollable)).first;

Json requestBody(FakeApi api, String method) => api.requests.lastWhere((r) => r.method == method).data as Json;

void main() {
  testWidgets('renders the hierarchy with badges and toggles archived categories', (tester) async {
    await pumpFinance(tester, const CategoriesScreen(), categoriesApi());

    expect(find.text('Categorías y etiquetas'), findsWidgets);
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('2 subcategorías'), findsOneWidget);
    expect(find.text('Alquiler'), findsOneWidget);
    expect(find.text('Luz'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Antigua'), findsNothing);
    expect(find.text('Nómina'), findsNothing);

    await tester.tap(find.text('1 archivada · mostrar'));
    await step(tester);
    expect(find.text('Antigua'), findsOneWidget);
    expect(find.text('Archivada'), findsOneWidget);
    expect(find.text('1 archivada · ocultar'), findsOneWidget);

    await tester.tap(find.text('Ingresos'));
    await step(tester);
    expect(find.text('Nómina'), findsOneWidget);
    expect(find.text('Abre periodo'), findsOneWidget);
    expect(find.text('Casa'), findsNothing);
  });

  testWidgets('creates a top-level category with icon and colour', (tester) async {
    final api = categoriesApi(
      extra: {
        'POST /v1/finance/categories': (_) => (201, {'data': adminCategoryJson('cat-new', 'Mascotas')}),
      },
    );
    await pumpFinance(tester, const CategoriesScreen(), api);

    await tester.tap(find.bySemanticsLabel('Nueva categoría'));
    await step(tester);
    expect(find.text('Nueva categoría'), findsWidgets);

    await tester.tap(find.text('Guardar'));
    await step(tester);
    expect(find.text('Ponle un nombre.'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);

    await tester.enterText(find.byType(TextField), '  Mascotas ');
    final dog = find.bySemanticsLabel('dog');
    await tester.scrollUntilVisible(dog, 200, scrollable: formScrollable());
    await tester.tap(dog);
    final colour = find.bySemanticsLabel('Color 3');
    await tester.scrollUntilVisible(colour, 200, scrollable: formScrollable());
    await tester.tap(colour);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await step(tester);

    expect(requestBody(api, 'POST'), {
      'name': 'Mascotas',
      'icon': 'dog',
      'color': 'c3',
      'parent_id': null,
      'kind': 'expense',
    });
    expect(find.text('Categoría creada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('creates an income category that opens a period', (tester) async {
    final api = categoriesApi(
      extra: {
        'POST /v1/finance/categories': (_) => (201, {'data': adminCategoryJson('cat-new', 'Extra', kind: 'income')}),
      },
    );
    await pumpFinance(tester, const CategoriesScreen(), api);

    await tester.tap(find.bySemanticsLabel('Nueva categoría'));
    await step(tester);
    await tester.tap(find.text('Ingreso'));
    await step(tester);
    await tester.enterText(find.byType(TextField), 'Extra');
    final toggle = find.byType(CupertinoSwitch);
    await tester.scrollUntilVisible(toggle, 200, scrollable: formScrollable());
    await tester.tap(toggle);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await step(tester);

    expect(requestBody(api, 'POST'), {
      'name': 'Extra',
      'icon': null,
      'color': null,
      'opens_period': true,
      'parent_id': null,
      'kind': 'income',
    });
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('adds a subcategory from the menu without kind or colour', (tester) async {
    final api = categoriesApi(
      extra: {
        'POST /v1/finance/categories': (_) =>
            (201, {'data': adminCategoryJson('cat-new', 'Pienso', parentId: 'cat-food')}),
      },
    );
    await pumpFinance(tester, const CategoriesScreen(), api);

    await openMenu(tester, 'Comida');
    await tester.tap(find.text('Añadir subcategoría'));
    await step(tester);
    expect(find.text('Color en gráficos'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Pienso');
    await tester.tap(find.text('Guardar'));
    await step(tester);

    expect(requestBody(api, 'POST'), {'name': 'Pienso', 'icon': null, 'color': null, 'parent_id': 'cat-food'});
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('moves a category under another parent when editing', (tester) async {
    final api = categoriesApi(
      extra: {
        'PATCH /v1/finance/categories/cat-food': (_) => (200, {'data': adminCategoryJson('cat-food', 'Comida')}),
      },
    );
    await pumpFinance(tester, const CategoriesScreen(), api);

    await openMenu(tester, 'Comida');
    await tester.tap(find.text('Editar'));
    await step(tester);
    expect(find.text('Editar categoría'), findsOneWidget);
    expect(find.text('Gasto'), findsNothing);

    await tester.tap(find.text('Ninguna (categoría principal)'));
    await step(tester);
    await tester.tap(find.text('Casa').last);
    await step(tester);
    expect(find.text('Color en gráficos'), findsNothing);
    await tester.tap(find.text('Guardar'));
    await step(tester);

    expect(requestBody(api, 'PATCH'), {'name': 'Comida', 'icon': 'utensils', 'color': null, 'parent_id': 'cat-home'});
    expect(find.text('Categoría actualizada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('does not send the parent when editing a category with children', (tester) async {
    final api = categoriesApi(
      extra: {
        'PATCH /v1/finance/categories/cat-home': (_) => (200, {'data': adminCategoryJson('cat-home', 'Hogar')}),
      },
    );
    await pumpFinance(tester, const CategoriesScreen(), api);

    await openMenu(tester, 'Casa');
    await tester.tap(find.text('Editar'));
    await step(tester);
    expect(find.text('Dentro de'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Hogar');
    await tester.tap(find.text('Guardar'));
    await step(tester);

    expect(requestBody(api, 'PATCH'), {'name': 'Hogar', 'icon': 'house', 'color': 'c2'});
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('shows the validation error returned by the server', (tester) async {
    final api = categoriesApi(
      extra: {
        'POST /v1/finance/categories': (_) => (
          422,
          {
            'message': 'invalid',
            'errors': {
              'name': ['Ya existe una categoría con ese nombre.'],
            },
          },
        ),
      },
    );
    await pumpFinance(tester, const CategoriesScreen(), api);

    await tester.tap(find.bySemanticsLabel('Nueva categoría'));
    await step(tester);
    await tester.enterText(find.byType(TextField), 'Comida');
    await tester.tap(find.text('Guardar'));
    await step(tester);

    expect(find.text('Editar categoría'), findsNothing);
    expect(find.text('Ya existe una categoría con ese nombre.'), findsOneWidget);
  });

  testWidgets('archives a category with undo', (tester) async {
    final api = categoriesApi(
      extra: {
        'PATCH /v1/finance/categories/cat-food': (_) =>
            (200, {'data': adminCategoryJson('cat-food', 'Comida', archived: true)}),
      },
    );
    await pumpFinance(tester, const CategoriesScreen(), api);

    await openMenu(tester, 'Comida');
    await tester.tap(find.text('Archivar'));
    await step(tester);

    expect(requestBody(api, 'PATCH'), {'archived': true});
    expect(find.text('Comida archivada'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await step(tester);
    expect(requestBody(api, 'PATCH'), {'archived': false});
  });

  testWidgets('deletes a category reassigning its transactions', (tester) async {
    var attempts = 0;
    final api = categoriesApi(
      extra: {
        'DELETE /v1/finance/categories/cat-power': (options) {
          attempts++;
          if (options.queryParameters['reassign_to'] == null) {
            return (
              422,
              {
                'message': 'invalid',
                'errors': {
                  'reassign_to': ['La categoría tiene movimientos: elige otra categoría a la que reasignarlos.'],
                },
              },
            );
          }
          return (204, null);
        },
      },
    );
    await pumpFinance(tester, const CategoriesScreen(), api);

    await openMenu(tester, 'Luz');
    await tester.tap(find.text('Eliminar'));
    await step(tester);
    expect(find.text('Eliminar Luz'), findsOneWidget);

    await tester.tap(find.text('Eliminar').last);
    await step(tester);
    expect(find.text('La categoría tiene movimientos: elige otra categoría a la que reasignarlos.'), findsOneWidget);

    await tester.tap(find.text('No mover (solo si no tiene movimientos)'));
    await step(tester);
    expect(find.text('Casa › Antigua'), findsNothing);
    expect(find.text('Nómina'), findsNothing);
    await tester.tap(find.text('Casa › Alquiler'));
    await step(tester);
    await tester.tap(find.text('Eliminar').last);
    await step(tester);

    expect(attempts, 2);
    expect(api.requests.lastWhere((r) => r.method == 'DELETE').queryParameters, {'reassign_to': 'cat-rent'});
    expect(find.text('Categoría eliminada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('blocks deleting a category with subcategories', (tester) async {
    final api = categoriesApi();
    await pumpFinance(tester, const CategoriesScreen(), api);

    await openMenu(tester, 'Casa');
    await tester.tap(find.text('Eliminar'));
    await step(tester);

    expect(find.text('Tiene subcategorías. Muévelas o elimínalas antes de borrar esta categoría.'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await step(tester);
    expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
  });

  testWidgets('renames, merges and deletes tags', (tester) async {
    final api = categoriesApi(
      tags: [tagJson('t1', 'viaje', 3), tagJson('t2', 'vacaciones', 1)],
      extra: {
        'PATCH /v1/finance/tags/t1': (_) => (200, {'data': tagJson('t1', 'viajes', 3)}),
        'POST /v1/finance/tags/t1/merge': (_) => (200, {'data': tagJson('t2', 'vacaciones', 4)}),
        'DELETE /v1/finance/tags/t2': (_) => (204, null),
      },
    );
    await pumpFinance(tester, const CategoriesScreen(), api);

    await tester.tap(find.text('Etiquetas'));
    await step(tester);
    expect(find.text('#viaje'), findsOneWidget);
    expect(find.text('3 movimientos'), findsOneWidget);
    expect(find.text('1 movimiento'), findsOneWidget);
    expect(find.bySemanticsLabel('Nueva categoría'), findsNothing);

    await openMenu(tester, '#viaje');
    await tester.tap(find.text('Renombrar'));
    await step(tester);
    await tester.enterText(find.byType(TextField), ' #Viajes ');
    await tester.tap(find.text('Guardar'));
    await step(tester);
    expect(requestBody(api, 'PATCH'), {'name': 'viajes'});
    expect(find.text('Etiqueta renombrada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));

    await openMenu(tester, '#viaje');
    await tester.tap(find.text('Fusionar con…'));
    await step(tester);
    await tester.tap(find.text('Elige una etiqueta'));
    await step(tester);
    expect(find.text('#viaje'), findsWidgets);
    await tester.tap(find.text('#vacaciones').last);
    await step(tester);
    await tester.tap(find.text('Fusionar'));
    await step(tester);
    expect(requestBody(api, 'POST'), {'into_tag_id': 't2'});
    expect(find.text('#viaje fusionada con #vacaciones'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));

    await openMenu(tester, '#vacaciones');
    await tester.tap(find.text('Eliminar'));
    await step(tester);
    expect(find.text('¿Eliminar #vacaciones?'), findsOneWidget);
    await tester.tap(find.text('Eliminar').last);
    await step(tester);
    expect(api.requests.lastWhere((r) => r.method == 'DELETE').path, '/v1/finance/tags/t2');
    expect(find.text('Etiqueta eliminada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('shows empty states', (tester) async {
    await pumpFinance(tester, const CategoriesScreen(), categoriesApi(tree: const [], tags: const []));

    expect(find.text('Sin categorías'), findsOneWidget);
    await tester.tap(find.text('Nueva categoría'));
    await step(tester);
    expect(find.text('Guardar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await step(tester);

    await tester.tap(find.text('Etiquetas'));
    await step(tester);
    expect(find.text('Aún no hay etiquetas'), findsOneWidget);
  });

  testWidgets('retries after a loading error', (tester) async {
    var fail = true;
    final api = FakeApi({
      ...financeBaseRoutes(),
      'GET /v1/finance/categories': (_) => fail ? (500, {'message': 'boom'}) : (200, {'data': defaultTree()}),
    });
    await pumpFinance(tester, const CategoriesScreen(), api);

    expect(find.text('No se han podido cargar las categorías'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Reintentar'));
    await step(tester);
    expect(find.text('Casa'), findsOneWidget);
  });
}
