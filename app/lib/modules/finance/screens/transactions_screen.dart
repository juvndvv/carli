import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/card.dart';
import '../../../ui/chip.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/page.dart';
import '../../../ui/pressable.dart';
import '../../../ui/search.dart';
import '../../../ui/sheet.dart';
import '../../../ui/skeleton.dart';
import '../../../ui/toast.dart';
import '../data/finance_changes.dart';
import '../data/finance_format.dart';
import '../data/finance_providers.dart';
import '../data/models.dart';
import '../data/transaction_filters.dart';
import '../data/transactions_list.dart';
import '../data/transactions_repository.dart';
import '../ui/transaction_row.dart';
import 'transaction_sheet.dart';
import 'transaction_tools.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.query = const {}});

  final Map<String, List<String>> query;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();
  final _dismissed = <String>{};
  final _exportKey = GlobalKey();
  var _selecting = false;
  var _selected = <String>{};
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(transactionFiltersProvider).query;
    _applyQuery();
  }

  @override
  void didUpdateWidget(TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.query, widget.query)) _applyQuery();
  }

  void _applyQuery() {
    final query = widget.query;
    if (query.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      final location = router?.routeInformationProvider.value.uri.path;
      if (router != null && location != null) router.go(location);
      if (query.containsKey(TransactionQuery.quickAdd)) {
        showTransactionSheet(context, preset: quickAddPreset(query));
        return;
      }
      final filters = TransactionFilters.fromQuery(query);
      _filters.replace(filters);
      _search.text = filters.query;
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  TransactionFiltersController get _filters => ref.read(transactionFiltersProvider.notifier);

  void _onSearch(String text) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _filters.update((current) => current.copyWith(query: text.trim()));
    });
  }

  Future<void> _refresh(TransactionFilters filters) async {
    ref.read(financeChangesProvider.notifier).notifyTransactions();
    await ref.read(transactionListProvider(filters).future).then((_) {}, onError: (_) {});
  }

  Future<void> _loadMore(TransactionFilters filters) async {
    try {
      await ref.read(transactionListProvider(filters).notifier).loadMore();
    } catch (error) {
      ref
          .read(toastControllerProvider.notifier)
          .error(apiErrorMessage(error, fallback: 'No se han podido cargar más movimientos.'));
    }
  }

  void _reveal(String id) {
    if (mounted) setState(() => _dismissed.remove(id));
  }

  Future<void> _delete(Transaction transaction) async {
    setState(() => _dismissed.add(transaction.id));
    final repository = ref.read(transactionsRepositoryProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      final periodsChanged = await repository.remove(transaction.id);
      final base = transaction.kind == TransactionKind.transfer ? 'Transferencia eliminada' : 'Movimiento eliminado';
      toasts.withUndo(withPeriodsNotice(base, periodsChanged), () async {
        await repository.restore(transaction.id);
        _reveal(transaction.id);
      });
    } catch (error) {
      _reveal(transaction.id);
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido eliminar el movimiento.'));
    }
  }

  Future<void> _pickPeriod(TransactionFilters filters) async {
    final periods = ref.read(periodsProvider).value;
    if (periods == null) return;
    final selectedId = switch (filters.periodScope) {
      PeriodScope.all => null,
      PeriodScope.current => periods.current?.id,
      PeriodScope.specific => filters.periodId,
    };
    final picked = await showCarliSheet<(Period?,)>(
      context,
      title: 'Periodo',
      scrollable: true,
      builder: (context) => _ChoiceList(
        options: [
          for (final period in periods.all)
            _Choice((period,), period.name, subtitle: period.rangeLabel, selected: period.id == selectedId),
          _Choice((null,), 'Todos los periodos', selected: filters.periodScope == PeriodScope.all),
        ],
      ),
    );
    if (picked != null) _filters.update((current) => current.withPeriod(picked.$1));
  }

  Future<Set<T>?> _pickMany<T>(String title, List<_Choice<T>> options, Set<T> selected, {String? emptyText}) =>
      showCarliSheet<Set<T>>(
        context,
        title: title,
        scrollable: true,
        builder: (context) => _MultiChoice<T>(options: options, initial: selected, emptyText: emptyText),
      );

  Future<void> _pickAccounts(TransactionFilters filters) async {
    final accounts = ref.read(accountsProvider).value;
    if (accounts == null) return;
    final result = await _pickMany('Cuentas', [
      for (final account in accounts.all)
        _Choice(
          account.id,
          account.name,
          icon: account.icon ?? account.type.icon,
          subtitle: account.archived ? 'Archivada' : null,
        ),
    ], filters.accountIds);
    if (result != null) _filters.update((current) => current.copyWith(accountIds: result));
  }

  Future<void> _pickCategories(TransactionFilters filters) async {
    final categories = ref.read(categoriesProvider).value;
    if (categories == null) return;
    final result = await _pickMany('Categorías', [
      const _Choice(uncategorizedFilter, 'Sin categoría', icon: 'circle-dashed'),
      for (final entry in categories.entries)
        _Choice(
          entry.category.id,
          entry.category.name,
          icon: entry.icon,
          indent: entry.parent != null,
          subtitle: entry.parent == null && entry.category.kind == CategoryKind.income ? 'Ingreso' : null,
        ),
    ], filters.categoryIds);
    if (result != null) _filters.update((current) => current.copyWith(categoryIds: result));
  }

  Future<void> _pickKinds(TransactionFilters filters) async {
    final result = await _pickMany('Tipo de movimiento', [
      for (final kind in TransactionKind.values) _Choice(kind, kind.plural),
    ], filters.kinds);
    if (result != null) _filters.update((current) => current.copyWith(kinds: result));
  }

  Future<void> _pickTags(TransactionFilters filters) async {
    final tags = await ref.read(tagsProvider.future).then((value) => value, onError: (_) => const <Tag>[]);
    if (!mounted) return;
    final result = await _pickMany(
      'Etiquetas',
      [for (final tag in tags) _Choice(tag.name, '#${tag.name}', subtitle: movementsCount(tag.transactionsCount))],
      filters.tags,
      emptyText: 'Aún no has usado etiquetas.',
    );
    if (result != null) _filters.update((current) => current.copyWith(tags: result));
  }

  Future<void> _pickMore(TransactionFilters filters) async {
    final result = await showMoreFiltersSheet(context, filters);
    if (result == null) return;
    _filters.update(
      (current) => current.copyWith(
        status: () => result.status,
        min: () => result.min,
        max: () => result.max,
        from: () => result.from,
        to: () => result.to,
        periodScope: result.from != null || result.to != null ? PeriodScope.all : null,
      ),
    );
  }

  void _toggleSelecting() => setState(() {
    _selecting = !_selecting;
    _selected = {};
  });

  void _toggleSelected(Transaction transaction) => setState(() {
    if (!_selected.remove(transaction.id)) _selected.add(transaction.id);
  });

  Future<void> _bulkEdit() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final changes = await showBulkEditSheet(context, ids.length);
    if (changes == null) return;
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      final updated = await ref.read(transactionsRepositoryProvider).bulkUpdate({'ids': ids, ...changes});
      toasts.show(updated == 1 ? '1 movimiento actualizado' : '$updated movimientos actualizados');
      if (mounted) {
        setState(() {
          _selecting = false;
          _selected = {};
        });
      }
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se han podido actualizar los movimientos.'));
    }
  }

  Future<void> _export(TransactionFilters filters) async {
    final periods = ref.read(periodsProvider).value;
    final box = _exportKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await exportTransactionsCsv(ref, filters.toApiQuery(periods?.current?.id), origin: origin);
  }

  void _clear() {
    _search.clear();
    _filters.update((current) => current.cleared());
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(transactionFiltersProvider);
    final list = ref.watch(transactionListProvider(filters));
    final accounts = ref.watch(accountsProvider).value;
    final categories = ref.watch(categoriesProvider).value;
    final periods = ref.watch(periodsProvider).value;

    ref.listen(transactionFiltersProvider.select((value) => value.query), (_, query) {
      if (_search.text.trim() != query) _search.text = query;
    });

    final periodLabel = filters.hasDateRange
        ? '${filters.from == null ? '…' : formatShortDate(filters.from!, withYear: true)} – '
              '${filters.to == null ? 'hoy' : formatShortDate(filters.to!, withYear: true)}'
        : switch (filters.periodScope) {
            PeriodScope.all => 'Todos los periodos',
            PeriodScope.current => periods?.current == null ? 'Periodo actual' : periodButtonLabel(periods!.current!),
            PeriodScope.specific =>
              periods?.find(filters.periodId) == null ? 'Periodo' : periodButtonLabel(periods!.find(filters.periodId)!),
          };
    final tagLabel = switch (filters.tags.length) {
      0 => 'Etiqueta',
      1 => '#${filters.tags.single}',
      final count => '$count etiquetas',
    };
    final accountLabel = switch (filters.accountIds.length) {
      0 => 'Todas las cuentas',
      1 => accounts?.find(filters.accountIds.single)?.name ?? '1 cuenta',
      final count => '$count cuentas',
    };
    final categoryLabel = switch (filters.categoryIds.length) {
      0 => 'Categoría',
      1 =>
        filters.categoryIds.single == uncategorizedFilter
            ? 'Sin categoría'
            : categories?.find(filters.categoryIds.single)?.category.name ?? '1 categoría',
      final count => '$count categorías',
    };
    final kindLabel = filters.kinds.isEmpty
        ? 'Gastos e ingresos'
        : [
            for (final kind in TransactionKind.values)
              if (filters.kinds.contains(kind)) kind.plural,
          ].join(' y ');
    final pendingCount = list.value?.pendingCount;

    return CarliPage(
      title: 'Movimientos',
      onRefresh: () => _refresh(filters),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Exportar CSV',
            child: Pressable(
              key: _exportKey,
              onTap: () => _export(filters),
              child: Padding(
                padding: const EdgeInsets.all(CarliSpace.s8),
                child: CarliIcon(carliIconNamed('download'), size: 20, color: context.colors.brandInk),
              ),
            ),
          ),
          TextButton(onPressed: _toggleSelecting, child: Text(_selecting ? 'Terminar' : 'Seleccionar')),
        ],
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s12),
            child: CarliSearchField(
              controller: _search,
              placeholder: 'Buscar por comercio, concepto o nota',
              onChanged: _onSearch,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
            child: Row(
              spacing: CarliSpace.s8,
              children: [
                CarliChip(
                  icon: carliIconNamed('calendar'),
                  label: periodLabel,
                  selected: true,
                  onTap: () => _pickPeriod(filters),
                ),
                CarliChip(
                  icon: carliIconNamed('wallet'),
                  label: accountLabel,
                  selected: filters.accountIds.isNotEmpty,
                  onTap: () => _pickAccounts(filters),
                ),
                CarliChip(
                  icon: carliIconNamed('tag'),
                  label: categoryLabel,
                  selected: filters.categoryIds.isNotEmpty,
                  onTap: () => _pickCategories(filters),
                ),
                CarliChip(
                  icon: carliIconNamed('hash'),
                  label: tagLabel,
                  selected: filters.tags.isNotEmpty,
                  onTap: () => _pickTags(filters),
                ),
                CarliChip(label: kindLabel, selected: filters.kinds.isNotEmpty, onTap: () => _pickKinds(filters)),
                CarliChip(
                  icon: carliIconNamed('clock'),
                  label: 'Pendientes${pendingCount == null ? '' : ' ($pendingCount)'}',
                  selected: filters.status == TransactionStatus.pending,
                  onTap: () => _filters.update(
                    (current) => current.copyWith(
                      status: () => current.status == TransactionStatus.pending ? null : TransactionStatus.pending,
                    ),
                  ),
                ),
                CarliChip(
                  icon: carliIconNamed('circle-dashed'),
                  label: 'Sin categoría',
                  selected: filters.uncategorized,
                  onTap: () => _filters.update((current) => current.copyWith(uncategorized: !current.uncategorized)),
                ),
                CarliChip(
                  icon: carliIconNamed('sliders-horizontal'),
                  label: 'Más filtros',
                  selected: filters.moreFiltersActive,
                  onTap: () => _pickMore(filters),
                ),
                if (filters.activeCount > 0 || filters.query.isNotEmpty)
                  CarliChip(icon: carliIconNamed('x'), label: 'Limpiar', onTap: _clear),
              ],
            ),
          ),
        ),
        if (_selecting)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s12, CarliSpace.s16, 0),
            sliver: SliverToBoxAdapter(
              child: _SelectionBar(
                count: _selected.length,
                onAll: () => setState(() {
                  final all = {for (final item in list.value?.items ?? const <Transaction>[]) item.id};
                  _selected = _selected.length == all.length ? {} : all;
                }),
                onEdit: _selected.isEmpty ? null : _bulkEdit,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s12, CarliSpace.s16, CarliSpace.s12),
          sliver: SliverToBoxAdapter(child: _Totals(totals: list.value?.totals)),
        ),
        ..._body(list, filters, accounts),
      ],
    );
  }

  List<Widget> _body(AsyncValue<TransactionListState> list, TransactionFilters filters, AccountsData? accounts) {
    final colors = context.colors;
    if (list case AsyncValue(hasValue: false, hasError: true, :final error)) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: CarliCard(
              child: CarliEmptyState(
                icon: carliIconNamed('circle-alert'),
                title: 'No se han podido cargar los movimientos',
                message: apiErrorMessage(error!, fallback: 'Comprueba tu conexión e inténtalo de nuevo.'),
                actionLabel: 'Reintentar',
                onAction: () => ref.invalidate(transactionListProvider(filters)),
              ),
            ),
          ),
        ),
      ];
    }
    final state = list.value;
    if (state == null) return [const SliverToBoxAdapter(child: _ListSkeleton())];

    final groups = groupByDay([
      for (final item in state.items)
        if (!_dismissed.contains(item.id)) item,
    ], hideIncomingTransfers: filters.accountIds.isEmpty);
    if (groups.isEmpty) {
      final (icon, title, message, action, onAction) = filters.onlyUncategorized
          ? (
              'circle-check',
              'Todo categorizado',
              'No quedan movimientos sin categoría en lo que estás viendo.',
              'Ver todos los movimientos',
              () => _filters.update((current) => current.copyWith(uncategorized: false)),
            )
          : filters.activeCount > 0 || filters.query.isNotEmpty
          ? (
              'search',
              'Nada coincide con los filtros',
              'Prueba con otro periodo o quita algún filtro.',
              'Quitar filtros',
              _clear,
            )
          : (
              'inbox',
              'Aún no hay movimientos',
              'Apunta tu primer gasto y empezarás a ver tu resumen.',
              'Añadir movimiento',
              () => showTransactionSheet(context),
            );
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: CarliCard(
              child: CarliEmptyState(
                icon: carliIconNamed(icon),
                title: title,
                message: message,
                actionLabel: action,
                onAction: onAction,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      for (final (index, group) in groups.indexed) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              CarliSpace.s20,
              index == 0 ? 0 : CarliSpace.s16,
              CarliSpace.s20,
              CarliSpace.s8,
            ),
            child: Semantics(
              header: true,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatRelativeDay(group.date, style: RelativeDateStyle.title),
                      style: CarliType.small.copyWith(fontWeight: FontWeight.w600, color: colors.text2),
                    ),
                  ),
                  Text(
                    formatMoney(group.total, display: MoneyDisplay.signed),
                    style: CarliType.money(CarliType.small).copyWith(color: colors.text3),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: _GroupCard(
              items: group.items,
              accounts: accounts,
              selecting: _selecting,
              selected: _selected,
              onTap: (transaction) =>
                  _selecting ? _toggleSelected(transaction) : showTransactionSheet(context, transaction: transaction),
              onDelete: _delete,
            ),
          ),
        ),
      ],
      if (state.hasMore)
        SliverToBoxAdapter(
          child: _LoadMore(loading: state.loadingMore, onVisible: () => _loadMore(filters)),
        ),
    ];
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals});

  final TransactionTotals? totals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final totals = this.totals;
    return CarliCard(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
      child: totals == null
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [CarliSkeleton(width: 100, height: 14), CarliSkeleton(width: 160, height: 14)],
            )
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: CarliSpace.s12,
              runSpacing: CarliSpace.s4,
              children: [
                Text(movementsCount(totals.count), style: CarliType.small.copyWith(color: colors.text2)),
                Wrap(
                  spacing: CarliSpace.s12,
                  children: [
                    _Sum(label: 'Ingresos', cents: totals.incomeCents, color: colors.positive),
                    _Sum(label: 'Gastos', cents: totals.expenseCents, color: colors.text),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Sum extends StatelessWidget {
  const _Sum({required this.label, required this.cents, required this.color});

  final String label;
  final int cents;
  final Color color;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: CarliType.small.copyWith(color: context.colors.text2),
      children: [
        TextSpan(text: '$label '),
        TextSpan(
          text: formatMoney(cents, display: MoneyDisplay.signed),
          style: CarliType.money(CarliType.small).copyWith(fontWeight: FontWeight.w600, color: color),
        ),
      ],
    ),
  );
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.items,
    required this.accounts,
    required this.onTap,
    required this.onDelete,
    this.selecting = false,
    this.selected = const {},
  });

  final bool selecting;
  final Set<String> selected;

  final List<Transaction> items;
  final AccountsData? accounts;
  final ValueChanged<Transaction> onTap;
  final ValueChanged<Transaction> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(CarliRadius.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CarliRadius.lg),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            for (final (index, transaction) in items.indexed) ...[
              if (index > 0) Divider(indent: 68, color: colors.border),
              if (selecting)
                TransactionRow(
                  transaction: transaction,
                  accounts: accounts,
                  selectable: true,
                  selected: selected.contains(transaction.id),
                  onTap: () => onTap(transaction),
                )
              else
                Dismissible(
                  key: ValueKey(transaction.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: CarliColors.dangerFill,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: CarliSpace.s20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: CarliSpace.s8,
                      children: [
                        CarliIcon(carliIconNamed('trash'), size: 18, color: colors.onPrimary),
                        Text(
                          'Eliminar',
                          style: CarliType.small.copyWith(fontWeight: FontWeight.w600, color: colors.onPrimary),
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (_) => onDelete(transaction),
                  child: TransactionRow(transaction: transaction, accounts: accounts, onTap: () => onTap(transaction)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadMore extends StatefulWidget {
  const _LoadMore({required this.loading, required this.onVisible});

  final bool loading;
  final VoidCallback onVisible;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CarliSpace.s16),
      child: Center(
        child: widget.loading
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(onPressed: widget.onVisible, child: const Text('Cargar más')),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
      child: CarliCard(
        padding: const EdgeInsets.symmetric(vertical: CarliSpace.s8),
        child: Column(
          children: [
            for (var i = 0; i < 6; i++)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
                child: Row(
                  spacing: CarliSpace.s12,
                  children: [
                    CarliSkeleton.circle(size: 40),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: CarliSpace.s8,
                        children: [CarliSkeleton(width: 150, height: 14), CarliSkeleton(width: 100, height: 12)],
                      ),
                    ),
                    CarliSkeleton(width: 70, height: 14),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Choice<T> {
  const _Choice(this.value, this.label, {this.subtitle, this.icon, this.indent = false, this.selected = false});

  final T value;
  final String label;
  final String? subtitle;
  final String? icon;
  final bool indent;
  final bool selected;
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.choice, required this.selected, required this.onTap, this.multi = false});

  final _Choice<Object?> choice;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      checked: multi ? selected : null,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(choice.indent ? 44 : CarliSpace.s20, 12, CarliSpace.s20, 12),
          child: Row(
            spacing: CarliSpace.s12,
            children: [
              if (choice.icon case final icon?) CarliIcon(carliIconNamed(icon), size: 20, color: colors.text2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(choice.label, style: CarliType.body.copyWith(color: colors.text)),
                    if (choice.subtitle case final subtitle?)
                      Text(subtitle, style: CarliType.small.copyWith(color: colors.text3)),
                  ],
                ),
              ),
              if (multi)
                CarliIcon(
                  carliIconNamed(selected ? 'circle-check' : 'circle'),
                  size: 22,
                  color: selected ? colors.brandInk : colors.text3,
                )
              else if (selected)
                CarliIcon(carliIconNamed('check'), size: 20, color: colors.brandInk, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceList<T> extends StatelessWidget {
  const _ChoiceList({required this.options});

  final List<_Choice<T>> options;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: CarliSpace.s16),
      children: [
        for (final option in options)
          _ChoiceRow(choice: option, selected: option.selected, onTap: () => Navigator.pop(context, option.value)),
      ],
    );
  }
}

class _MultiChoice<T> extends StatefulWidget {
  const _MultiChoice({required this.options, required this.initial, this.emptyText});

  final String? emptyText;

  final List<_Choice<T>> options;
  final Set<T> initial;

  @override
  State<_MultiChoice<T>> createState() => _MultiChoiceState<T>();
}

class _MultiChoiceState<T> extends State<_MultiChoice<T>> {
  late final Set<T> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.options.isEmpty && widget.emptyText != null)
          Padding(
            padding: const EdgeInsets.all(CarliSpace.s20),
            child: Text(widget.emptyText!, style: CarliType.small.copyWith(color: colors.text2)),
          ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final option in widget.options)
                _ChoiceRow(
                  choice: option,
                  multi: true,
                  selected: _selected.contains(option.value),
                  onTap: () => setState(
                    () =>
                        _selected.contains(option.value) ? _selected.remove(option.value) : _selected.add(option.value),
                  ),
                ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s8, CarliSpace.s16, CarliSpace.s16),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  style: TextButton.styleFrom(foregroundColor: colors.text2),
                  child: const Text('Quitar todo'),
                ),
                const Spacer(),
                Pressable(
                  onTap: () => Navigator.pop(context, _selected),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s20, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(CarliRadius.control),
                    ),
                    child: Text(
                      'Aplicar',
                      style: CarliType.body.copyWith(fontWeight: FontWeight.w600, color: colors.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.onAll, required this.onEdit});

  final int count;
  final VoidCallback onAll;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: 'Selección',
      child: Container(
        padding: const EdgeInsets.only(left: CarliSpace.s16, right: CarliSpace.s8),
        height: 52,
        decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(CarliRadius.md)),
        child: Row(
          spacing: CarliSpace.s8,
          children: [
            Expanded(
              child: Text(
                count == 1 ? '1 seleccionado' : '$count seleccionados',
                style: CarliType.small.copyWith(fontWeight: FontWeight.w600, color: colors.text),
              ),
            ),
            TextButton(onPressed: onAll, child: const Text('Todos')),
            CarliButton(
              label: 'Editar',
              icon: carliIconNamed('pencil'),
              size: CarliButtonSize.sm,
              block: false,
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}
