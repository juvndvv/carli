import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';
import '../../../../core/router/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/badge.dart';
import '../../../../ui/button.dart';
import '../../../../ui/card.dart';
import '../../../../ui/empty_state.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/list_item.dart';
import '../../../../ui/page.dart';
import '../../../../ui/progress.dart';
import '../../../../ui/skeleton.dart';
import '../../../../ui/stat.dart';
import '../../../../ui/toast.dart';
import '../../data/goals.dart';
import 'contribution_sheet.dart';
import 'goal_sheet.dart';
import 'goals_screen.dart';

String goalRemainingLabel(SavingsGoal goal) =>
    goal.remainingCents == 0 ? 'Nada, ¡lo tienes!' : formatMoney(goal.remainingCents);

String goalMonthlyLabel(SavingsGoal goal) {
  if (goal.achieved || goal.remainingCents == 0) return '—';
  final monthly = goal.monthlyNeededCents;
  return monthly != null && monthly > 0 ? '${formatMoney(monthly)}/mes' : 'Sin fecha límite';
}

String? goalMonthsLeftLabel(SavingsGoal goal) {
  final months = goal.monthsLeft;
  if (months == null || goal.achieved) return null;
  return months == 1 ? 'Durante 1 mes' : 'Durante $months meses';
}

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  void _backToGoals(BuildContext context) => GoRouter.maybeOf(context)?.go(Routes.goals);

  Future<void> _edit(BuildContext context, SavingsGoal goal) async {
    final outcome = await showGoalSheet(context, goal: goal);
    if (outcome == GoalSheetOutcome.deleted && context.mounted) _backToGoals(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(goalProvider(goalId));
    final current = goal.value;

    return CarliPage(
      title: current?.name ?? 'Objetivo',
      trailing: current == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: CarliSpace.s8,
              children: [
                CarliButton.icon(
                  icon: carliIconNamed('pencil'),
                  semanticLabel: 'Editar objetivo',
                  size: CarliButtonSize.sm,
                  onPressed: () => _edit(context, current),
                ),
                if (current.accountId == null)
                  CarliButton.icon(
                    icon: carliIconNamed('plus'),
                    semanticLabel: 'Aportar',
                    variant: CarliButtonVariant.primary,
                    size: CarliButtonSize.sm,
                    onPressed: () => showContributionSheet(context, current),
                  ),
              ],
            ),
      onRefresh: () async {
        ref.invalidate(goalProvider(goalId));
        ref.invalidate(goalContributionsProvider(goalId));
        await ref.read(goalProvider(goalId).future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: switch (goal) {
              AsyncValue(hasValue: true, :final value?) => _GoalBody(goal: value),
              AsyncValue(hasError: true) => CarliCard(
                child: CarliEmptyState(
                  icon: carliIconNamed('circle-alert'),
                  title: 'No encontramos este objetivo',
                  message: 'Puede que se haya eliminado.',
                  actionLabel: 'Volver a objetivos',
                  onAction: () => _backToGoals(context),
                ),
              ),
              _ => const CarliCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: CarliSpace.s12,
                  children: [
                    CarliSkeleton(width: 160, height: 42),
                    CarliSkeleton(height: 8, radius: CarliRadius.full),
                    CarliSkeleton(width: 220),
                  ],
                ),
              ),
            },
          ),
        ),
      ],
    );
  }
}

