import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';
import '../../../../core/router/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/avatar.dart';
import '../../../../ui/badge.dart';
import '../../../../ui/button.dart';
import '../../../../ui/card.dart';
import '../../../../ui/empty_state.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/list_item.dart';
import '../../../../ui/page.dart';
import '../../../../ui/skeleton.dart';
import '../../data/contacts.dart';
import '../../data/finance_changes.dart';
import 'contact_sheets.dart';

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final String contactId;

  Future<void> _edit(BuildContext context, FinanceContactDetail detail) async {
    final result = await showContactSheet(context, detail: detail);
    if (result == ContactSheetResult.deleted && context.mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(contactDetailProvider(contactId));
    final current = detail.value;
    return CarliPage(
      title: current?.contact.name ?? 'Contacto',
      trailing: current == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: CarliSpace.s8,
              children: [
                CarliButton.icon(
                  icon: carliIconNamed('pencil'),
                  semanticLabel: 'Editar contacto',
                  size: CarliButtonSize.sm,
                  onPressed: () => _edit(context, current),
                ),
                if (current.contact.sharesPendingCents > 0)
                  CarliButton.icon(
                    icon: carliIconNamed('check'),
                    semanticLabel: 'Liquidar',
                    variant: CarliButtonVariant.primary,
                    size: CarliButtonSize.sm,
                    onPressed: () => showSettleSheet(context, current.contact),
                  ),
              ],
            ),
      onRefresh: () async {
        ref.read(financeChangesProvider.notifier).notify(const [FinanceScope.contacts]);
        await ref.read(contactDetailProvider(contactId).future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: switch (detail) {
              AsyncValue(hasValue: true, :final value?) => _DetailBody(detail: value),
              AsyncValue(hasError: true) => CarliCard(
                child: CarliEmptyState(
                  icon: carliIconNamed('circle-alert'),
                  title: 'No encontramos este contacto',
                  message: 'Puede que se haya eliminado.',
                  actionLabel: 'Volver a compartidos',
                  onAction: () =>
                      GoRouter.maybeOf(context) == null ? Navigator.of(context).maybePop() : context.go(Routes.shared),
                ),
              ),
              _ => const CarliCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: CarliSpace.s12,
                  children: [CarliSkeleton(width: 140, height: 42), CarliSkeleton(width: 220)],
                ),
              ),
            },
          ),
        ),
      ],
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final FinanceContactDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final contact = detail.contact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s12,
      children: [
        CarliCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: CarliSpace.s16,
                children: [
                  CarliAvatar(name: contact.name, size: 48),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saldo', style: CarliType.caption.copyWith(color: colors.text2)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            contactBalanceLabel(contact.balanceCents),
                            style: CarliType.display
                                .copyWith(fontSize: 28, height: 34 / 28)
                                .copyWith(color: contact.balanceCents > 0 ? colors.positive : colors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (contact.archived) CarliBadge('Archivado', icon: carliIconNamed('archive')),
                ],
              ),
              const SizedBox(height: CarliSpace.s16),
              Divider(height: 1, color: colors.border),
              const SizedBox(height: CarliSpace.s12),
              _BreakdownLine(label: 'Gastos compartidos sin liquidar', cents: contact.sharesPendingCents),
              if (contact.owedToMeCents > 0)
                _BreakdownLine(label: 'Préstamos que te debe', cents: contact.owedToMeCents),
              if (contact.iOweCents > 0) _BreakdownLine(label: 'Préstamos que le debes', cents: contact.iOweCents),
              if (contact.notes case final notes? when notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: CarliSpace.s12),
                  child: Text(notes, style: CarliType.small.copyWith(color: colors.text2)),
                ),
            ],
          ),
        ),
        _ListCard(
          title: 'Gastos compartidos',
          children: detail.shares.isEmpty
              ? [
                  CarliEmptyState(
                    icon: carliIconNamed('users'),
                    title: 'Sin gastos compartidos',
                    message: 'Al registrar un gasto, actívale “Gasto compartido” y elige a ${contact.name}.',
                  ),
                ]
              : [for (final share in detail.shares) _ShareRow(share: share)],
        ),
        if (detail.debts.isNotEmpty)
          _ListCard(
            title: 'Préstamos',
            action: CarliButton(
              label: 'Deudas',
              icon: carliIconNamed('chevron-right'),
              variant: CarliButtonVariant.ghost,
              size: CarliButtonSize.sm,
              block: false,
              onPressed: () => context.push(Routes.debts),
            ),
            children: [for (final debt in detail.debts) _DebtRow(debt: debt)],
          ),
      ],
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: CarliType.small.copyWith(color: colors.text2)),
          ),
          Text(formatMoney(cents), style: CarliType.money(CarliType.small).copyWith(color: colors.text)),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CarliCard(
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
                    child: Text(title, style: CarliType.h2.copyWith(color: colors.text)),
                  ),
                ),
                ?action,
              ],
            ),
          ),
          for (final (index, child) in children.indexed) ...[
            if (index > 0) Divider(indent: 68, color: colors.border),
            child,
          ],
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.share});

  final ContactShare share;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle =
        '${formatRelativeDay(share.date, style: RelativeDateStyle.title)} · total ${formatMoney(share.transactionAmountCents.abs())}';
    final amount = formatMoney(share.amountCents, display: MoneyDisplay.signed);
    final status = share.settled ? 'Liquidado' : 'Pendiente';
    return Semantics(
      container: true,
      label: '${share.title}, $amount, $status, $subtitle',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
        child: Row(
          spacing: CarliSpace.s12,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
              child: CarliIcon(carliIconNamed(share.settled ? 'check' : 'receipt'), size: 20, color: colors.text),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    share.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CarliType.body.copyWith(fontWeight: FontWeight.w500, color: colors.text),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CarliType.small.copyWith(color: colors.text2),
                  ),
                  CarliBadge(status, icon: carliIconNamed(share.settled ? 'check' : 'clock')),
                ],
              ),
            ),
            Text(
              amount,
              style: CarliType.money(CarliType.body)
                  .copyWith(fontWeight: FontWeight.w600, color: share.settled ? colors.text2 : colors.positive),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt});

  final ContactDebt debt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = [
      debt.direction.label,
      if (debt.closed) 'saldada' else if (debt.dueDate case final due?) 'vence ${formatShortDate(due)}',
    ].join(' · ');
    final color = debt.closed
        ? colors.text2
        : (debt.direction == DebtDirection.owedToMe ? colors.positive : colors.text);
    return CarliListItem(
      title: debt.name,
      subtitle: subtitle,
      icon: carliIconNamed(debt.direction == DebtDirection.iOwe ? 'arrow-up-right' : 'arrow-down-left'),
      trailing: Text(
        formatMoney(debt.pendingCents),
        style: CarliType.money(CarliType.body).copyWith(fontWeight: FontWeight.w600, color: color),
      ),
      onTap: () => context.push(Routes.debts),
    );
  }
}
