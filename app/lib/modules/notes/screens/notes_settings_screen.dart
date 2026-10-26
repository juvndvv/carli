import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/modules/modules_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../../../ui/segmented.dart';
import '../../../ui/toast.dart';
import '../data/models.dart';
import '../data/notes_actions.dart';
import '../data/notes_store.dart';
import '../data/notes_sync.dart';
import '../data/views.dart';
import 'note_screen.dart';
import '../ui/notes_widgets.dart';

class NotesSettingsScreen extends ConsumerWidget {
  const NotesSettingsScreen({super.key});

  Future<void> _setDefaultBehavior(WidgetRef ref, CheckedBehavior behavior) async {
    try {
      await ref
          .read(dioProvider)
          .patch<Object?>(
            '/v1/modules/$notesModuleId',
            data: {
              'settings': {'checked_behavior': behavior.wire},
            },
          );
      ref.invalidate(modulesProvider);
    } catch (error) {
      ref.read(toastControllerProvider.notifier).error(apiErrorMessage(error, fallback: 'No se ha podido guardar.'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final index = ref.watch(notesIndexProvider).value ?? NotesIndex.empty;
    final actions = ref.read(notesActionsProvider);
    final lists = index.shoppingNotes();
    final primary = index.primaryShoppingNote;
    final behavior = ref.watch(notesDefaultCheckedBehaviorProvider);
    final sections = index.sections;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s48),
          children: [
            const NoteTopBar(),
            Text('Ajustes de Notas', style: CarliType.h1.copyWith(color: colors.text)),
            if (lists.length > 1) ...[
              const SectionLabel('Lista de la compra principal'),
              GroupedRows(
                indent: 16,
                children: [
                  for (final note in lists)
                    Pressable(
                      onTap: () => actions.makePrimary(note.id),
                      pressedOpacity: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(note.displayTitle, style: CarliType.body.copyWith(color: colors.text)),
                            ),
                            if (note.id == primary?.id)
                              CarliIcon(carliIconNamed('check'), size: 18, color: colors.brandInk),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(CarliSpace.s4, CarliSpace.s8, CarliSpace.s4, 0),
                child: Text('Es la que abre la pestaña Compra.', style: CarliType.small.copyWith(color: colors.text2)),
              ),
            ],
            const SectionLabel('Elementos marcados en listas nuevas'),
            CarliSegmented<CheckedBehavior>(
              value: behavior,
              segments: const [
                CarliSegment(CheckedBehavior.move, 'Bajan a "Hechos"'),
                CarliSegment(CheckedBehavior.inline, 'Tachados en su sitio'),
              ],
              onChanged: (value) => _setDefaultBehavior(ref, value),
            ),
            SectionLabel(
              'Secciones del súper',
              trailing: TextButton(
                onPressed: () async {
                  final name = await promptName(context, title: 'Nueva sección', confirmLabel: 'Crear');
                  if (name != null) await actions.createSection(name);
                },
                child: const Text('Añadir'),
              ),
            ),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(CarliRadius.lg),
                border: Border.all(color: colors.cardBorder),
              ),
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) {
                  final ordered = [...sections];
                  ordered.insert(to, ordered.removeAt(from));
                  actions.reorderSections(ordered);
                },
                children: [
                  for (final (position, section) in sections.indexed)
                    SwipeToDelete(
                      key: ValueKey(section.id),
                      id: section.id,
                      onDelete: () => actions.deleteSection(section.id),
                      child: _SectionRow(
                        section: section,
                        position: position,
                        onRename: () async {
                          final name = await promptName(context, title: 'Renombrar sección', initial: section.name);
                          if (name != null) await actions.renameSection(section.id, name);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(CarliSpace.s4, CarliSpace.s8, CarliSpace.s4, 0),
              child: Text(
                'Ordénalas como recorres tu súper: arrastra para mover, desliza para borrar.',
                style: CarliType.small.copyWith(color: colors.text2),
              ),
            ),
            const SizedBox(height: CarliSpace.s24),
            CarliButton(
              label: 'Sincronizar ahora',
              variant: CarliButtonVariant.secondary,
              onPressed: () => ref.read(notesSyncProvider.notifier).sync(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section, required this.position, required this.onRename});

  final ShoppingSection section;
  final int position;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.surface,
      child: Column(
        children: [
          if (position > 0) Divider(height: 1, thickness: 0.5, indent: CarliSpace.s16, color: colors.border),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: onRename,
                  pressedOpacity: 0.5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: 13),
                    child: Text(section.name, style: CarliType.body.copyWith(color: colors.text)),
                  ),
                ),
              ),
              ReorderableDragStartListener(
                index: position,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: 13),
                  child: CarliIcon(carliIconNamed('menu'), size: 18, color: colors.text3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
