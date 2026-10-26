import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/search/search_result.dart';
import 'package:carli/shell/search/search_destination.dart';
import 'package:carli/shell/search/search_entries.dart';

SearchResult result({
  String module = 'finance',
  String type = 'account',
  String? id = 'acc-1',
  String title = 'BBVA',
  String url = '/finanzas/cuentas/acc-1',
  String? moduleName = 'Finanzas',
  String? icon = 'landmark',
}) => SearchResult(module: module, moduleName: moduleName, type: type, id: id, title: title, url: url, icon: icon);

void main() {
  group('nativeLocationOf', () {
    final cases = {
      '/': '/',
      '': '/',
      '/finanzas': '/finanzas',
      '/finanzas/movimientos': '/finanzas/movimientos',
      '/finanzas/movimientos?q=merca': '/finanzas/movimientos',
      '/finanzas/movimientos/nuevo': '/finanzas/movimientos',
      '/finanzas/presupuestos': '/finanzas/presupuestos',
      '/finanzas/cuentas': '/mas/cuentas',
      '/finanzas/cuentas/acc-1': '/mas/cuentas/acc-1',
      '/finanzas/categorias': '/mas/categorias',
      '/finanzas/recurrentes': '/mas/recurrentes',
      '/finanzas/objetivos': '/mas/objetivos',
      '/finanzas/objetivos/goal-1': '/mas/objetivos/goal-1',
      '/finanzas/deudas': '/mas/deudas',
      '/finanzas/compartidos': '/mas/compartidos',
      '/finanzas/compartidos/contact-1': '/mas/compartidos/contact-1',
      '/finanzas/ajustes': '/mas/ajustes-finanzas',
      '/finanzas/ajustes/bancos': '/mas/ajustes-finanzas/bancos',
      '/finanzas/ajustes/bancos/conn-1/vincular': '/mas/ajustes-finanzas/bancos/conn-1/vincular',
      '/ajustes': '/mas/ajustes',
      '/ajustes/perfil': '/mas/ajustes/perfil',
      '/ajustes/seguridad': '/mas/ajustes/seguridad',
      '/ajustes/apariencia': '/mas/ajustes/apariencia',
      '/ajustes/notificaciones': '/mas/ajustes/avisos',
      '/ajustes/modulos': '/mas/ajustes/modulos',
      '/ajustes/modulo/finance': '/mas/ajustes-finanzas',
      '/ajustes/modulo/tasks': '/tareas/ajustes',
      '/mas/cuentas/acc-1': '/mas/cuentas/acc-1',
      '/tareas': '/tareas',
      '/tareas/tarea/task-1': '/tareas/tarea/task-1',
      '/tareas/plantillas/tpl-1': '/tareas/plantillas/tpl-1',
    };
    for (final MapEntry(key: url, value: location) in cases.entries) {
      test('maps "$url" to $location', () => expect(nativeLocationOf(url), location));
    }

    for (final url in [
      '/finanzas/desconocido',
      '/finanzas/deudas/debt-1',
      '/ajustes/modulo/health',
      'https://example.com/finanzas',
    ]) {
      test('has no native location for "$url"', () => expect(nativeLocationOf(url), isNull));
    }
  });

  group('searchDestinationOf', () {
    test('opens a finance transaction with the original query', () {
      expect(
        searchDestinationOf(result(type: 'transaction', id: 'tx-1', url: '/finanzas/movimientos?q=merca%20dona')),
        const OpenTransaction('tx-1', query: 'merca dona'),
      );
    });

    test('opens other results at their native location', () {
      expect(searchDestinationOf(result()), const OpenLocation('/mas/cuentas/acc-1'));
      expect(
        searchDestinationOf(result(type: 'contact', id: 'c-1', url: '/finanzas/compartidos/c-1')),
        const OpenLocation('/mas/compartidos/c-1'),
      );
    });

    test('has no destination for an unknown route', () {
      expect(searchDestinationOf(result(module: 'health', type: 'weight', url: '/salud/1')), isNull);
    });
  });

  group('searchEntries', () {
    test('suggests the first sections while the query is empty', () {
      final entries = searchEntries(query: '', results: const []);

      expect(entries, hasLength(idleSectionCount));
      expect(entries.first.title, 'Inicio');
      expect(entries.every((entry) => entry.group == sectionsGroup), isTrue);
    });

    test('filters sections ignoring case and accents', () {
      final entries = searchEntries(query: 'CATEGORIA', results: const []);

      expect(entries.map((entry) => entry.title), ['Categorías']);
      expect(entries.single.destination, const OpenLocation('/mas/categorias'));
    });

    test('hides the sections of disabled modules', () {
      final entries = searchEntries(query: 'ajustes', results: const [], enabledModuleIds: const {});

      expect(entries.map((entry) => entry.subtitle), ['Cuenta']);
    });

    test('lists remote results first, grouped by module name', () {
      final entries = searchEntries(
        query: 'ba',
        results: [
          result(),
          result(type: 'transaction', id: 'tx-1', title: 'Bar Pepe', url: '/finanzas/movimientos?q=ba'),
          result(module: 'notes', moduleName: null, type: 'note', title: 'Baño', url: '/notas/n/1'),
        ],
      );
      final groups = groupSearchEntries(entries);

      expect(groups.map((group) => group.$1), ['Finanzas', resultsGroup]);
      expect(groups.first.$2.map((entry) => entry.title), ['BBVA', 'Bar Pepe']);
      expect(groups.last.$2.single.destination, const OpenLocation('/notas/n/1'));
    });
  });

  test('normalizes accents and case', () {
    expect(normalizeSearchText('  Categorías Ñandú '), 'categorias nandu');
  });
}
