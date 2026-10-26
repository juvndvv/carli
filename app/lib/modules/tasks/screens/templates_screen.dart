import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../data/quick_dates.dart';
import '../data/tasks_models.dart';
import '../data/tasks_providers.dart';
import '../ui/task_group.dart';
import '../ui/tasks_routes.dart';
import '../ui/tasks_skeleton.dart';

String templateRule(TaskTemplate template) => [
  template.frequencyText,
  ?template.dueTime,
  if (template.leadDays > 0) template.leadDays == 1 ? 'aparece 1 día antes' : 'aparece ${template.leadDays} días antes',
].join(' · ');

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(taskTemplatesProvider);
    final colors = context.colors;
    return CarliPage(
      title: 'Plantillas',
      trailing: CarliButton.icon(
        icon: carliIconNamed('plus'),
        semanticLabel: 'Nueva plantilla',
        size: CarliButtonSize.sm,
        onPressed: () => context.push(TasksRoutes.newTemplate),
      ),
      onRefresh: () async {
        ref.invalidate(taskTemplatesProvider);
        await ref.read(taskTemplatesProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: AsyncView(
              value: templates,
              errorTitle: 'No se han podido cargar las plantillas',
              onRetry: () => ref.invalidate(taskTemplatesProvider),
              loading: const TasksSkeleton(),
              data: (templates) {
                if (templates.isEmpty) {
                  return CarliCard(
                    child: CarliEmptyState(
                      icon: carliIconNamed('repeat'),
                      title: 'Sin plantillas',
                      message:
                          'Crea una para lo que se repite: sacar la basura, regar las plantas o pagar la comunidad.',
                      actionLabel: 'Nueva plantilla',
                      onAction: () => context.push(TasksRoutes.newTemplate),
                    ),
                  );
                }
                final active = templates.where((template) => !template.paused).toList();
                final paused = templates.where((template) => template.paused).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: CarliSpace.s20,
                  children: [
                    Text(
                      [
                        active.length == 1 ? '1 activa' : '${active.length} activas',
                        if (paused.isNotEmpty) paused.length == 1 ? '1 pausada' : '${paused.length} pausadas',
                      ].join(' · '),
                      style: CarliType.small.copyWith(color: colors.text2),
                    ),
                    if (active.isNotEmpty)
                      TaskGroup(
                        indent: CarliSpace.s16,
                        children: [for (final template in active) _TemplateRow(template: template)],
                      ),
                    if (paused.isNotEmpty) ...[
                      CarliSectionHeader(title: 'Pausadas'),
                      TaskGroup(
                        indent: CarliSpace.s16,
                        children: [for (final template in paused) _TemplateRow(template: template)],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.template});

  final TaskTemplate template;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final next = template.nextDate;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: () => context.push(TasksRoutes.template(template.id)),
        pressedOpacity: 0.6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
          child: Row(
            spacing: CarliSpace.s12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      template.title,
                      style: CarliType.body.copyWith(color: template.paused ? colors.text2 : colors.text),
                    ),
                    Text(
                      templateRule(template),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.small.copyWith(color: colors.text2),
                    ),
                  ],
                ),
              ),
              if (template.paused)
                CarliBadge('Pausada', icon: carliIconNamed('clock'))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: 2,
                  children: [
                    Text(
                      next == null ? '—' : '${template.afterDone ? '≈ ' : ''}${weekdayShortDate(next)}',
                      style: CarliType.money(CarliType.small).copyWith(color: colors.text, fontWeight: FontWeight.w600),
                    ),
                    Text(template.list.name, style: CarliType.caption.copyWith(color: colors.text2)),
                  ],
                ),
              CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
            ],
          ),
        ),
      ),
    );
  }
}
