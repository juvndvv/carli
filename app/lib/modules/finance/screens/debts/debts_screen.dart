import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';
import '../../../../core/router/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/async_view.dart';
import '../../../../ui/avatar.dart';
import '../../../../ui/badge.dart';
import '../../../../ui/button.dart';
import '../../../../ui/card.dart';
import '../../../../ui/empty_state.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/list_item.dart';
import '../../../../ui/page.dart';
import '../../../../ui/pressable.dart';
import '../../../../ui/progress.dart';
import '../../../../ui/skeleton.dart';
import '../../../../ui/stat.dart';
import '../../data/debts.dart';
import '../../data/finance_providers.dart';
import '../../data/models.dart';
import 'debt_detail_sheet.dart';
import 'debt_sheet.dart';

String openDebtsLabel(int count) => switch (count) {
  0 => 'Nada pendiente',
  1 => '1 deuda abierta',
  _ => '$count deudas abiertas',
};

String? debtNextDateLabel(Debt debt) {
  if (debt.nextPaymentDate case final next?) return 'Próx. ${formatShortDate(next)}';
  if (debt.dueDate case final due?) return 'Vence ${formatShortDate(due)}';
  return null;
}

String contactBalanceLabel(Cents balance) {
  if (balance > 0) return 'Te debe ${formatMoney(balance)}';
  if (balance < 0) return 'Le debes ${formatMoney(-balance)}';
  return 'En paz';
}

CarliBadge debtDirectionBadge(Debt debt) =>
    CarliBadge(debt.direction.label, tone: debt.owesMe ? CarliBadgeTone.positive : CarliBadgeTone.neutral);

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider);
    return CarliPage(
      title: 'Deudas',
      trailing: CarliButton.icon(
        icon: carliIconNamed('plus'),
        semanticLabel: 'Nueva deuda',
        size: CarliButtonSize.sm,
        onPressed: () => showDebtSheet(context),
      ),
      onRefresh: () async {
        ref.invalidate(debtsProvider);
        ref.invalidate(contactOptionsProvider);
        await ref.read(debtsProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: debts,
              errorTitle: 'No se han podido cargar las deudas',
              onRetry: () => ref.invalidate(debtsProvider),
              loading: const _DebtsSkeleton(),
              data: (overview) => Column(
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
                            label: 'Te deben',
                            icon: carliIconNamed('arrow-down-left'),
                            tone: CarliTone.positive,
                            value: formatMoney(overview.owedToMeCents),
                            delta: openDebtsLabel(overview.openCount(DebtDirection.owedToMe)),
                          ),
                        ),
                        Expanded(
                          child: CarliStat(
                            label: 'Debes',
                            icon: carliIconNamed('arrow-up-right'),
                            value: formatMoney(overview.iOweCents),
                            delta: openDebtsLabel(overview.openCount(DebtDirection.iOwe)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _DebtsCard(overview: overview),
                  const _SharedCard(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, {this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, CarliSpace.s8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: CarliType.h2.copyWith(color: context.colors.text)),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class _DebtsCard extends StatefulWidget {
  const _DebtsCard({required this.overview});

  final DebtsOverview overview;

  @override
  State<_DebtsCard> createState() => _DebtsCardState();
}

class _DebtsCardState extends State<_DebtsCard> {
  var _showClosed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final open = widget.overview.open;
    final closed = widget.overview.closed;
    return CarliCard(
      padding: const EdgeInsets.only(bottom: CarliSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle('Préstamos y deudas'),
          if (open.isEmpty)
            CarliEmptyState(
              icon: carliIconNamed('hand-coins'),
              title: 'Sin deudas pendientes',
              message: 'Apunta préstamos y dinero que debes o te deben, y lleva la cuenta de cada pago.',
              actionLabel: 'Nueva deuda',
              onAction: () => showDebtSheet(context),
            )
          else
            for (final (index, debt) in open.indexed) ...[
              if (index > 0) Divider(indent: CarliSpace.s16, endIndent: CarliSpace.s16, color: colors.border),
              DebtTile(debt: debt, onTap: () => showDebtDetailSheet(context, debt)),
            ],
          if (closed.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(CarliSpace.s8, CarliSpace.s8, CarliSpace.s8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  expanded: _showClosed,
                  child: Pressable(
                    onTap: () => setState(() => _showClosed = !_showClosed),
                    child: Padding(
                      padding: const EdgeInsets.all(CarliSpace.s8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: CarliSpace.s4,
                        children: [
                          Text(
                            'Saldadas (${closed.length})',
                            style: CarliType.small.copyWith(fontWeight: FontWeight.w600, color: colors.text2),
                          ),
                          CarliIcon(
                            carliIconNamed(_showClosed ? 'chevron-up' : 'chevron-down'),
                            size: 16,
                            color: colors.text2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_showClosed)
              for (final debt in closed)
                CarliListItem(
                  title: debt.name,
                  subtitle: debt.subtitle,
                  icon: carliIconNamed('check'),
                  trailing: Text(
                    formatMoney(debt.principalCents),
                    style: CarliType.money(CarliType.body).copyWith(color: colors.text2),
                  ),
                  onTap: () => showDebtDetailSheet(context, debt),
                ),
          ],
        ],
      ),
    );
  }
}

class DebtTile extends StatelessWidget {
  const DebtTile({super.key, required this.debt, required this.onTap});

  final Debt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final next = debtNextDateLabel(debt);
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        pressedOpacity: 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: CarliSpace.s8,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(debt.name, style: CarliType.bodyStrong.copyWith(color: colors.text)),
                        Text(debt.subtitle, style: CarliType.small.copyWith(color: colors.text3)),
                      ],
                    ),
                  ),
                  debtDirectionBadge(debt),
                ],
              ),
              const SizedBox(height: CarliSpace.s8),
              DebtFigures(debt: debt, trailing: next),
              const SizedBox(height: 6),
              CarliProgress(ratio: debt.ratio, tone: ProgressTone.goal, label: 'Pagado de ${debt.name}'),
            ],
          ),
        ),
      ),
    );
  }
}

