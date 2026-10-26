import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../data/models.dart';
import '../data/notes_format.dart';
import '../data/views.dart';
import 'notes_widgets.dart';

class NoteRow extends StatelessWidget {
  const NoteRow({super.key, required this.note, required this.onTap, this.path = const [], this.preview, this.now});

  final Note note;
  final VoidCallback onTap;
  final List<String> path;
  final String? preview;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = preview ?? notePreview(note);
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        pressedOpacity: 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
          child: Row(
            spacing: CarliSpace.s12,
            children: [
              NoteTypeBadge(note.type),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      note.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.bodyStrong.copyWith(color: colors.text),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CarliType.small.copyWith(color: colors.text2),
                      ),
                    if (path.isNotEmpty)
                      Row(
                        spacing: CarliSpace.s4,
                        children: [
                          CarliIcon(folderIcon, size: 12, color: colors.text3),
                          Expanded(
                            child: Text(
                              path.join(' › '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CarliType.caption.copyWith(color: colors.text3),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Text(
                noteWhen(note.updatedAt, now: now),
                style: CarliType.small.copyWith(color: colors.text2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PinnedCard extends StatelessWidget {
  const PinnedCard({super.key, required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final counter = switch (note.type) {
      NoteType.shopping => (note.openCount, 'por comprar'),
      NoteType.list when note.items.isNotEmpty => (note.checkedCount, 'de ${note.items.length}'),
      _ => null,
    };
    return Semantics(
      button: true,
      label: '${note.displayTitle}, fijada',
      child: Pressable(
        onTap: onTap,
        pressedOpacity: 0.7,
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(CarliRadius.lg),
            border: Border.all(color: colors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CarliSpace.s8,
            children: [
              Row(
                spacing: 6,
                children: [
                  CarliIcon(noteTypeIcon(note.type), size: 14, color: colors.text2),
                  Text(note.type.label, style: CarliType.small.copyWith(color: colors.text2)),
                ],
              ),
              Text(
                note.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CarliType.h2.copyWith(color: colors.text),
              ),
              if (counter case (final count, final unit))
                Text.rich(
                  TextSpan(
                    text: '$count ',
                    style: CarliType.metric.copyWith(color: colors.text),
                    children: [
                      TextSpan(
                        text: unit,
                        style: CarliType.small.copyWith(color: colors.text2),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  notePreview(note),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CarliType.small.copyWith(color: colors.text2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FolderChip extends StatelessWidget {
  const FolderChip({super.key, required this.folder, required this.count, required this.onTap, this.onLongPress});

  final NoteFolder folder;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: '${folder.name}, $count notas',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: CarliSpace.s8,
            children: [
              CarliIcon(folderIcon, size: 16, color: colors.text),
              Text(folder.name, style: CarliType.bodyStrong.copyWith(color: colors.text)),
              Text('$count', style: CarliType.small.copyWith(color: colors.text2)),
            ],
          ),
        ),
      ),
    );
  }
}

class FolderRow extends StatelessWidget {
  const FolderRow({super.key, required this.folder, required this.count, required this.onTap, this.onMenu});

  final NoteFolder folder;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: '${folder.name}, $count notas',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        onLongPress: onMenu,
        pressedOpacity: 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
          child: Row(
            spacing: CarliSpace.s12,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(CarliRadius.chip),
                ),
                child: CarliIcon(folderIcon, size: 18, color: colors.text),
              ),
              Expanded(
                child: Text(folder.name, style: CarliType.bodyStrong.copyWith(color: colors.text)),
              ),
              Text('$count', style: CarliType.small.copyWith(color: colors.text2)),
              CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
            ],
          ),
        ),
      ),
    );
  }
}
