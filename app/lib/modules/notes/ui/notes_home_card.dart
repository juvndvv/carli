import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/modules/modules_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/card.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../data/models.dart';
import '../data/notes_actions.dart';
import '../data/notes_sync.dart';
import '../data/views.dart';
import '../notes_paths.dart';
import 'notes_widgets.dart';

/// Inicio card: what is left to buy on the main list, its first items to tick, and up to two pinned notes.
class NotesHomeCard extends ConsumerWidget {
  const NotesHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(enabledModuleIdsProvider)?.contains(notesModuleId) != true) return const SizedBox.shrink();
    final index = ref.watch(notesIndexProvider).value;
    if (index == null) return const SizedBox.shrink();
    final shopping = index.primaryShoppingNote;
    final pinned = index.pinnedNotes.where((note) => note.id != shopping?.id).take(2).toList();
    if (shopping == null && pinned.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final open = shopping?.items.where((item) => !item.checked).take(3).toList() ?? const <NoteItem>[];
    return Padding(
      padding: const EdgeInsets.only(top: CarliSpace.s16),
      child: CarliCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CarliSpace.s12,
          children: [
            if (shopping != null) ...[
              Semantics(
                button: true,
                hint: 'Abrir la lista de la compra',
                child: Pressable(
                  onTap: () => context.go(NotesPaths.shopping),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              'Notas · ${shopping.displayTitle}',
                              style: CarliType.small.copyWith(color: colors.text2),
                            ),
                            Text.rich(
                              TextSpan(
                                text: '${shopping.openCount} ',
                                style: CarliType.metric.copyWith(color: colors.text),
                                children: [
                                  TextSpan(
                                    text: 'por comprar',
                                    style: CarliType.body.copyWith(color: colors.text2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: CarliSpace.s8),
                        child: CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
                      ),
                    ],
                  ),
                ),
              ),
              if (open.isNotEmpty)
                Column(
                  children: [
                    for (final item in open)
                      Semantics(
                        button: true,
                        checked: item.checked,
                        label: item.text,
                        hint: 'Al carro',
                        excludeSemantics: true,
                        child: Pressable(
                          onTap: () => ref.read(notesActionsProvider).setChecked(item, true),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: CarliSpace.s8),
                            child: Row(
                              spacing: CarliSpace.s12,
                              children: [
                                CheckCircle(checked: item.checked),
                                Expanded(
                                  child: Text(item.text, style: CarliType.body.copyWith(color: colors.text)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
            if (pinned.isNotEmpty) ...[
              if (shopping != null) Divider(height: 1, thickness: 0.5, color: colors.border),
              Row(
                spacing: CarliSpace.s8,
                children: [
                  for (final note in pinned)
                    Expanded(
                      child: Pressable(
                        onTap: () => context.go(NotesPaths.note(note.id)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s12, vertical: 10),
                          decoration: BoxDecoration(
                            color: colors.surface2,
                            borderRadius: BorderRadius.circular(CarliRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              Text(
                                note.type == NoteType.text ? 'Fijada' : 'Fijada · ${notePreview(note)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CarliType.small.copyWith(color: colors.text2),
                              ),
                              Text(
                                note.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CarliType.bodyStrong.copyWith(color: colors.text),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (pinned.length == 1) const Spacer(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
