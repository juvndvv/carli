import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/router/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/badge.dart';
import '../../../ui/button.dart';
import '../../../ui/card.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/page.dart';
import '../../../ui/pressable.dart';
import '../../../ui/skeleton.dart';
import '../../../ui/stat.dart';
import '../../../ui/toast.dart';
import '../data/finance_changes.dart';
import '../data/finance_format.dart';
import '../data/finance_providers.dart';
import '../data/models.dart';
import '../data/transaction_filters.dart';
import '../data/transactions_repository.dart';
import '../ui/budget_line.dart';
import '../ui/period_selector.dart';
import '../ui/uncategorized_notice.dart';
import 'budget_editor.dart';

String budgetStatusIconName(BudgetStatus status) => switch (status) {
  BudgetStatus.ok => 'check',
  BudgetStatus.warning => 'triangle-alert',
  BudgetStatus.exceeded => 'circle-x',
};

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodId = ref.watch(budgetsPeriodProvider);
    final overview = ref.watch(budgetsProvider(periodId));
    final periods = ref.watch(periodsProvider).value;

    return CarliPage(
      title: 'Presupuestos',
      onRefresh: () async {
        ref.read(financeChangesProvider.notifier).notify(const [FinanceScope.budgets, FinanceScope.periods]);
        await ref.read(budgetsProvider(periodId).future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s12),
          sliver: SliverToBoxAdapter(
            child: PeriodSelector(
              selected: periods?.find(periodId) ?? overview.value?.period,
              onSelected: ref.read(budgetsPeriodProvider.notifier).select,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: overview,
              errorTitle: 'No se han podido cargar los presupuestos',
              onRetry: () => ref.invalidate(budgetsProvider(periodId)),
              loading: const _BudgetsSkeleton(),
              data: (data) => _BudgetsBody(data: data),
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetsBody extends ConsumerStatefulWidget {
  const _BudgetsBody({required this.data});

  final BudgetOverview data;

  @override
  ConsumerState<_BudgetsBody> createState() => _BudgetsBodyState();
}

class _BudgetsBodyState extends ConsumerState<_BudgetsBody> {
  var _copying = false;

  BudgetOverview get data => widget.data;

  Future<void> _copyFrom(Period previous) async {
    setState(() => _copying = true);
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      final result = await ref.read(budgetsRepositoryProvider).copy(from: previous.id, to: data.period.id);
      final copied = result.copied ?? 0;
      toasts.show(switch (copied) {
        0 => 'No había nada nuevo que copiar de ${previous.shortName}',
        1 => '1 presupuesto copiado de ${previous.shortName}',
        _ => '$copied presupuestos copiados de ${previous.shortName}',
      });
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se han podido copiar los presupuestos.'));
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Future<void> _edit() async {
    if (await showBudgetEditor(context, data)) {
      ref.read(toastControllerProvider.notifier).show('Presupuestos guardados');
    }
  }

  void _openTransactions(BudgetRow row) {
    ref
        .read(transactionFiltersProvider.notifier)
        .replace(
          TransactionFilters(
            categoryIds: {row.categoryId},
            kinds: const {TransactionKind.expense},
          ).withPeriod(data.period),
        );
    context.go(Routes.transactions);
  }

  String? _nextPayrollLabel(FinanceSettings? settings) {
    final end = data.period.expectedEndDate;
    if (end == null) return null;
    return settings?.calendarPeriods ?? false
        ? 'termina el ${formatShortDate(end)}'
        : 'nómina prevista el ${formatShortDate(end.add(const Duration(days: 1)))}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = ref.watch(financeSettingsProvider).value;
    final rows = [...data.rows]..sort((left, right) => left.category.sortKey.compareTo(right.category.sortKey));
    final budgeted = rows.fold<int>(0, (sum, row) => sum + budgetLimit(row));
    final totals = data.totals;
    final period = data.period;
    final previous = data.previousPeriod;
    final projectionOver = budgeted > 0 && totals.projectedCents > budgeted;
    final spentPercent = budgeted > 0
        ? '${formatPercentRounded((totals.spentCents * 10000 / budgeted).round())} del total'
        : null;
    final spentDelta = [
      spentPercent,
      if (period.isCurrent) _nextPayrollLabel(settings),
    ].whereType<String>().join(' · ');
    final gap = totals.projectedCents - budgeted;
    final threshold = settings?.budgetWarningThreshold ?? 80;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s12,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: CarliSpace.s12,
            children: [
              Expanded(
                child: CarliStat(
                  label: 'Presupuestado',
                  value: formatMoney(budgeted),
                  delta: rows.length == 1 ? '1 categoría' : '${rows.length} categorías',
                ),
              ),
              Expanded(
                child: CarliStat(
                  label: 'Gastado',
                  value: formatMoney(totals.spentCents),
                  delta: spentDelta.isEmpty ? null : spentDelta,
                ),
              ),
            ],
          ),
        ),
        if (period.isCurrent)
          CarliStat(
            label: 'Proyección fin de periodo',
            value: formatMoney(totals.projectedCents),
            tone: projectionOver ? CarliTone.warning : CarliTone.normal,
            delta: budgeted == 0
                ? 'Según tu ritmo de gasto'
                : gap > 0
                ? 'Superarías el total en ${formatMoney(gap)}'
                : 'Te sobrarían ${formatMoney(-gap)}',
            deltaIcon: carliIconNamed(projectionOver ? 'triangle-alert' : 'circle-check'),
            deltaTone: projectionOver ? CarliTone.warning : CarliTone.muted,
          )
        else
          CarliStat(
            label: 'Resultado',
            value: formatMoney(totals.remainingCents),
            tone: totals.remainingCents < 0 ? CarliTone.negative : CarliTone.positive,
            delta: totals.remainingCents < 0 ? 'Te pasaste del total' : 'Te sobró del total',
          ),
        UncategorizedNotice(
          summary: data.uncategorized,
          onReview: () {
            ref
                .read(transactionFiltersProvider.notifier)
                .replace(const TransactionFilters(uncategorized: true).withPeriod(period));
            context.go(Routes.transactions);
          },
        ),
        CarliCard(
          padding: const EdgeInsets.only(bottom: CarliSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, CarliSpace.s8),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text('Por categoría', style: CarliType.h2.copyWith(color: colors.text)),
                      ),
                    ),
                    if (previous != null && rows.isNotEmpty)
                      CarliButton.icon(
                        icon: carliIconNamed('copy'),
                        semanticLabel: 'Copiar de ${previous.shortName}',
                        size: CarliButtonSize.sm,
                        loading: _copying,
                        onPressed: () => _copyFrom(previous),
                      ),
                    if (rows.isNotEmpty) ...[
                      const SizedBox(width: CarliSpace.s8),
                      CarliButton(
                        label: 'Editar',
                        icon: carliIconNamed('pencil'),
                        variant: CarliButtonVariant.secondary,
                        size: CarliButtonSize.sm,
                        block: false,
                        onPressed: _edit,
                      ),
                    ],
                  ],
                ),
              ),
              if (rows.isEmpty)
                Column(
                  children: [
                    CarliEmptyState(
                      icon: carliIconNamed('gauge'),
                      title: 'Aún no hay presupuestos en este periodo',
                      message:
                          'Pon un límite a cada categoría y te avisaremos al llegar al $threshold % y al superarlo.',
                      actionLabel: 'Crear presupuestos',
                      onAction: _edit,
                    ),
                    if (previous != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: CarliSpace.s16),
                        child: CarliButton(
                          label: 'Copiar de ${previous.shortName}',
                          icon: carliIconNamed('copy'),
                          variant: CarliButtonVariant.secondary,
                          size: CarliButtonSize.md,
                          block: false,
                          loading: _copying,
                          onPressed: () => _copyFrom(previous),
                        ),
                      ),
                  ],
                )
              else
                for (final (index, row) in rows.indexed) ...[
                  if (index > 0) Divider(indent: 68, color: colors.border),
                  _BudgetRowTile(row: row, showProjection: period.isCurrent, onTap: () => _openTransactions(row)),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetRowTile extends StatelessWidget {
  const _BudgetRowTile({required this.row, required this.showProjection, required this.onTap});

  final BudgetRow row;
  final bool showProjection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      hint: 'Ver movimientos',
      child: Pressable(
        onTap: onTap,
        pressedOpacity: 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CarliSpace.s12,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
                child: CarliIcon(
                  carliIconNamed(row.category.icon ?? fallbackCategoryIcon),
                  size: 20,
                  color: colors.text,
                ),
              ),
              Expanded(
                child: BudgetLine(
                  row: row,
                  showProjection: showProjection,
                  badge: CarliBadge(budgetUsageLabel(row), icon: carliIconNamed(budgetStatusIconName(row.status))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetsSkeleton extends StatelessWidget {
  const _BudgetsSkeleton();

  @override
  Widget build(BuildContext context) {
    const stat = CarliCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CarliSpace.s8,
        children: [CarliSkeleton(width: 90, height: 13), CarliSkeleton(width: 120, height: 28)],
      ),
    );
    return const Column(
      spacing: CarliSpace.s12,
      children: [
        Row(
          spacing: CarliSpace.s12,
          children: [
            Expanded(child: stat),
            Expanded(child: stat),
          ],
        ),
        stat,
        CarliCard(child: CarliSkeleton(height: 260)),
      ],
    );
  }
}
