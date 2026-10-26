import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';
import '../data/models.dart';
import '../data/notes_sync.dart';

CarliIconData noteTypeIcon(NoteType type) => switch (type) {
  NoteType.text => HugeIconsStrokeRounded.note01,
  NoteType.list => HugeIconsStrokeRounded.checkList,
  NoteType.shopping => HugeIconsStrokeRounded.shoppingCart01,
};

const folderIcon = HugeIconsStrokeRounded.folder01;
const moreIcon = HugeIconsStrokeRounded.moreHorizontal;
const searchIcon = HugeIconsStrokeRounded.search01;
const pinIcon = HugeIconsStrokeRounded.pin;

class NoteTypeBadge extends StatelessWidget {
  const NoteTypeBadge(this.type, {super.key, this.size = 32});

  final NoteType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(CarliRadius.chip)),
      child: CarliIcon(noteTypeIcon(type), size: size * 0.56, color: colors.text),
    );
  }
}

class CheckCircle extends StatelessWidget {
  const CheckCircle({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: CarliMotion.hover,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? colors.text2 : null,
        border: checked ? null : Border.all(color: colors.text3, width: 1.5),
      ),
      child: checked ? CarliIcon(carliIconNamed('check'), size: 13, color: colors.surface, strokeWidth: 2.6) : null,
    );
  }
}

/// White rounded group of rows separated by hairlines, as in iOS settings lists.
class GroupedRows extends StatelessWidget {
  const GroupedRows({super.key, required this.children, this.indent = 50});

  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CarliRadius.lg),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) Divider(height: 1, thickness: 0.5, indent: indent, color: colors.border),
            child,
          ],
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s4, CarliSpace.s16, CarliSpace.s4, CarliSpace.s8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text.toUpperCase(), style: CarliType.eyebrow.copyWith(color: colors.text2)),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({
    super.key,
    required this.id,
    required this.onDelete,
    required this.child,
    this.label = 'Borrar',
  });

  final String id;
  final VoidCallback onDelete;
  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dismissible(
      key: ValueKey('swipe-$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: CarliColors.dangerFill,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: CarliSpace.s20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: CarliSpace.s8,
          children: [
            CarliIcon(carliIconNamed('trash'), size: 18, color: colors.onPrimary),
            Text(
              label,
              style: CarliType.small.copyWith(fontWeight: FontWeight.w600, color: colors.onPrimary),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.label, required this.onTap, this.active = false});

  final CarliIconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: active ? colors.text : colors.surface2, shape: BoxShape.circle),
            child: CarliIcon(icon, size: 18, color: active ? colors.bg : colors.text, strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

/// "Sin conexión" line: changes keep working and are sent when the connection comes back.
class OfflineNotice extends ConsumerWidget {
  const OfflineNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(notesSyncProvider.select((state) => state.online));
    final colors = context.colors;
    return AnimatedSize(
      duration: CarliMotion.enter,
      child: online
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: CarliSpace.s12),
                padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s12, vertical: CarliSpace.s8),
                decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(CarliRadius.md)),
                child: Row(
                  spacing: CarliSpace.s8,
                  children: [
                    CarliIcon(HugeIconsStrokeRounded.wifiOff01, size: 16, color: colors.text2),
                    Expanded(
                      child: Text(
                        'Sin conexión. Tus cambios se guardan y se envían al volver.',
                        style: CarliType.small.copyWith(color: colors.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

typedef MenuAction<T> = (T value, String label, bool destructive);

Future<T?> showActionMenu<T>(BuildContext context, {String? title, required List<MenuAction<T>> actions}) =>
    showCupertinoModalPopup<T>(
      context: context,
      useRootNavigator: true,
      builder: (context) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        actions: [
          for (final (value, label, destructive) in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: destructive,
              onPressed: () => Navigator.pop(context, value),
              child: Text(label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ),
    );

Future<String?> promptName(
  BuildContext context, {
  required String title,
  String initial = '',
  String placeholder = 'Nombre',
  String confirmLabel = 'Guardar',
}) async {
  final result = await showCupertinoDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (context) =>
        _NamePrompt(title: title, initial: initial, placeholder: placeholder, confirmLabel: confirmLabel),
  );
  final trimmed = result?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

class _NamePrompt extends StatefulWidget {
  const _NamePrompt({
    required this.title,
    required this.initial,
    required this.placeholder,
    required this.confirmLabel,
  });

  final String title;
  final String initial;
  final String placeholder;
  final String confirmLabel;

  @override
  State<_NamePrompt> createState() => _NamePromptState();
}

class _NamePromptState extends State<_NamePrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: Text(widget.title),
    content: Padding(
      padding: const EdgeInsets.only(top: CarliSpace.s12),
      child: CupertinoTextField(
        controller: _controller,
        autofocus: true,
        placeholder: widget.placeholder,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
    ),
    actions: [
      CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      CupertinoDialogAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