class _GoalBody extends StatelessWidget {
  const _GoalBody({required this.goal});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final account = goal.account;
    final targetDate = goal.targetDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s12,
      children: [
        CarliCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: CarliSpace.s8,
                children: [
                  GoalIconBubble(icon: goal.iconName),
                  Expanded(
                    child: Text(
                      account == null ? 'Ahorrado' : 'Saldo de ${account.name}',
                      style: CarliType.caption.copyWith(color: colors.text2),
                    ),
                  ),
                  CarliBadge(
                    goal.achieved ? 'Conseguido' : '${goal.percent} %',
                    tone: goal.achieved ? CarliBadgeTone.positive : CarliBadgeTone.neutral,
                    icon: goal.achieved ? carliIconNamed('check') : null,
                  ),
                ],
              ),
              const SizedBox(height: CarliSpace.s12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: CarliSpace.s8,
                children: [
                  Text(formatMoney(goal.savedCents), style: CarliType.display.copyWith(color: colors.text)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'de ${formatMoney(goal.targetCents)}',
                      style: CarliType.money(CarliType.body).copyWith(color: colors.text2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CarliSpace.s12),
              CarliProgress(ratio: goal.ratio, tone: ProgressTone.goal, label: 'Progreso de ${goal.name}'),
              if (account != null) ...[
                const SizedBox(height: CarliSpace.s12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: CarliSpace.s4,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: CarliIcon(carliIconNamed('link'), size: 13, color: colors.text3),
                    ),
                    Expanded(
                      child: Text(
                        'El progreso es el saldo de ${account.name}. Para aportar, haz una transferencia a esa cuenta.',
                        style: CarliType.small.copyWith(color: colors.text3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CarliSpace.s12),
                CarliButton(
                  label: 'Ver cuenta',
                  icon: carliIconNamed('landmark'),
                  variant: CarliButtonVariant.secondary,
                  size: CarliButtonSize.sm,
                  block: false,
                  onPressed: () => GoRouter.maybeOf(context)?.push(Routes.account(account.id)),
                ),
              ],
            ],
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: CarliSpace.s12,
            children: [
              Expanded(
                child: CarliStat(
                  label: 'Te falta',
                  icon: carliIconNamed('target'),
                  value: goalRemainingLabel(goal),
                  tone: goal.achieved ? CarliTone.positive : CarliTone.normal,
                ),
              ),
              Expanded(
                child: CarliStat(
                  label: 'Aportación mensual',
                  icon: carliIconNamed('calendar'),
                  value: goalMonthlyLabel(goal),
                  delta: goalMonthsLeftLabel(goal),
                ),
              ),
            ],
          ),
        ),
        CarliStat(
          label: 'Fecha objetivo',
          icon: carliIconNamed('calendar-days'),
          value: goalTargetMonthLabel(targetDate) ?? 'Sin fecha',
          delta: targetDate == null ? 'Ahorra a tu ritmo' : formatShortDate(targetDate, withYear: true),
        ),
        if (goal.accountId == null) _ContributionsCard(goal: goal),
      ],
    );
  }
}

class _ContributionsCard extends ConsumerWidget {
  const _ContributionsCard({required this.goal});

  final SavingsGoal goal;

  Future<void> _remove(WidgetRef ref, GoalContribution item) async {
    final repository = ref.read(goalsRepositoryProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      await repository.removeContribution(goal.id, item.id);
      toasts.withUndo('Aportación borrada', () async {
        try {
          await repository.contribute(goal.id, item.toPayload());
        } catch (error) {
          toasts.error(apiErrorMessage(error, fallback: 'No se ha podido registrar la aportación.'));
        }
      });
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido borrar la aportación.'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final contributions = ref.watch(goalContributionsProvider(goal.id));
    final items = contributions.value ?? const <GoalContribution>[];

    return CarliCard(
      padding: const EdgeInsets.only(bottom: CarliSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, CarliSpace.s8),
            child: Semantics(
              header: true,
              child: Text('Aportaciones', style: CarliType.h2.copyWith(color: colors.text)),
            ),
          ),
          if (contributions.isLoading && items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
              child: CarliSkeleton(),
            )
          else if (items.isEmpty)
            CarliEmptyState(
              icon: carliIconNamed('piggy-bank'),
              title: 'Sin aportaciones todavía',
              message: 'Cada vez que apartes dinero para este objetivo, regístralo aquí.',
              actionLabel: 'Aportar',
              onAction: () => showContributionSheet(context, goal),
            )
          else
            for (final (index, item) in items.indexed) ...[
              if (index > 0) Divider(indent: 68, color: colors.border),
              CarliListItem(
                title: item.note ?? (item.amountCents > 0 ? 'Aportación' : 'Retirada'),
                subtitle: formatRelativeDay(item.date, style: RelativeDateStyle.title),
                icon: carliIconNamed(item.amountCents > 0 ? 'plus' : 'minus'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: CarliSpace.s4,
                  children: [
                    Text(
                      formatMoney(item.amountCents, display: MoneyDisplay.signed),
                      style: CarliType.money(CarliType.body).copyWith(
                        fontWeight: FontWeight.w600,
                        color: item.amountCents > 0 ? colors.positive : colors.text,
                      ),
                    ),
                    CarliButton.icon(
                      icon: carliIconNamed('trash'),
                      semanticLabel: 'Borrar aportación del ${formatShortDate(item.date)}',
                      size: CarliButtonSize.sm,
                      onPressed: () => _remove(ref, item),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
