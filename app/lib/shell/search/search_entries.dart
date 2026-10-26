import 'package:flutter/foundation.dart';

import '../../core/modules/app_module.dart';
import '../../core/modules/modules_provider.dart';
import '../../core/router/router.dart';
import '../../core/search/search_result.dart';
import '../settings/settings_screen.dart';
import 'search_destination.dart';

const sectionsGroup = 'Secciones';
const resultsGroup = 'Resultados';
const idleSectionCount = 6;

@immutable
class SearchEntry {
  const SearchEntry({
    required this.title,
    required this.icon,
    required this.group,
    required this.destination,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String icon;
  final String group;
  final SearchDestination? destination;
}

class SearchSection {
  const SearchSection(this.title, this.icon, this.location, {this.subtitle, this.moduleId});

  final String title;
  final String? subtitle;
  final String icon;
  final String location;
  final String? moduleId;
}

const searchSections = [
  SearchSection('Inicio', 'house', Routes.home),
  SearchSection('Resumen', 'layout-dashboard', Routes.summary, subtitle: 'Finanzas', moduleId: AppModuleIds.finance),
  SearchSection('Movimientos', 'list', Routes.transactions, subtitle: 'Finanzas', moduleId: AppModuleIds.finance),
  SearchSection('Cuentas', 'landmark', Routes.accounts, subtitle: 'Finanzas', moduleId: AppModuleIds.finance),
  SearchSection('Presupuestos', 'gauge', Routes.budgets, subtitle: 'Finanzas', moduleId: AppModuleIds.finance),
  SearchSection('Categorías', 'tag', Routes.categories, subtitle: 'Finanzas', moduleId: AppModuleIds.finance),
  SearchSection('Recurrentes', 'repeat', Routes.recurring, subtitle: 'Finanzas', moduleId: AppModuleIds.finance),
  SearchSection('Objetivos', 'target', Routes.goals, subtitle: 'Finanzas', moduleId: AppModuleIds.finance),
  SearchSection('Deudas', 'hand-coins', Routes.debts, subtitle: 'Finanzas', moduleId: AppModuleIds.finance),
  SearchSection('Compartidos', 'users', Routes.shared, subtitle: 'Finanzas', moduleId: AppModuleIds.finance),
  SearchSection('Ajustes', 'settings', Routes.financeSettings, subtitle: 'Finanzas', moduleId: AppModuleIds.finance),
  SearchSection('Ajustes', 'settings', SettingsPaths.root, subtitle: 'Cuenta'),
];

const _diacritics = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

String normalizeSearchText(String text) =>
    text.toLowerCase().split('').map((character) => _diacritics[character] ?? character).join().trim();

List<SearchEntry> searchEntries({
  required String query,
  required List<SearchResult> results,
  Set<String>? enabledModuleIds,
}) {
  final term = normalizeSearchText(query);
  final available = [
    for (final section in searchSections)
      if (section.moduleId == null || isModuleEnabled(enabledModuleIds, section.moduleId!)) section,
  ];
  final sections = term.isEmpty
      ? available.take(idleSectionCount)
      : available.where((section) => normalizeSearchText('${section.title} ${section.subtitle ?? ''}').contains(term));
  return [
    for (final result in results)
      SearchEntry(
        title: result.title,
        subtitle: result.subtitle,
        icon: result.icon ?? 'search',
        group: result.moduleName ?? resultsGroup,
        destination: searchDestinationOf(result),
      ),
    for (final section in sections)
      SearchEntry(
        title: section.title,
        subtitle: section.subtitle,
        icon: section.icon,
        group: sectionsGroup,
        destination: OpenLocation(section.location),
      ),
  ];
}

List<(String, List<SearchEntry>)> groupSearchEntries(List<SearchEntry> entries) {
  final groups = <(String, List<SearchEntry>)>[];
  for (final entry in entries) {
    if (groups.isEmpty || groups.last.$1 != entry.group) {
      groups.add((entry.group, [entry]));
    } else {
      groups.last.$2.add(entry);
    }
  }
  return groups;
}