class DebtFigures extends StatelessWidget {
  const DebtFigures({super.key, required this.debt, this.trailing});

  final Debt debt;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = CarliType.small.copyWith(color: colors.text2);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: CarliSpace.s8,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'Pendiente ',
              children: [
                TextSpan(
                  text: formatMoney(debt.pendingCents),
                  style: CarliType.money(style).copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
                TextSpan(text: ' de ${formatMoney(debt.principalCents)}'),
              ],
            ),
            style: style,
          ),
        ),
        if (trailing case final trailing?) Text(trailing, style: CarliType.small.copyWith(color: colors.text3)),
      ],
    );
  }
}

class _SharedCard extends ConsumerWidget {
  const _SharedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final contacts = ref.watch(contactOptionsProvider).value;
    final top = [
      for (final contact in contacts ?? const <ContactOption>[])
        if (contact.balanceCents != 0) contact,
    ]..sort((left, right) => right.balanceCents.abs().compareTo(left.balanceCents.abs()));
    void open(String path) => GoRouter.maybeOf(context)?.push(path);

    return CarliCard(
      padding: const EdgeInsets.only(bottom: CarliSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            'Gastos compartidos',
            action: TextButton(onPressed: () => open(Routes.shared), child: const Text('Ver todo')),
          ),
          if (contacts != null && top.isEmpty)
            CarliEmptyState(
              icon: carliIconNamed('users'),
              title: 'Nadie con saldo',
              message: 'Reparte un gasto con un contacto y verás aquí quién te debe.',
              actionLabel: 'Contactos',
              onAction: () => open(Routes.shared),
            )
          else
            for (final contact in top.take(5))
              CarliListItem(
                title: contact.name,
                leading: CarliAvatar(name: contact.name),
                trailing: Text(
                  contactBalanceLabel(contact.balanceCents),
                  style: CarliType.money(CarliType.body).copyWith(
                    fontWeight: FontWeight.w600,
                    color: contact.balanceCents > 0 ? colors.positive : colors.text,
                  ),
                ),
                onTap: () => open(Routes.contact(contact.id)),
              ),
        ],
      ),
    );
  }
}

class _DebtsSkeleton extends StatelessWidget {
  const _DebtsSkeleton();

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
        CarliCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CarliSpace.s12,
            children: [
              CarliSkeleton(width: 180),
              CarliSkeleton(height: 8, radius: CarliRadius.full),
              CarliSkeleton(width: 140),
              CarliSkeleton(height: 8, radius: CarliRadius.full),
            ],
          ),
        ),
      ],
    );
  }
}
