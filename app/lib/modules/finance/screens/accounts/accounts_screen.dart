import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/money.dart';
import '../../../../core/router/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/async_view.dart';
import '../../../../ui/badge.dart';
import '../../../../ui/button.dart';
import '../../../../ui/card.dart';
import '../../../../ui/empty_state.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/page.dart';
import '../../../../ui/pressable.dart';
import '../../../../ui/progress.dart';
import '../../../../ui/skeleton.dart';
import '../../data/accounts_admin.dart';
import '../../data/finance_changes.dart';
import '../../data/transaction_filters.dart';
import 'account_actions.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  var _showArchived = false;

  Future<void> _refresh() async {
    ref.read(financeChangesProvider.notifier).notify(const [FinanceScope.accounts]);
    await ref.read(accountsOverviewProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(accountsOverviewProvider);
    return CarliPage(
      title: 'Cuentas',
      trailing: CarliButton.icon(
        icon: carliIconNamed('plus'),
        semanticLabel: 'Nueva cuenta',
        onPressed: () => editAccount(context, ref),
      ),
      onRefresh: _refresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: overview,
              errorTitle: 'No se han podido cargar las cuentas',
              onRetry: () => ref.invalidate(accountsOverviewProvider),
              loading: const _AccountsSkeleton(),
              data: (data) => data.all.isEmpty
                  ? CarliCard(
                      child: CarliEmptyState(
                        icon: carliIconNamed('landmark'),
                        title: 'Aún no tienes cuentas',
                        message: 'Crea tu cuenta corriente, tu tarjeta o el efectivo con su saldo actual y empieza a apuntar movimientos.',
                        actionLabel: 'Añadir cuenta',
                        onAction: () => editAccount(context, ref),
                      ),
                    )
                  : _AccountsBody(
                      data: data,
                      showArchived: _showArchived,
                      onToggleArchived: () => setState(() => _showArchived = !_showArchived),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountsBody extends StatelessWidget {
  const _AccountsBody({required this.data, required this.showArchived, required this.onToggleArchived});

  final AccountsOverview data;
  final bool showArchived;
  final VoidCallback onToggleArchived;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = data.active;
    final archived = data.archived;
    final visible = showArchived ? [...active, ...archived] : active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s12,
      children: [
        CarliCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CarliSpace.s4,
            children: [
              Text('Patrimonio neto', style: CarliType.small.copyWith(color: colors.text2)),
              Text(formatMoney(data.netWorthCents), style: CarliType.display.copyWith(color: colors.text)),
              Text(accountsSummaryLabel(active), style: CarliType.small.copyWith(color: colors.text2)),
            ],
          ),
        ),
        for (final account in visible) AccountCard(account: account),
        if (archived.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              child: Pressable(
                onTap: onToggleArchived,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: CarliSpace.s8, horizontal: CarliSpace.s4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      CarliIcon(carliIconNamed('archive'), size: 14, color: colors.text3),
                      Text(
                        '${archivedAccountsLabel(archived.length)} · ${showArchived ? 'ocultar' : 'mostrar'}',
                        style: CarliType.small.copyWith(color: colors.text3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AccountCard extends ConsumerWidget {
  const AccountCard({super.key, required this.account});

  final AccountDetails account;

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final action = await showAccountMenu(context, account);
    if (action != null && context.mounted) await runAccountAction(context, ref, account, action);
  }

  void _openTransactions(BuildContext context, WidgetRef ref) {
    ref.read(transactionFiltersProvider.notifier).replace(TransactionFilters(accountIds: {account.id}));
    context.go(Routes.transactions);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final limit = account.creditLimitCents;
    final used = account.usedCreditCents ?? 0;
    final schedule = cardSchedule(account);
    final secondary = CarliType.small.copyWith(color: colors.text3);
    final bank = account.bank;
    final subtitle = '${account.typeLabel}${account.includeInNetWorth ? '' : ' · fuera del patrimonio'}';
    return Opacity(
      opacity: account.archived ? 0.75 : 1,
      child: CarliCard(
        onTap: () => context.push(Routes.account(account.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: CarliSpace.s12,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
                  child: CarliIcon(carliIconNamed(account.iconName), size: 18, color: colors.text),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CarliType.bodyStrong.copyWith(color: colors.text),
                      ),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: secondary),
                    ],
                  ),
                ),
                if (account.archived) CarliBadge('Archivada', icon: carliIconNamed('archive')),
                CarliButton.icon(
                  icon: carliIconNamed('ellipsis'),
                  semanticLabel: 'Opciones de ${account.name}',
                  size: CarliButtonSize.sm,
                  onPressed: () => _openMenu(context, ref),
                ),
              ],
            ),
            const SizedBox(height: CarliSpace.s16),
            Text(
              formatMoney(account.balanceCents),
              style: CarliType.money(CarliType.h1.copyWith(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600))
                  .copyWith(color: account.balanceCents < 0 && !account.isCreditCard ? colors.negative : colors.text),
            ),
            const SizedBox(height: CarliSpace.s4),
            if (account.isCreditCard && limit != null && limit > 0) ...[
              const SizedBox(height: 6),
              CarliProgress(
                ratio: ratioOf(used, limit).toDouble(),
                tone: ProgressTone.goal,
                label: 'Crédito dispuesto de ${account.name}',
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dispuesto ${formatMoney(used)}', style: CarliType.small.copyWith(color: colors.text2)),
                  Text(
                    'Disponible ${formatMoney(account.availableCreditCents ?? 0)}',
                    style: CarliType.small.copyWith(color: colors.text2),
                  ),
                ],
              ),
              if (schedule != null) Text(schedule, style: secondary),
            ] else if (account.pendingCents != 0)
              Text(
                'Pendiente ${formatMoney(account.pendingCents, display: MoneyDisplay.signed)} · confirmado ${formatMoney(account.clearedBalanceCents)}',
                style: secondary,
              )
            else
              Text('Todo confirmado', style: secondary),
            if (bank != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: BankBalanceLine(link: bank),
              ),
            const SizedBox(height: 14),
            Row(
              spacing: CarliSpace.s8,
              children: [
                CarliButton(
                  label: 'Movimientos',
                  icon: carliIconNamed('list'),
                  variant: CarliButtonVariant.secondary,
                  size: CarliButtonSize.sm,
                  block: false,
                  onPressed: () => _openTransactions(context, ref),
                ),
                CarliButton(
                  label: 'Conciliar',
                  icon: carliIconNamed('check-check'),
                  variant: CarliButtonVariant.ghost,
                  size: CarliButtonSize.sm,
                  block: false,
                  onPressed: () => reconcileAccount(context, account),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsSkeleton extends StatelessWidget {
  const _AccountsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      spacing: CarliSpace.s12,
      children: [
        CarliCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CarliSpace.s8,
            children: [CarliSkeleton(width: 110, height: 12), CarliSkeleton(width: 200, height: 40)],
          ),
        ),
        CarliCard(child: CarliSkeleton(height: 140)),
        CarliCard(child: CarliSkeleton(height: 140)),
      ],
    );
  }
}
