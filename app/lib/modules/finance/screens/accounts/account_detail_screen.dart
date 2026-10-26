import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';
import '../../../../core/router/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/button.dart';
import '../../../../ui/card.dart';
import '../../../../ui/empty_state.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/page.dart';
import '../../../../ui/pressable.dart';
import '../../../../ui/progress.dart';
import '../../../../ui/skeleton.dart';
import '../../../../ui/stat.dart';
import '../../data/accounts_admin.dart';
import '../../data/finance_changes.dart';
import '../../data/finance_providers.dart';
import '../../data/models.dart';
import '../../data/transaction_filters.dart';
import '../../data/transactions_list.dart';
import '../../ui/transaction_row.dart';
import '../transaction_sheet.dart';
import 'account_actions.dart';
import 'balance_chart.dart';

const _recentLimit = 50;

bool _isMissing(Object? error) => error is DioException && error.response?.statusCode == 404;

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(financeChangesProvider.notifier).notify(const [FinanceScope.accounts, FinanceScope.transactions]);
    await ref.read(accountDetailsProvider(accountId).future).then((_) {}, onError: (_) {});
  }

  Future<void> _openMenu(BuildContext context, WidgetRef ref, Account account) async {
    final action = await showAccountMenu(
      context,
      account,
      actions: const {
        AccountAction.edit,
        AccountAction.reconcile,
        AccountAction.toggleNetWorth,
        AccountAction.toggleArchived,
        AccountAction.delete,
      },
    );
    if (action == null || !context.mounted) return;
    await runAccountAction(
      context,
      ref,
      account,
      action,
      onDeleted: () {
        if (context.mounted) context.canPop() ? context.pop() : context.go(Routes.accounts);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(accountDetailsProvider(accountId));
    final account = details.value;
    return CarliPage(
      title: account?.name ?? 'Cuenta',
      trailing: account == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CarliButton.icon(
                  icon: carliIconNamed('plus'),
                  semanticLabel: 'Nuevo movimiento',
                  onPressed: () => showTransactionSheet(context, preset: TransactionPreset(accountId: account.id)),
                ),
                CarliButton.icon(
                  icon: carliIconNamed('ellipsis'),
                  semanticLabel: 'Opciones de ${account.name}',
                  onPressed: () => _openMenu(context, ref, account),
                ),
              ],
            ),
      onRefresh: () => _refresh(ref),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: switch (details) {
              AsyncValue(hasValue: true, value: final account?) => _DetailBody(account: account),
              AsyncValue(hasError: true, :final error) when _isMissing(error) => CarliCard(
                child: CarliEmptyState(
                  icon: carliIconNamed('landmark'),
                  title: 'No encontramos esta cuenta',
                  message: 'Puede que se haya eliminado.',
                  actionLabel: 'Volver a cuentas',
                  onAction: () => context.canPop() ? context.pop() : context.go(Routes.accounts),
                ),
              ),
              AsyncValue(hasError: true) => CarliCard(
                child: CarliEmptyState(
                  icon: carliIconNamed('circle-alert'),
                  title: 'No se ha podido cargar la cuenta',
                  message: 'Comprueba tu conexión e inténtalo de nuevo.',
                  actionLabel: 'Reintentar',
                  onAction: () => ref.invalidate(accountDetailsProvider(accountId)),
                ),
              ),
              _ => const _DetailSkeleton(),
            },
          ),
        ),
      ],
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.account});

  final Account account;

  void _openAll(BuildContext context, WidgetRef ref) {
    ref
        .read(transactionFiltersProvider.notifier)
        .replace(TransactionFilters(accountIds: {account.id}, periodScope: PeriodScope.all));
    context.go(Routes.transactions);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final history = ref.watch(accountHistoryProvider(account.id));
    final accounts = ref.watch(accountsProvider).value;
    final loading = !history.hasValue && !history.hasError;
    final items = history.value ?? const <Transaction>[];
    final points = balanceHistory(account.balanceCents, items, today(), accountHistoryDays);
    final groups = groupByDay(items.take(_recentLimit).toList(), hideIncomingTransfers: false);
    final bank = account.bank;
    final limit = account.creditLimitCents;
    final schedule = cardSchedule(account);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s12,
      children: [
        CarliStat(
          label: 'Saldo actual',
          icon: carliIconNamed(account.isCreditCard ? 'credit-card' : 'wallet'),
          value: formatMoney(account.balanceCents),
          tone: account.balanceCents < 0 && !account.isCreditCard ? CarliTone.negative : CarliTone.normal,
          delta: account.typeLabel,
        ),
        if (account.isCreditCard && limit != null && limit > 0)
          CarliCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Crédito', style: CarliType.small.copyWith(color: colors.text2)),
                const SizedBox(height: CarliSpace.s8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _LabeledFigure(label: 'Dispuesto', cents: account.usedCreditCents ?? 0),
                    _LabeledFigure(label: 'Disponible', cents: account.availableCreditCents ?? 0),
                  ],
                ),
                const SizedBox(height: CarliSpace.s8),
                CarliProgress(
                  ratio: ratioOf(account.usedCreditCents ?? 0, limit).toDouble(),
                  tone: ProgressTone.goal,
                  label: 'Crédito dispuesto',
                ),
                const SizedBox(height: 6),
                Text(
                  'Límite ${formatMoney(limit)}${schedule == null ? '' : ' · $schedule'}',
                  style: CarliType.small.copyWith(color: colors.text3),
                ),
              ],
            ),
          )
        else
          CarliStat(
            label: 'Confirmado',
            icon: carliIconNamed('circle-check'),
            value: formatMoney(account.clearedBalanceCents),
            delta: account.pendingCents == 0 ? 'Todo confirmado' : 'Sin contar pendientes',
          ),
        CarliStat(
          label: 'Pendiente',
          icon: carliIconNamed('clock'),
          tone: account.pendingCents == 0 ? CarliTone.muted : CarliTone.warning,
          value: formatMoney(account.pendingCents, display: MoneyDisplay.signed),
          delta: account.includeInNetWorth ? 'Suma al patrimonio' : 'Fuera del patrimonio',
        ),
        if (bank != null)
          CarliCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: CarliSpace.s12,
              children: [
                BankBalanceLine(link: bank, detailed: true),
                Row(
                  spacing: CarliSpace.s8,
                  children: [
                    CarliButton(
                      label: 'Banco',
                      icon: carliIconNamed('settings'),
                      variant: CarliButtonVariant.ghost,
                      size: CarliButtonSize.sm,
                      block: false,
                      onPressed: () => context.push(Routes.banks),
                    ),
                    if (bank.differenceCents case final difference? when difference != 0)
                      CarliButton(
                        label: 'Conciliar',
                        icon: carliIconNamed('check-check'),
                        variant: CarliButtonVariant.secondary,
                        size: CarliButtonSize.sm,
                        block: false,
                        onPressed: () => reconcileAccount(context, account),
                      ),
                  ],
                ),
              ],
            ),
          ),
        CarliCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: CarliSpace.s12,
            children: [
              Semantics(
                header: true,
                child: Text('Evolución del saldo · 90 días', style: CarliType.h2.copyWith(color: colors.text)),
              ),
              if (loading) const CarliSkeleton(height: 220) else BalanceChart(points: points),
            ],
          ),
        ),
        CarliCard(
          padding: const EdgeInsets.only(bottom: CarliSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, CarliSpace.s4),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text('Movimientos recientes', style: CarliType.h2.copyWith(color: colors.text)),
                      ),
                    ),
                    Semantics(
                      button: true,
                      child: Pressable(
                        onTap: () => _openAll(context, ref),
                        child: Padding(
                          padding: const EdgeInsets.all(CarliSpace.s4),
                          child: Text('Ver todos', style: CarliType.small.copyWith(color: colors.brandInk)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(CarliSpace.s16),
                  child: Column(
                    spacing: CarliSpace.s8,
                    children: [CarliSkeleton(height: 56), CarliSkeleton(height: 56)],
                  ),
                )
              else if (groups.isEmpty)
                CarliEmptyState(
                  icon: carliIconNamed('inbox'),
                  title: 'Sin movimientos',
                  message: 'Los movimientos de esta cuenta aparecerán aquí.',
                  actionLabel: 'Añadir movimiento',
                  onAction: () => showTransactionSheet(context, preset: TransactionPreset(accountId: account.id)),
                )
              else
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s12, CarliSpace.s16, 0),
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
                  for (final (index, transaction) in group.items.indexed) ...[
                    if (index > 0) Divider(indent: 68, color: colors.border),
                    TransactionRow(
                      transaction: transaction,
                      accounts: accounts,
                      showAccount: false,
                      onTap: () => showTransactionSheet(context, transaction: transaction),
                    ),
                  ],
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledFigure extends StatelessWidget {
  const _LabeledFigure({required this.label, required this.cents});

  final String label;
  final Cents cents;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text.rich(
      TextSpan(
        style: CarliType.small.copyWith(color: colors.text2),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: formatMoney(cents),
            style: CarliType.money(CarliType.small).copyWith(fontWeight: FontWeight.w600, color: colors.text),
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    const stat = CarliCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CarliSpace.s8,
        children: [CarliSkeleton(width: 90, height: 13), CarliSkeleton(width: 140, height: 28)],
      ),
    );
    return const Column(spacing: CarliSpace.s12, children: [stat, stat, stat]);
  }
}
