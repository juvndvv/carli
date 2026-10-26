import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/format/money.dart';
import '../../../core/router/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/avatar.dart';
import '../../../ui/card.dart';
import '../../../ui/chart.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/list_item.dart';
import '../../../ui/page.dart';
import '../../../ui/pressable.dart';
import '../../../ui/skeleton.dart';
import '../../../ui/metric_card.dart';
import '../../../ui/stat.dart';
import '../data/activity_rings.dart';
import '../data/finance_changes.dart';
import '../data/finance_format.dart';
import '../data/finance_providers.dart';
import '../data/models.dart';
import '../data/transaction_filters.dart';
import '../ui/activity_rings_card.dart';
import '../ui/budget_line.dart';
import '../ui/period_selector.dart';
import '../ui/transaction_row.dart';
import '../ui/uncategorized_notice.dart';
import 'transaction_sheet.dart';

const _maxSlices = 8;

class DonutSlice {
  const DonutSlice(this.label, this.amount, this.slot);

  final String label;
  final Cents amount;
  final int? slot;

  Color color(CarliColors colors) => slot == null ? colors.text3 : colors.chart[slot! - 1];
}

int? chartSlot(String? color) {
  final match = RegExp(r'^c([1-8])$').firstMatch(color ?? '');
  return match == null ? null : int.parse(match[1]!);
}

List<DonutSlice> buildDonut(List<DashboardCategoryGroup> groups) {
  final sorted = [...groups]..sort((left, right) => right.amountCents.compareTo(left.amountCents));
  final head = sorted.length > _maxSlices ? sorted.sublist(0, _maxSlices - 1) : sorted;
  final tail = sorted.length > _maxSlices ? sorted.sublist(_maxSlices - 1) : const <DashboardCategoryGroup>[];
  final used = <int>{};
  final wanted = [
    for (final group in head)
      switch (chartSlot(group.color)) {
        final slot? when used.add(slot) => slot,
        _ => null,
      },
  ];
  final free = [
    for (var slot = 1; slot <= 8; slot++)
      if (!used.contains(slot)) slot,
  ];
  return [
    for (final (index, group) in head.indexed)
      DonutSlice(group.name, group.amountCents, wanted[index] ?? (free.isEmpty ? null : free.removeAt(0))),
    if (tail.isNotEmpty) DonutSlice('Otros', tail.fold(0, (sum, group) => sum + group.amountCents), null),
  ];
}

CarliTone deltaTone(BasisPoints? value, {required bool higherIsBetter}) {
  if (value == null || value.abs() < 50) return CarliTone.muted;
  return (value > 0) == higherIsBetter ? CarliTone.positive : CarliTone.negative;
}

