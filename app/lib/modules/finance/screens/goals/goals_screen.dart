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
import '../../../../ui/progress.dart';
import '../../../../ui/skeleton.dart';
import '../../data/goals.dart';
import 'contribution_sheet.dart';
import 'goal_sheet.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    return CarliPage(
      title: 'Objetivos de ahorro',
      trailing: CarliButton.icon(
        icon: carliIconNamed('plus'),
        semanticLabel: 'Nuevo objetivo',
        size: CarliButtonSize.sm,
        onPressed: () => showGoalSheet(context),
      ),
      onRefresh: () async {
        ref.invalidate(goalsProvider);
        await ref.read(goalsProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: goals,
              errorTitle: 'No se han podido cargar los objetivos',
              onRetry: () => ref.invalidate(goalsProvider),
              loading: const _GoalsSkeleton(),
              data: (goals) => goals.isEmpty
                  ? CarliCard(
                      child: CarliEmptyState(
                        icon: carliIconNamed('target'),
                        title: 'Aún no tienes objetivos',
                        message:
                            'Ponle nombre y cifra a lo que quieres conseguir y te diremos cuánto apartar cada mes.',
                        actionLabel: 'Nuevo objetivo',
                        onAction: () => showGoalSheet(context),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: CarliSpace.s12,
                      children: [for (final goal in goals) GoalCard(goal: goal)],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class GoalIconBubble extends StatelessWidget {
  const GoalIconBubble({super.key, required this.icon});

  final String icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
      child: CarliIcon(carliIconNamed(icon), size: 18, color: colors.text),
    );
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final account = goal.account;
    final monthly = goal.monthlyNeededCents;
    final meta = goal.achieved
        ? const TextSpan(text: 'Objetivo conseguido')
        : goal.targetDate != null
        ? TextSpan(
            text: 'Meta: ${goalTargetMonthLabel(goal.targetDate)}',
            children: [
              if (monthly != null && monthly > 0) ...[
                const TextSpan(text: ' · aporta '),
                TextSpan(
                  text: '${formatMoney(monthly)}/mes',
                  style: CarliType.money(CarliType.small).copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
              ],
            ],
          )
        : const TextSpan(text: 'Sin fecha límite');

    return CarliCard(
      onTap: () => GoRouter.maybeOf(context)?.push(Routes.goal(goal.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GoalIconBubble(icon: goal.iconName),
              const Spacer(),
              CarliBadge(
                '${goal.percent} %',
                tone: goal.achieved ? CarliBadgeTone.positive : CarliBadgeTone.neutral,
                icon: goal.achieved ? carliIconNamed('check') : null,
              ),
            ],
          ),
          const SizedBox(height: CarliSpace.s12),
          Semantics(
            header: true,
            child: Text(goal.name, style: CarliType.h2.copyWith(color: colors.text)),
          ),
          const SizedBox(height: CarliSpace.s4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(
                formatMoney(goal.savedCents),
                style: CarliType.money(CarliType.h2)
                    .copyWith(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600, color: colors.text),
              ),
              Text(
                'de ${formatMoney(goal.targetCents)}',
                style: CarliType.money(CarliType.small).copyWith(color: colors.text2),
              ),
            ],
          ),
          const SizedBox(height: CarliSpace.s12),
          CarliProgress(ratio: goal.ratio, tone: ProgressTone.goal, label: 'Progreso de ${goal.name}'),
          const SizedBox(height: CarliSpace.s8),
          Text.rich(meta, style: CarliType.small.copyWith(color: colors.text2)),
          if (account != null) ...[
            const SizedBox(height: CarliSpace.s4),
            Row(
              spacing: CarliSpace.s4,
              children: [
                CarliIcon(carliIconNamed('link'), size: 13, color: colors.text3),
                Flexible(
                  child: Text(
                    'Vinculado a la cuenta ${account.name}',
                    style: CarliType.small.copyWith(color: colors.text3),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: CarliSpace.s12),
          if (account != null)
            CarliButton(
              label: 'Ver cuenta',
              icon: carliIconNamed('landmark'),
              variant: CarliButtonVariant.secondary,
              size: CarliButtonSize.sm,
              block: false,
              onPressed: () => GoRouter.maybeOf(context)?.push(Routes.account(account.id)),
            )
          else
            CarliButton(
              label: 'Aportar',
              icon: carliIconNamed('plus'),
              variant: CarliButtonVariant.secondary,
              size: CarliButtonSize.sm,
              block: false,
              onPressed: () => showContributionSheet(context, goal),
            ),
        ],
      ),
    );
  }
}

class _GoalsSkeleton extends StatelessWidget {
  const _GoalsSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    spacing: CarliSpace.s12,
    children: [
      for (var index = 0; index < 3; index++)
        const CarliCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CarliSpace.s12,
            children: [
              CarliSkeleton.circle(),
              CarliSkeleton(width: 180, height: 20),
              CarliSkeleton(height: 8, radius: CarliRadius.full),
            ],
          ),
        ),
    ],
  );
}
