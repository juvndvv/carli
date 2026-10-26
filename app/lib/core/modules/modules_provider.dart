import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_module.dart';
import 'modules_repository.dart';

final modulesProvider = AsyncNotifierProvider<ModulesController, List<AppModule>>(ModulesController.new);

final enabledModuleIdsProvider = Provider<Set<String>?>((ref) {
  final modules = ref.watch(modulesProvider).value;
  if (modules == null) return null;
  return {
    for (final module in modules)
      if (module.enabled) module.id,
  };
});

bool isModuleEnabled(Set<String>? enabledIds, String moduleId) => enabledIds?.contains(moduleId) ?? true;

class ModulesController extends AsyncNotifier<List<AppModule>> {
  ModulesRepository get _repository => ref.read(modulesRepositoryProvider);

  @override
  Future<List<AppModule>> build() => _repository.list();

  Future<void> setEnabled(String id, bool enabled) async {
    final previous = state.value;
    if (previous != null) {
      state = AsyncData([for (final module in previous) module.id == id ? module.copyWith(enabled: enabled) : module]);
    }
    try {
      final updated = await _repository.setEnabled(id, enabled);
      final current = state.value ?? previous ?? const [];
      state = AsyncData([for (final module in current) module.id == id ? updated : module]);
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}
