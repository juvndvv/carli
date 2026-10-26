import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/modules/modules_provider.dart';
import '../../core/router/router.dart';
import '../../core/search/search_repository.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../modules/finance/data/models.dart';
import '../../modules/finance/data/transaction_filters.dart';
import '../../modules/finance/screens/transaction_sheet.dart';
import '../../ui/icon.dart';
import '../../ui/icon_names.dart';
import '../../ui/list_item.dart';
import '../../ui/page.dart';
import '../../ui/search.dart';
import '../settings/settings_screen.dart';
import 'search_destination.dart';
import 'search_entries.dart';

const searchDebounce = Duration(milliseconds: 250);

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  var _typed = '';
  var _query = '';
  var _visible = const <SearchEntry>[];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() => _typed = text);
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  void _onSubmitted(String _) {
    for (final entry in _visible) {
      if (entry.destination != null) {
        _open(entry);
        return;
      }
    }
  }

  Future<void> _open(SearchEntry entry) async {
    switch (entry.destination) {
      case OpenLocation(:final location):
        context.go(location);
      case OpenTransaction(:final transactionId, :final query):
        await _openTransaction(transactionId, query);
      case null:
        return;
    }
  }

  Future<void> _openTransaction(String id, String query) async {
    try {
      final response = await ref.read(dioProvider).get<Map<String, dynamic>>('/v1/finance/transactions/$id');
      final transaction = Transaction.fromJson(response.data!['data'] as Map<String, dynamic>);
      if (mounted) await showTransactionSheet(context, transaction: transaction);
    } catch (_) {
      if (!mounted) return;
      ref
          .read(transactionFiltersProvider.notifier)
          .replace(TransactionFilters(periodScope: PeriodScope.all, query: query));
      context.go(Routes.transactions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final term = _typed.trim();
    final remote = _query.length >= minSearchQueryLength ? ref.watch(searchResultsProvider(_query)) : null;
    final entries = _visible = searchEntries(
      query: _typed,
      results: remote?.value ?? const [],
      enabledModuleIds: ref.watch(enabledModuleIdsProvider),
    );
    final searching = term.length >= minSearchQueryLength && (term != _query || (remote?.isLoading ?? false));
    final emptyMessage = searching
        ? 'Buscando…'
        : term.length >= minSearchQueryLength
        ? 'Sin resultados para «$term».'
        : 'Escribe al menos $minSearchQueryLength letras.';

    return CarliPage(
      title: 'Buscar',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s8, CarliSpace.s16, 0),
          sliver: SliverToBoxAdapter(
            child: Semantics(
              label: 'Búsqueda global',
              child: CarliSearchField(
                controller: _controller,
                placeholder: 'Busca movimientos, cuentas, secciones…',
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: _onSubmitted,
              ),
            ),
          ),
        ),
        if (entries.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(CarliSpace.s24),
            sliver: SliverToBoxAdapter(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: CarliType.small.copyWith(color: colors.text3),
                ),
              ),
            ),
          )
        else
          SliverList.list(
            children: [
              for (final (group, items) in groupSearchEntries(entries))
                SettingsGroup(
                  title: group,
                  children: [
                    for (final entry in items)
                      CarliListItem(
                        title: entry.title,
                        subtitle: entry.subtitle,
                        icon: carliIconNamed(entry.icon, fallback: carliIconNamed('search')),
                        trailing: entry.destination == null
                            ? null
                            : CarliIcon(carliIconNamed('arrow-right'), size: 16, color: colors.text3),
                        onTap: entry.destination == null ? null : () => _open(entry),
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
