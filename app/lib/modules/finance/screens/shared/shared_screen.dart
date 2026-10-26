import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/money.dart';
import '../../../../core/router/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/async_view.dart';
import '../../../../ui/avatar.dart';
import '../../../../ui/button.dart';
import '../../../../ui/card.dart';
import '../../../../ui/empty_state.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/page.dart';
import '../../../../ui/pressable.dart';
import '../../../../ui/skeleton.dart';
import '../../../../ui/stat.dart';
import '../../data/contacts.dart';
import '../../data/finance_changes.dart';
import 'contact_sheets.dart';

class SharedScreen extends ConsumerWidget {
  const SharedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(contactsProvider);
    return CarliPage(
      title: 'Compartidos',
      trailing: CarliButton.icon(
        icon: carliIconNamed('user-plus'),
        semanticLabel: 'Nuevo contacto',
        size: CarliButtonSize.sm,
        onPressed: () => showContactSheet(context),
      ),
      onRefresh: () async {
        ref.read(financeChangesProvider.notifier).notify(const [FinanceScope.contacts]);
        await ref.read(contactsProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: overview,
              errorTitle: 'No se han podido cargar los contactos',
              onRetry: () => ref.invalidate(contactsProvider),
              loading: const _SharedSkeleton(),
              data: (data) => _SharedBody(data: data),
            ),
          ),
        ),
      ],
    );
  }
}

class _SharedBody extends StatelessWidget {
  const _SharedBody({required this.data});

  final ContactsOverview data;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                  label: 'Te deben',
                  icon: carliIconNamed('arrow-down-left'),
                  value: formatMoney(data.owedToMeCents),
                  tone: CarliTone.positive,
                  delta: peopleLabel(data.owingMeCount),
                ),
              ),
              Expanded(
                child: CarliStat(
                  label: 'Debes',
                  icon: carliIconNamed('arrow-up-right'),
                  value: formatMoney(data.iOweCents),
                  delta: peopleLabel(data.owedByMeCount),
                ),
              ),
            ],
          ),
        ),
        CarliCard(
          padding: const EdgeInsets.only(bottom: CarliSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, CarliSpace.s8),
                child: Semantics(
                  header: true,
                  child: Text('Gastos compartidos', style: CarliType.h2.copyWith(color: colors.text)),
                ),
              ),
              if (data.contacts.isEmpty)
                CarliEmptyState(
                  icon: carliIconNamed('users'),
                  title: 'Aún no compartes gastos',
                  message: 'Añade a las personas con las que compartes gastos. Al registrar un gasto podrás repartirlo con ellas.',
                  actionLabel: 'Nuevo contacto',
                  onAction: () => showContactSheet(context),
                )
              else
                for (final (index, contact) in data.contacts.indexed) ...[
                  if (index > 0) Divider(indent: 64, color: colors.border),
                  ContactRow(contact: contact),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class ContactRow extends StatelessWidget {
  const ContactRow({super.key, required this.contact});

  final FinanceContact contact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final balance = contactBalanceLabel(contact.balanceCents);
    final subtitle = contactSubtitle(contact);
    final balanceColor = switch (contact.balanceCents) {
      > 0 => colors.positive,
      0 => colors.text2,
      _ => colors.text,
    };
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: '${contact.name}, $balance, $subtitle',
            excludeSemantics: true,
            child: Pressable(
              onTap: () => context.push(Routes.contact(contact.id)),
              pressedOpacity: 0.5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
                child: Row(
                  spacing: CarliSpace.s12,
                  children: [
                    CarliAvatar(name: contact.name),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CarliType.body.copyWith(fontWeight: FontWeight.w500, color: colors.text),
                          ),
                          Text(subtitle, style: CarliType.small.copyWith(color: colors.text2)),
                        ],
                      ),
                    ),
                    Text(
                      balance,
                      style: CarliType.money(CarliType.body).copyWith(fontWeight: FontWeight.w600, color: balanceColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (contact.sharesPendingCents > 0)
          Padding(
            padding: const EdgeInsets.only(right: CarliSpace.s12),
            child: Semantics(
              label: 'Liquidar con ${contact.name}',
              button: true,
              excludeSemantics: true,
              child: CarliButton(
                label: 'Liquidar',
                variant: CarliButtonVariant.ghost,
                size: CarliButtonSize.sm,
                block: false,
                onPressed: () => showSettleSheet(context, contact),
              ),
            ),
          ),
      ],
    );
  }
}

class _SharedSkeleton extends StatelessWidget {
  const _SharedSkeleton();

  @override
  Widget build(BuildContext context) {
    const stat = CarliCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CarliSpace.s8,
        children: [CarliSkeleton(width: 90, height: 13), CarliSkeleton(width: 120, height: 28)],
      ),
    );
    return Column(
      spacing: CarliSpace.s12,
      children: [
        const Row(
          spacing: CarliSpace.s12,
          children: [
            Expanded(child: stat),
            Expanded(child: stat),
          ],
        ),
        CarliCard(
          child: Column(
            spacing: CarliSpace.s16,
            children: [
              for (var i = 0; i < 3; i++)
                const Row(
                  spacing: CarliSpace.s12,
                  children: [
                    CarliSkeleton.circle(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: CarliSpace.s8,
                        children: [CarliSkeleton(width: 120), CarliSkeleton(width: 180, height: 12)],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
