import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/format/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/async_view.dart';
import '../../../../ui/badge.dart';
import '../../../../ui/button.dart';
import '../../../../ui/card.dart';
import '../../../../ui/empty_state.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/list_item.dart';
import '../../../../ui/page.dart';
import '../../../../ui/pressable.dart';
import '../../../../ui/sheet.dart';
import '../../../../ui/skeleton.dart';
import '../../../../ui/stat.dart';
import '../../../../ui/tabs.dart';
import '../../../../ui/toast.dart';
import '../../data/recurring.dart';
import '../../data/finance_providers.dart';
import 'confirm_occurrence_sheet.dart';
import 'recurring_rule_sheet.dart';

const _emptyCopy = {
  RecurringTab.all: (
    'Aún no tienes recurrentes',
    'Añade el alquiler, la nómina o tus suscripciones y te avisaremos antes de cada cargo.',
  ),
  RecurringTab.subscriptions: (
    'Sin suscripciones',
    'Marca un recurrente como suscripción para ver aquí cuánto te cuestan al mes y al año.',
  ),
  RecurringTab.pending: (
    'Nada pendiente de confirmar',
    'Los cargos con confirmación aparecerán aquí el día que toquen.',
  ),
  RecurringTab.cancelled: (
    'Sin suscripciones canceladas',
    'Cuando canceles un recurrente lo verás aquí y podrás reactivarlo.',
  ),
};