String deltaIconName(BasisPoints? value) {
  if (value == null || value.abs() < 50) return 'minus';
  return value > 0 ? 'trending-up' : 'trending-down';
}

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodId = ref.watch(summaryPeriodProvider);
    final dashboard = ref.watch(dashboardProvider(periodId));
    final accounts = ref.watch(accountsProvider);
    final periods = ref.watch(periodsProvider).value;

    return CarliPage(
      title: 'Resumen',
      moduleSwitcher: true,
      trailing: const _ProfileButton(),
      onRefresh: () async {
        ref.read(financeChangesProvider.notifier).refreshAll();
        await ref.read(dashboardProvider(periodId).future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s12),
          sliver: SliverToBoxAdapter(
            child: PeriodSelector(
              selected: periods?.find(periodId) ?? dashboard.value?.period,
              onSelected: ref.read(summaryPeriodProvider.notifier).select,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: dashboard,
              errorTitle: 'No se ha podido cargar el resumen',
              onRetry: () => ref.invalidate(dashboardProvider(periodId)),
              loading: const _SummarySkeleton(),
              data: (data) => accounts.value?.all.isEmpty ?? false
                  ? CarliCard(
                      child: CarliEmptyState(
                        icon: carliIconNamed('wallet'),
                        title: 'Empieza por tus cuentas',
                        message: 'Añade tu cuenta corriente, tus tarjetas o el efectivo y apunta tu primer movimiento para ver aquí tu resumen.',
                        actionLabel: 'Añadir cuenta',
                        onAction: () => context.push(Routes.accounts),
                      ),
                    )
                  : _SummaryBody(data: data, accounts: accounts.value),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryBody extends ConsumerWidget {
  const _SummaryBody({required this.data, required this.accounts});

  final Dashboard data;
  final AccountsData? accounts;

  String? _percentDelta(BasisPoints? value) {
    final previous = data.previousPeriod?.shortName;
    if (value == null || previous == null) return null;
    return '${formatBasisPoints(value, signed: true)} vs $previous';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final period = data.period;
    final previous = data.previousPeriod?.shortName;
    final netDelta = data.netWorthDeltaCents;
    final donut = buildDonut(data.byCategory);
    final pastPeriod = period.isCurrent ? null : period;

    void reviewUncategorized() {
      ref
          .read(transactionFiltersProvider.notifier)
          .replace(const TransactionFilters(uncategorized: true).withPeriod(pastPeriod));
      context.go(Routes.transactions);
    }

    void openBudgets() {
      ref.read(budgetsPeriodProvider.notifier).select(period);
      context.go(Routes.budgets);
    }

    final savingsTarget = ref.watch(financeSettingsProvider).value?.savingsTargetPercent ?? 20;
    final rings = ActivityRings.of(data, savingsTargetPercent: savingsTarget);
    final history = data.history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s12,
      children: [
        Text(
          (period.isCurrent
                  ? '${period.name} · ${daysLeftLabel(period.daysRemaining)}'
                  : '${period.name} · ${period.rangeLabel}')
              .toUpperCase(),
          style: CarliType.eyebrow.copyWith(color: colors.text2),
        ),
        ActivityRingsCard(rings: rings, onTap: openBudgets),
        UncategorizedNotice(summary: data.uncategorized, onReview: reviewUncategorized),
        _StatGrid(
          children: [
            CarliMetricCard(
              label: 'Patrimonio',
              value: formatMoney(data.netWorthCents),
              note: netDelta == null
                  ? null
                  : '${formatMoney(netDelta, display: MoneyDisplay.signed)}${previous == null ? '' : ' vs $previous'}',
              noteIcon: carliIconNamed(netDelta == null || netDelta >= 0 ? 'trending-up' : 'trending-down'),
              noteTone: (netDelta ?? 0) >= 0 ? CarliTone.positive : CarliTone.negative,
              trend: [for (final point in history) point.netWorthCents],
              onTap: () => context.push(Routes.accounts),
            ),
            CarliMetricCard(
              label: 'Ingresos',
              value: formatMoney(data.incomeCents),
              tone: CarliTone.positive,
              note: _percentDelta(data.incomeDeltaBp),
              noteIcon: carliIconNamed(deltaIconName(data.incomeDeltaBp)),
              noteTone: deltaTone(data.incomeDeltaBp, higherIsBetter: true),
              trend: [for (final point in history) point.incomeCents],
            ),
            CarliMetricCard(
              label: 'Gastos',
              value: formatMoney(data.expenseCents),
              note: _percentDelta(data.expenseDeltaBp),
              noteIcon: carliIconNamed(deltaIconName(data.expenseDeltaBp)),
              noteTone: deltaTone(data.expenseDeltaBp, higherIsBetter: false),
              trend: [for (final point in history) point.expenseCents],
              onTap: () {
                ref
                    .read(transactionFiltersProvider.notifier)
                    .replace(const TransactionFilters().withPeriod(pastPeriod));
                context.go(Routes.transactions);
              },
            ),
            CarliMetricCard(
              label: 'Ahorro',
              value: formatMoney(data.savingsCents),
              tone: data.savingsCents < 0 ? CarliTone.negative : CarliTone.normal,
              note: data.savingsRateBp == null
                  ? 'Sin ingresos este periodo'
                  : 'Tasa ${formatBasisPoints(data.savingsRateBp)}',
              trend: [for (final point in history) point.incomeCents - point.expenseCents],
            ),
          ],
        ),
        _Section(
          title: 'Ingresos y gastos',
          child: history.isEmpty
              ? const _Muted('Aún no hay periodos anteriores con los que comparar.')
              : CarliChart(
                  type: CarliChartType.bar,
                  semanticLabel: 'Ingresos y gastos de los últimos periodos',
                  labels: [for (final point in history) point.label],
                  series: [
                    CarliSeries('Ingresos', [for (final point in history) point.incomeCents]),
                    CarliSeries('Gastos', [for (final point in history) point.expenseCents]),
                  ],
                ),
        ),
        _Section(
          title: 'Gasto por categoría',
          child: donut.isEmpty
              ? CarliEmptyState(
                  icon: carliIconNamed('chart-pie'),
                  title: 'Sin gastos en este periodo',
                  message: 'Cuando apuntes gastos verás aquí en qué se va el dinero.',
                )
              : Column(
                  spacing: CarliSpace.s12,
                  children: [
                    CarliChart(
                      type: CarliChartType.donut,
                      height: 180,
                      showLegend: false,
                      centerLabel: 'Gastado',
                      semanticLabel: 'Gasto por categoría',
                      labels: [for (final slice in donut) slice.label],
                      colors: [for (final slice in donut) slice.color(colors)],
                      series: [
                        CarliSeries('Gasto', [for (final slice in donut) slice.amount]),
                      ],
                    ),
                    for (final slice in donut.take(6))
                      Row(
                        spacing: CarliSpace.s8,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: slice.color(colors), shape: BoxShape.circle),
                          ),
                          Expanded(
                            child: Text(slice.label, style: CarliType.small.copyWith(color: colors.text)),
                          ),
                          Text(
                            formatMoney(slice.amount),
                            style: CarliType.money(CarliType.small).copyWith(color: colors.text2),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        _Section(
          title: 'Presupuestos',
          actionLabel: 'Ver todos',
          onAction: openBudgets,
          child: data.topBudgets.isEmpty
              ? CarliEmptyState(
                  icon: carliIconNamed('gauge'),
                  title: 'Sin presupuestos',
                  message: 'Pon un límite a las categorías en las que más gastas.',
                  actionLabel: 'Crear presupuestos',
                  onAction: openBudgets,
                )
              : Column(
                  spacing: CarliSpace.s16,
                  children: [for (final row in data.topBudgets) BudgetLine(row: row)],
                ),
        ),
        _Section(
          title: 'Próximos cargos',
          padded: data.upcoming.isEmpty,
          child: data.upcoming.isEmpty
              ? const _Muted('No hay cargos recurrentes en los próximos 7 días.')
              : Column(
                  children: [
                    for (final charge in data.upcoming)
                      CarliListItem(
                        title: charge.name,
                        subtitle: upcomingSubtitle(charge),
                        icon: carliIconNamed(charge.category?.icon ?? 'repeat'),
                        trailing: Text(
                          formatMoney(charge.amountCents, display: MoneyDisplay.signed),
                          style: CarliType.money(CarliType.body).copyWith(
                            fontWeight: FontWeight.w600,
                            color: charge.amountCents > 0 ? colors.positive : colors.text,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        _Section(
          title: 'Últimos movimientos',
          actionLabel: 'Ver todos',
          padded: data.recentTransactions.isEmpty,
          onAction: () {
            ref.read(transactionFiltersProvider.notifier).replace(const TransactionFilters());
            context.go(Routes.transactions);
          },
          child: data.recentTransactions.isEmpty
              ? CarliEmptyState(
                  icon: carliIconNamed('inbox'),
                  title: 'Aún no hay movimientos',
                  message: 'Apunta tu primer gasto y empezarás a ver tu resumen.',
                  actionLabel: 'Añadir movimiento',
                  onAction: () => showTransactionSheet(context),
                )
              : Column(
                  children: [
                    for (final (index, transaction) in data.recentTransactions.indexed) ...[
                      if (index > 0) Divider(indent: 68, color: colors.border),
                      TransactionRow(
                        transaction: transaction,
                        accounts: accounts,
                        onTap: () => showTransactionSheet(context, transaction: transaction),
                      ),
                    ],
                  ],
                ),
        ),
        _Section(
          title: 'Patrimonio',
          child: history.length > 1
              ? CarliChart(
                  type: CarliChartType.line,
                  showLegend: false,
                  semanticLabel: 'Evolución del patrimonio',
                  labels: [for (final point in history) point.label],
                  series: [
                    CarliSeries('Patrimonio', [for (final point in history) point.netWorthCents]),
                  ],
                )
              : const _Muted('La evolución aparecerá cuando tengas más de un periodo.'),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: CarliSpace.s12,
      children: [
        for (var row = 0; row < children.length; row += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: CarliSpace.s12,
              children: [
                Expanded(child: children[row]),
                Expanded(child: row + 1 < children.length ? children[row + 1] : const SizedBox.shrink()),
              ],
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.actionLabel, this.onAction, this.padded = true});

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: CarliSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s8,
        children: [
          CarliSectionHeader(title: title, actionLabel: actionLabel, onAction: onAction),
          CarliCard(
            padding: padded
                ? const EdgeInsets.all(CarliSpace.s16)
                : const EdgeInsets.symmetric(vertical: CarliSpace.s4),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Avatar at the top right, as in Fitness: opens Ajustes.
class _ProfileButton extends ConsumerWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = switch (ref.watch(authControllerProvider)) {
      SignedIn(:final user?) => user.name,
      _ => '',
    };
    return Semantics(
      button: true,
      label: 'Ajustes',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => context.push(Routes.settings),
        child: CarliAvatar(name: name, size: 32),
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: CarliType.small.copyWith(color: context.colors.text2));
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    const stat = CarliCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CarliSpace.s8,
        children: [CarliSkeleton(width: 90, height: 13), CarliSkeleton(width: 130, height: 28)],
      ),
    );
    return const Column(
      spacing: CarliSpace.s12,
      children: [
        _StatGrid(children: [stat, stat, stat, stat]),
        CarliCard(child: CarliSkeleton(height: 220)),
        CarliCard(child: CarliSkeleton(height: 220)),
      ],
    );
  }
}
