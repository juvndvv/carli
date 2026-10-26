import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:carli/modules/notes/data/local_db.dart';
import 'package:carli/modules/notes/data/notes_sync.dart';

NotesDatabase memoryNotesDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return NotesDatabase(NativeDatabase.memory());
}

List<Override> notesOverrides(NotesDatabase db, {DateTime? now}) => [
  notesDatabaseProvider.overrideWithValue(db),
  if (now != null) notesClockProvider.overrideWithValue(() => now),
];

Map<String, Object?> emptySnapshot({List<Map<String, Object?>> sections = const []}) => {
  'server_time': '2026-10-26T10:00:00Z',
  'folders': <Object?>[],
  'notes': <Object?>[],
  'sections': sections,
  'products': <Object?>[],
};

const defaultSections = [
  {'id': 'sec-fruit', 'name': 'Fruta y verdura', 'position': 0, 'updated_at': '2026-10-01T10:00:00Z'},
  {'id': 'sec-dairy', 'name': 'Lácteos y huevos', 'position': 1, 'updated_at': '2026-10-01T10:00:00Z'},
  {'id': 'sec-clean', 'name': 'Limpieza', 'position': 2, 'updated_at': '2026-10-01T10:00:00Z'},
];
