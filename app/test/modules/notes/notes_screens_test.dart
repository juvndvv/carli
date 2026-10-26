import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:carli/modules/notes/data/local_db.dart';
import 'package:carli/modules/notes/data/models.dart';
import 'package:carli/modules/notes/data/notes_actions.dart';
import 'package:carli/modules/notes/data/notes_sync.dart';
import 'package:carli/modules/notes/screens/note_screen.dart';
import 'package:carli/modules/notes/screens/notes_screen.dart';
import 'package:carli/modules/notes/screens/shopping_view.dart';

import '../../support/fake_api.dart';
import '../../support/notes_support.dart';
import '../../support/routed_app.dart';

final _routes = [
  GoRoute(
    path: '/notas',
    builder: (context, state) => const NotesScreen(),
    routes: [
      GoRoute(path: 'n/:id', builder: (context, state) => NoteScreen(noteId: state.pathParameters['id']!)),
      GoRoute(path: 'carpeta/:id', builder: (context, state) => FolderScreen(folderId: state.pathParameters['id']!)),
    ],
  ),
  GoRoute(path: '/compra', builder: (context, state) => const ShoppingScreen()),
];

void main() {
  late NotesDatabase db;
  final now = DateTime(2026, 10, 26, 12);

  setUp(() => db = memoryNotesDatabase());
  tearDown(() => db.close());

  Future<NotesActions> pump(WidgetTester tester, String location, Future<void> Function(NotesActions) seed) async {
    final (container, _) = await pumpRouted(
      tester,
      FakeApi({}),
      initialLocation: location,
      routes: _routes,
      signedIn: false,
      overrides: notesOverrides(db, now: now),
    );
    final actions = container.read(notesActionsProvider);
    await tester.runAsync(() async {
      await container.read(notesStoreProvider).replaceWith(emptySnapshot(sections: defaultSections), today: now);
      await seed(actions);
    });
    await tester.pumpAndSettle();
    return actions;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows pinned notes, folders with recursive counts and recent notes', (tester) async {
    await pump(tester, '/notas', (actions) async {
      final house = await actions.createFolder('Casa');
      final works = await actions.createFolder('Reformas', parentId: house);
      final pinned = await actions.createNote(NoteType.text, title: 'Datos de la casa', body: 'Caldera');
      await actions.setPinned(pinned, true);
      await actions.createNote(NoteType.list, folderId: works, title: 'Maleta de viaje');
    });

    expect(find.text('Fijadas'), findsOneWidget);
    expect(find.text('Datos de la casa'), findsOneWidget);
    expect(find.bySemanticsLabel('Casa, 1 notas'), findsOneWidget);
    expect(find.text('Maleta de viaje'), findsOneWidget);
    expect(find.text('Casa › Reformas'), findsOneWidget);

    await tester.tap(find.text('Listas'));
    await tester.pumpAndSettle();
    expect(find.text('Datos de la casa'), findsNothing);
    expect(find.text('Maleta de viaje'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('ticks a product into the cart and finishes the trip', (tester) async {
    await pump(tester, '/compra', (actions) async {
      final list = await actions.createNote(NoteType.shopping, title: 'Súper');
      await actions.addProduct(list, 'Plátanos');
      await actions.addProduct(list, 'Leche');
    });

    expect(find.text('2 POR COMPRAR'), findsOneWidget);
    expect(find.text('FRUTA Y VERDURA'), findsOneWidget);

    await tester.tap(find.text('Plátanos'));
    await tester.pumpAndSettle();
    expect(find.text('1 POR COMPRAR'), findsOneWidget);
    expect(find.text('EN EL CARRO · 1'), findsOneWidget);

    await tester.tap(find.text('Terminar compra'));
    await tester.pumpAndSettle();
    expect(find.text('1 producto en el carro'), findsOneWidget);
    await tester.tap(find.text('Terminar compra').last);
    await tester.pumpAndSettle();

    expect(find.text('EN EL CARRO · 1'), findsNothing);
    expect(find.text('Compra terminada: 1 producto'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('adds products from the quick-add field', (tester) async {
    await pump(tester, '/compra', (actions) => actions.createNote(NoteType.shopping, title: 'Súper'));

    await tester.enterText(find.byType(TextField), 'Papel de cocina');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('LIMPIEZA'), findsOneWidget);
    expect(find.text('Papel de cocina'), findsOneWidget);
    await finish(tester);
  });
}
