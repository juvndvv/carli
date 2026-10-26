import 'package:flutter/foundation.dart';

import '../../core/modules/app_module.dart';
import '../../core/router/router.dart';
import '../../core/search/search_result.dart';
import '../settings/settings_screen.dart';

@immutable
sealed class SearchDestination {
  const SearchDestination();
}

final class OpenLocation extends SearchDestination {
  const OpenLocation(this.location);

  final String location;

  @override
  bool operator ==(Object other) => other is OpenLocation && other.location == location;

  @override
  int get hashCode => location.hashCode;

  @override
  String toString() => 'OpenLocation($location)';
}

final class OpenTransaction extends SearchDestination {
  const OpenTransaction(this.transactionId, {this.query = ''});

  final String transactionId;
  final String query;

  @override
  bool operator ==(Object other) =>
      other is OpenTransaction && other.transactionId == transactionId && other.query == query;

  @override
  int get hashCode => Object.hash(transactionId, query);

  @override
  String toString() => 'OpenTransaction($transactionId, $query)';
}

SearchDestination? searchDestinationOf(SearchResult result) {
  final uri = Uri.tryParse(result.url);
  if (result.module == AppModuleIds.finance && result.type == 'transaction' && (result.id ?? '').isNotEmpty) {
    return OpenTransaction(result.id!, query: uri?.queryParameters['q'] ?? '');
  }
  final location = nativeLocationOf(result.url);
  return location == null ? null : OpenLocation(location);
}

const _financeListsUnderMore = {
  'cuentas': Routes.accounts,
  'categorias': Routes.categories,
  'recurrentes': Routes.recurring,
  'objetivos': Routes.goals,
  'deudas': Routes.debts,
  'compartidos': Routes.shared,
};

const _financeDetailsUnderMore = {'cuentas', 'objetivos', 'compartidos'};

const _settingsSections = {
  'perfil': SettingsPaths.profile,
  'seguridad': SettingsPaths.security,
  'apariencia': SettingsPaths.appearance,
  'notificaciones': SettingsPaths.notifications,
  'avisos': SettingsPaths.notifications,
  'modulos': SettingsPaths.modules,
};

String? nativeLocationOf(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.hasScheme) return null;
  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  return switch (segments) {
    [] => Routes.home,
    ['finanzas'] => Routes.summary,
    ['finanzas', 'movimientos', ...] => Routes.transactions,
    ['finanzas', 'presupuestos'] => Routes.budgets,
    ['finanzas', 'ajustes'] => Routes.financeSettings,
    ['finanzas', 'ajustes', 'bancos'] => Routes.banks,
    ['finanzas', 'ajustes', 'bancos', final id, 'vincular'] => Routes.bankLink(id),
    ['finanzas', final section] => _financeListsUnderMore[section],
    ['finanzas', final section, final id] when _financeDetailsUnderMore.contains(section) =>
      '${_financeListsUnderMore[section]}/$id',
    ['ajustes'] => SettingsPaths.root,
    ['ajustes', 'modulo', final moduleId] => moduleSettingsLocationOf(moduleId),
    ['ajustes', final section] => _settingsSections[section],
    ['mas', ...] || ['tareas', ...] || ['notas', ...] || ['compra', ...] => '/${segments.join('/')}',
    _ => null,
  };
}