enum _RuleAction { edit, confirm, cancel, reactivate }

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  var _tab = RecurringTab.all;

  void _create() => showRecurringRuleSheet(context, isSubscription: _tab == RecurringTab.subscriptions);

  void _edit(RecurringRule rule) => showRecurringRuleSheet(context, rule: rule);

  void _confirm(RecurringRule rule) => showConfirmOccurrenceSheet(context, rule: rule);

  Future<void> _setCancelled(RecurringRule rule, bool cancelled) async {
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      await ref.read(recurringRepositoryProvider).setCancelled(rule.id, cancelled);
      if (cancelled) {
        toasts.withUndo('${rule.name} cancelada', () => _setCancelled(rule, false));
      } else {
        toasts.show('${rule.name} reactivada');
      }
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido actualizar el recurrente.'));
    }
  }

  Future<void> _openActions(RecurringRule rule) async {
    final canConfirm = !rule.cancelled && (rule.pendingTransaction != null || rule.nextOccurrence != null);
    final actions = [
      (_RuleAction.edit, 'Editar', 'pencil'),
      if (canConfirm)
        (
          _RuleAction.confirm,
          rule.pendingTransaction != null ? 'Confirmar cargo pendiente' : 'Registrar el próximo cargo ya',
          'check',
        ),
      if (rule.cancelled)
        (_RuleAction.reactivate, 'Reactivar', 'rotate-ccw')
      else
        (_RuleAction.cancel, rule.isSubscription ? 'Cancelar suscripción' : 'Cancelar recurrente', 'circle-x'),
    ];
    final picked = await showCarliSheet<_RuleAction>(
      context,
      title: rule.name,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: CarliSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (action, label, icon) in actions)
              _ActionRow(
                label: label,
                icon: icon,
                destructive: action == _RuleAction.cancel,
                onTap: () => Navigator.pop(context, action),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (picked) {
      case _RuleAction.edit:
        _edit(rule);
      case _RuleAction.confirm:
        _confirm(rule);
      case _RuleAction.cancel:
        await _setCancelled(rule, true);
      case _RuleAction.reactivate:
        await _setCancelled(rule, false);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(recurringRulesProvider);
    final pending = rules.value?.pendingCount ?? 0;

    return CarliPage(
      title: 'Recurrentes',
      trailing: CarliButton.icon(icon: carliIconNamed('plus'), semanticLabel: 'Nuevo recurrente', onPressed: _create),
      onRefresh: () async {
        ref.invalidate(recurringRulesProvider);
        ref.invalidate(financeSettingsProvider);
        await ref.read(recurringRulesProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s12),
          sliver: SliverToBoxAdapter(
            child: CarliTabs<RecurringTab>(
              tabs: [
                for (final tab in RecurringTab.values)
                  (tab, tab == RecurringTab.pending && pending > 0 ? '${tab.label} ($pending)' : tab.label),
              ],
              value: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: rules,
              errorTitle: 'No se han podido cargar',
              onRetry: () => ref.invalidate(recurringRulesProvider),
              loading: const _RecurringSkeleton(),
              data: (data) => _RecurringBody(
                data: data,
                tab: _tab,
                onCreate: _create,
                onEdit: _edit,
                onConfirm: _confirm,
                onActions: _openActions,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecurringBody extends ConsumerWidget {
  const _RecurringBody({
    required this.data,
    required this.tab,
    required this.onCreate,
    required this.onEdit,
    required this.onConfirm,
    required this.onActions,
  });

  final RecurringRules data;
  final RecurringTab tab;
  final VoidCallback onCreate;
  final ValueChanged<RecurringRule> onEdit;
  final ValueChanged<RecurringRule> onConfirm;
  final ValueChanged<RecurringRule> onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final reminder = ref.watch(recurringReminderDaysProvider).value;
    final visible = filterRecurringRules(data.rules, tab);
    final upcoming = tab == RecurringTab.subscriptions
        ? upcomingCharges(data.subscriptions, DateTime.now(), 30).take(5).toList()
        : const <RecurringRule>[];
    final (emptyTitle, emptyMessage) = _emptyCopy[tab]!;
    final canCreate = tab == RecurringTab.all || tab == RecurringTab.subscriptions;

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
                  label: 'Suscripciones al mes',
                  icon: carliIconNamed('repeat'),
                  value: formatMoney(data.meta.subscriptionsMonthlyCents),
                  delta: subscriptionsCountLabel(data.meta.subscriptionsCount),
                ),
              ),
              Expanded(
                child: CarliStat(
                  label: 'Al año',
                  icon: carliIconNamed('calendar'),
                  value: formatMoney(data.meta.subscriptionsYearlyCents),
                ),
              ),
            ],
          ),
        ),
        CarliStat(
          label: 'Aviso',
          icon: carliIconNamed('bell'),
          value: reminder == null ? '—' : reminderLabel(reminder),
          delta: 'Notificación push a las 09:00',
        ),
        if (upcoming.isNotEmpty)
          CarliCard(
            padding: const EdgeInsets.only(bottom: CarliSpace.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, CarliSpace.s8),
                  child: Semantics(
                    header: true,
                    child: Text('Próximos cargos', style: CarliType.h2.copyWith(color: colors.text)),
                  ),
                ),
                for (final (index, rule) in upcoming.indexed) ...[
                  if (index > 0) Divider(indent: 68, color: colors.border),
                  CarliListItem(
                    title: rule.name,
                    subtitle: upcomingChargeLabel(rule),
                    icon: carliIconNamed(recurringIconName(rule)),
                    trailing: _Amount(rule: rule),
                  ),
                ],
              ],
            ),
          ),
        CarliCard(
          padding: const EdgeInsets.symmetric(vertical: CarliSpace.s4),
          child: visible.isEmpty
              ? CarliEmptyState(
                  icon: carliIconNamed('repeat'),
                  title: emptyTitle,
                  message: emptyMessage,
                  actionLabel: canCreate ? 'Nuevo recurrente' : null,
                  onAction: canCreate ? onCreate : null,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, rule) in visible.indexed) ...[
                      if (index > 0) Divider(indent: 68, color: colors.border),
                      _RuleRow(
                        rule: rule,
                        onTap: () => onEdit(rule),
                        onConfirm: () => onConfirm(rule),
                        onActions: () => onActions(rule),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.rule});

  final RecurringRule rule;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      formatMoney(rule.amountCents, display: MoneyDisplay.signed),
      style: CarliType.money(CarliType.body).copyWith(
        fontWeight: FontWeight.w600,
        color: rule.cancelled ? colors.text3 : (rule.amountCents > 0 ? colors.positive : colors.text),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.onTap, required this.onConfirm, required this.onActions});

  final RecurringRule rule;
  final VoidCallback onTap;
  final VoidCallback onConfirm;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final badges = [
      if (rule.isSubscription) const CarliBadge('Suscripción'),
      if (rule.pendingTransaction != null)
        CarliBadge('Pendiente', tone: CarliBadgeTone.warning, icon: carliIconNamed('clock')),
      if (rule.cancelled) CarliBadge('Cancelada', icon: carliIconNamed('circle-x')),
      if (rule.debtId != null) CarliBadge('Préstamo', icon: carliIconNamed('hand-coins')),
    ];
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        pressedOpacity: 0.5,
        child: Padding(
          padding: const EdgeInsets.only(left: CarliSpace.s16, right: CarliSpace.s8, top: 10, bottom: 10),
          child: Row(
            spacing: CarliSpace.s12,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
                child: CarliIcon(carliIconNamed(recurringIconName(rule)), size: 20, color: colors.text),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      rule.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.body.copyWith(fontWeight: FontWeight.w500, color: colors.text),
                    ),
                    Text(
                      recurringSubtitle(rule),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.small.copyWith(color: colors.text2),
                    ),
                    if (badges.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: CarliSpace.s4),
                        child: Wrap(spacing: CarliSpace.s4, runSpacing: CarliSpace.s4, children: badges),
                      ),
                  ],
                ),
              ),
              _Amount(rule: rule),
              if (rule.pendingTransaction != null)
                CarliButton.icon(
                  icon: carliIconNamed('check'),
                  semanticLabel: 'Confirmar cargo de ${rule.name}',
                  variant: CarliButtonVariant.secondary,
                  size: CarliButtonSize.sm,
                  onPressed: onConfirm,
                ),
              CarliButton.icon(
                icon: carliIconNamed('ellipsis'),
                semanticLabel: 'Acciones de ${rule.name}',
                size: CarliButtonSize.sm,
                onPressed: onActions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, required this.icon, required this.onTap, this.destructive = false});

  final String label;
  final String icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = destructive ? colors.negative : colors.text;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s20, vertical: 14),
          child: Row(
            spacing: CarliSpace.s12,
            children: [
              CarliIcon(carliIconNamed(icon), size: 20, color: destructive ? colors.negative : colors.text2),
              Expanded(
                child: Text(label, style: CarliType.body.copyWith(color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringSkeleton extends StatelessWidget {
  const _RecurringSkeleton();

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
              for (var row = 0; row < 4; row++)
                const Row(
                  spacing: CarliSpace.s12,
                  children: [
                    CarliSkeleton.circle(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [CarliSkeleton(width: 140, height: 14), CarliSkeleton(width: 90, height: 12)],
                      ),
                    ),
                    CarliSkeleton(width: 72, height: 14),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
