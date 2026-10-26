import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import 'local_db.dart';
import 'notes_api.dart';
import 'notes_store.dart';

final notesDatabaseProvider = Provider<NotesDatabase>((ref) {
  final db = NotesDatabase();
  ref.onDispose(db.close);
  return db;
});

final notesStoreProvider = Provider<NotesStore>((ref) => NotesStore(ref.watch(notesDatabaseProvider)));

final notesClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final notesIndexProvider = StreamProvider<NotesIndex>((ref) {
  ref.read(notesSyncProvider.notifier).requestSync();
  return ref.watch(notesStoreProvider).watch();
});

@immutable
class NotesSyncState {
  const NotesSyncState({this.online = true, this.syncing = false, this.lastSyncedAt});

  final bool online;
  final bool syncing;
  final DateTime? lastSyncedAt;

  NotesSyncState copyWith({bool? online, bool? syncing, DateTime? lastSyncedAt}) => NotesSyncState(
    online: online ?? this.online,
    syncing: syncing ?? this.syncing,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
}

final notesSyncProvider = NotifierProvider<NotesSync, NotesSyncState>(NotesSync.new);

/// Sends the queued changes and refreshes the cache from the server. Without a connection the queue simply waits:
/// it is retried on a timer, when the app comes back to the foreground and after every new change.
class NotesSync extends Notifier<NotesSyncState> {
  static const debounce = Duration(milliseconds: 400);
  static const offlineRetry = Duration(seconds: 20);
  static const errorRetry = Duration(seconds: 60);

  Timer? _debounce;
  Timer? _retry;
  Future<void>? _running;
  var _again = false;
  AppLifecycleListener? _lifecycle;

  NotesStore get _store => ref.read(notesStoreProvider);

  @override
  NotesSyncState build() {
    _lifecycle = AppLifecycleListener(onResume: requestSync);
    ref.listen(authControllerProvider, (previous, next) {
      if (next is SignedOut && previous is SignedIn) ref.read(notesDatabaseProvider).wipe().ignore();
    });
    ref.onDispose(() {
      _debounce?.cancel();
      _retry?.cancel();
      _lifecycle?.dispose();
    });
    return const NotesSyncState();
  }

  void requestSync() {
    _debounce?.cancel();
    _debounce = Timer(debounce, () => sync().ignore());
  }

  Future<void> sync() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    _retry?.cancel();
    if (ref.read(authControllerProvider) is! SignedIn) return;
    state = state.copyWith(syncing: true);
    try {
      do {
        _again = false;
        await _exchange();
      } while (_again || await _store.pendingCount() > 0);
      state = NotesSyncState(lastSyncedAt: ref.read(notesClockProvider)());
    } on DioException catch (error) {
      final offline = error.response == null;
      state = state.copyWith(online: !offline, syncing: false);
      if (error.response?.statusCode == 401 || error.response?.statusCode == 403) return;
      _retry = Timer(offline ? offlineRetry : errorRetry, () => sync().ignore());
    }
  }

  Future<void> _exchange() async {
    final api = ref.read(notesApiProvider);
    final operations = await _store.pending();
    final today = ref.read(notesClockProvider)();
    if (operations.isEmpty) {
      await _store.replaceWith(await api.snapshot(), today: today);
      return;
    }
    final result = await api.sync(operations);
    await _store.replaceWith(result.snapshot, today: today, acknowledged: [for (final op in operations) op.id]);
  }
}
