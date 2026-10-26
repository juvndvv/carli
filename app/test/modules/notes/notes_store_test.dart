import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/modules/notes/data/local_db.dart';
import 'package:carli/modules/notes/data/models.dart';
import 'package:carli/modules/notes/data/notes_actions.dart';
import 'package:carli/modules/notes/data/notes_store.dart';
import 'package:carli/modules/notes/data/notes_sync.dart';
import 'package:carli/modules/notes/data/restock.dart';
import 'package:carli/modules/notes/data/views.dart';

import '../../support/fake_api.dart';
import '../../support/notes_support.dart';
import '../../support/test_app.dart';

void main() {
  late NotesDatabase db;
  late ProviderContainer container;
  late FakeApi api;
  final now = DateTime(2026, 10, 26, 12);

  setUp(() async {
    db = memoryNotesDatabase();
    api = FakeApi({});
    container = testContainer(api, overrides: notesOverrides(db, now: now));
    await container.read(notesStoreProvider).replaceWith(emptySnapshot(sections: defaultSections), today: now);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> signIn() async {
    container.read(authControllerProvider);
    await pumpEventQueue();
    container.read(authControllerProvider.notifier).state = const SignedIn(null);
  }

  NotesActions actions() => container.read(notesActionsProvider);
  Future<NotesIndex> load() => container.read(notesStoreProvider).load();

  test('applies every change locally and queues it for the server', () async {
    final id = await actions().createNote(NoteType.text, title: 'Datos de la casa');
    await actions().updateNote(id, body: 'Caldera Vaillant');
    await actions().setPinned(id, true);

    final note = (await load()).note(id)!;
    expect(note.title, 'Datos de la casa');
    expect(note.body, 'Caldera Vaillant');
    expect(note.pinned, isTrue);
    final pending = await container.read(notesStoreProvider).pending();
    expect(pending.map((op) => op.type), ['note.upsert', 'note.upsert', 'note.upsert']);
    expect(pending.last.payload, {'id': id, 'pinned': true});
  });

  test('deleting a folder moves its notes and subfolders to its parent', () async {
    final house = await actions().createFolder('Casa');
    final works = await actions().createFolder('Reformas', parentId: house);
    final kitchen = await actions().createFolder('Cocina', parentId: works);
    final note = await actions().createNote(NoteType.text, folderId: works, title: 'Presupuesto');

    expect((await load()).tree.pathTo(kitchen).map((folder) => folder.name), ['Casa', 'Reformas', 'Cocina']);
    expect(await actions().moveFolder(house, kitchen), isFalse);

    await actions().deleteFolder(works);
    final index = await load();
    expect(index.note(note)!.folderId, house);
    expect(index.folder(kitchen)!.parentId, house);
    expect(index.recursiveCount(house), 1);
  });

  test('converts text into a list and back', () async {
    final id = await actions().createNote(NoteType.text, body: 'Pasaporte\n- Cargador\n\nNeceser');
    await actions().convert((await load()).note(id)!);
    var note = (await load()).note(id)!;
    expect(note.type, NoteType.list);
    expect(note.items.map((item) => item.text), ['Pasaporte', 'Cargador', 'Neceser']);

    await actions().convert(note);
    note = (await load()).note(id)!;
    expect(note.type, NoteType.text);
    expect(note.body, 'Pasaporte\nCargador\nNeceser');
    expect(note.items, isEmpty);
  });

  test('learns products: guessed section, reuse, and an item in the cart comes back unchecked', () async {
    final list = await actions().createNote(NoteType.shopping, title: 'Súper');
    await actions().addProduct(list, 'Leche semidesnatada');
    await actions().addProduct(list, 'Plátanos');
    await actions().addProduct(list, 'leche SEMIDESNATADA');

    var index = await load();
    expect(index.note(list)!.isPrimary, isTrue);
    expect(index.productsOf(list), hasLength(2));
    final milk = index.note(list)!.items.firstWhere((item) => item.text == 'Leche semidesnatada');
    expect(milk.sectionId, 'sec-dairy');
    expect(groupBySection(index.note(list)!, index.sections).map((group) => group.title), [
      'Fruta y verdura',
      'Lácteos y huevos',
    ]);

    await actions().setChecked(milk, true);
    await actions().addProduct(list, 'Leche semidesnatada');
    index = await load();
    expect(index.note(list)!.items.where((item) => item.text == 'Leche semidesnatada').single.checked, isFalse);
  });

  test('finishing a trip empties the cart and brings every-trip products back with the shared id', () async {
    final list = await actions().createNote(NoteType.shopping, title: 'Súper');
    await actions().addProduct(list, 'Pan de molde');
    await actions().addProduct(list, 'Aceite');
    var index = await load();
    final bread = index.productsOf(list).firstWhere((product) => product.name == 'Pan de molde');
    await actions().setRestock(bread, RestockMode.everyTrip);
    for (final item in (await load()).note(list)!.items) {
      await actions().setChecked(item, true);
    }

    final undo = await actions().finishShopping((await load()).note(list)!);
    index = await load();
    final restocked = index.note(list)!.items.single;
    final boughtBread = index.productsOf(list).firstWhere((product) => product.id == bread.id);
    expect(restocked.text, 'Pan de molde');
    expect(restocked.checked, isFalse);
    expect(restocked.id, restockItemId(restockCycleKey(bread.id, boughtBread.lastBoughtAt!)));
    expect(boughtBread.timesBought, 1);

    await undo();
    index = await load();
    expect(index.note(list)!.items.map((item) => (item.text, item.checked)), unorderedEquals([
      ('Pan de molde', true),
      ('Aceite', true),
    ]));
    expect(index.productsOf(list).firstWhere((product) => product.id == bread.id).lastBoughtAt, isNull);
  });

  test('a refreshed snapshot keeps the changes that have not reached the server', () async {
    final id = await actions().createNote(NoteType.text, title: 'Offline');
    await container.read(notesStoreProvider).replaceWith(emptySnapshot(), today: now);
    expect((await load()).note(id)?.title, 'Offline');
  });

  test('sends the queue in one batch and takes the server snapshot', () async {
    final sent = <Object?>[];
    api.routes['POST /v1/notes/sync'] = (options) {
      sent.addAll((options.data as Map)['operations'] as List);
      return (
        200,
        {
          'results': [
            for (final op in sent) {'id': (op as Map)['id'], 'status': 'applied', 'error': null},
          ],
          'data': {
            ...emptySnapshot(),
            'notes': [
              {
                'id': 'server-note',
                'type': 'text',
                'title': 'Desde el servidor',
                'body': null,
                'checked_behavior': 'move',
                'is_primary': false,
                'sort': 0,
                'created_at': '2026-10-26T10:00:00Z',
                'updated_at': '2026-10-26T10:00:00Z',
                'items': <Object?>[],
              },
            ],
          },
        },
      );
    };
    await signIn();
    await actions().createNote(NoteType.text, title: 'Local');
    await container.read(notesSyncProvider.notifier).sync();

    expect(sent, hasLength(1));
    expect(await container.read(notesStoreProvider).pendingCount(), 0);
    expect((await load()).notes.single.title, 'Desde el servidor');
    expect(container.read(notesSyncProvider).online, isTrue);
  });

  test('keeps the queue and reports offline when the server is unreachable', () async {
    await signIn();
    api.routes['POST /v1/notes/sync'] = (options) => throw Exception('no network');
    await actions().createNote(NoteType.text, title: 'Sin red');
    await container.read(notesSyncProvider.notifier).sync();

    expect(container.read(notesSyncProvider).online, isFalse);
    expect(await container.read(notesStoreProvider).pendingCount(), 1);
  });
}
