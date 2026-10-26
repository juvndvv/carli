import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/token_store.dart';
import 'models.dart';

const _storageKey = 'finance_recent_categories';
const _limit = 8;

typedef RecentMap = Map<CategoryKind, List<String>>;

final recentCategoriesProvider = NotifierProvider<RecentCategories, RecentMap>(RecentCategories.new);

class RecentCategories extends Notifier<RecentMap> {
  @override
  RecentMap build() {
    Future.microtask(_load);
    return const {CategoryKind.expense: [], CategoryKind.income: []};
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(secureStorageProvider).read(key: _storageKey);
      if (raw == null) return;
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      state = {
        for (final kind in CategoryKind.values)
          kind: [
            for (final id in parsed[kind.api] as List? ?? const [])
              if (id is String) id,
          ],
      };
    } on Object {
      return;
    }
  }

  void remember(CategoryKind kind, String id) {
    state = {
      ...state,
      kind: [id, ...?state[kind]?.where((item) => item != id)].take(_limit).toList(),
    };
    final encoded = jsonEncode({for (final MapEntry(:key, :value) in state.entries) key.api: value});
    ref.read(secureStorageProvider).write(key: _storageKey, value: encoded).ignore();
  }
}
