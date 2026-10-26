import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/button.dart';
import '../../../../ui/field.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/select.dart';
import '../../../../ui/sheet.dart';
import '../../data/categories_admin.dart';
import '../../data/finance_providers.dart';
import '../../data/models.dart';

Future<Tag?> showRenameTag(BuildContext context, Tag tag) => showCarliSheet<Tag>(
  context,
  title: 'Renombrar etiqueta',
  builder: (context) => _RenameTagSheet(tag: tag),
);

Future<Tag?> showMergeTag(BuildContext context, Tag tag) => showCarliSheet<Tag>(
  context,
  title: 'Fusionar etiqueta',
  builder: (context) => _MergeTagSheet(tag: tag),
);

class _RenameTagSheet extends ConsumerStatefulWidget {
  const _RenameTagSheet({required this.tag});

  final Tag tag;

  @override
  ConsumerState<_RenameTagSheet> createState() => _RenameTagSheetState();
}

class _RenameTagSheetState extends ConsumerState<_RenameTagSheet> {
  late final _name = TextEditingController(text: widget.tag.name);
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = normalizeTagName(_name.text);
    if (name.isEmpty || name == widget.tag.name) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final renamed = await ref.read(categoriesAdminRepositoryProvider).renameTag(widget.tag.id, name);
      if (mounted) Navigator.pop(context, renamed);
    } catch (error) {
      if (mounted) {
        setState(() => _error = apiErrorMessage(error, fallback: 'Ya existe una etiqueta con ese nombre: fusiónalas.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text('#${widget.tag.name}', style: CarliType.small.copyWith(color: colors.text2)),
          CarliField(
            label: 'Nuevo nombre',
            error: _error,
            child: CarliInput(
              controller: _name,
              autofocus: true,
              invalid: _error != null,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
          ),
          _SheetActions(confirmLabel: 'Guardar', loading: _saving, onConfirm: _name.text.trim().isEmpty ? null : _save),
        ],
      ),
    );
  }
}

class _MergeTagSheet extends ConsumerStatefulWidget {
  const _MergeTagSheet({required this.tag});

  final Tag tag;

  @override
  ConsumerState<_MergeTagSheet> createState() => _MergeTagSheetState();
}

class _MergeTagSheetState extends ConsumerState<_MergeTagSheet> {
  String? _target;
  var _saving = false;
  String? _error;

  Future<void> _merge(String target) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final merged = await ref.read(categoriesAdminRepositoryProvider).mergeTag(widget.tag.id, target);
      if (mounted) Navigator.pop(context, merged);
    } catch (error) {
      if (mounted) {
        setState(() => _error = apiErrorMessage(error, fallback: 'No se han podido fusionar las etiquetas.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final target = _target;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(
            '#${widget.tag.name} desaparecerá y sus movimientos pasarán a la elegida.',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          CarliField(
            label: 'Fusionar con',
            error: _error,
            child: CarliSelect<String>(
              title: 'Fusionar con',
              placeholder: 'Elige una etiqueta',
              value: target,
              invalid: _error != null,
              onChanged: (id) => setState(() => _target = id),
              options: [
                for (final candidate in tags)
                  if (candidate.id != widget.tag.id) CarliOption(candidate.id, '#${candidate.name}'),
              ],
            ),
          ),
          _SheetActions(
            confirmLabel: 'Fusionar',
            icon: 'git-merge',
            loading: _saving,
            onConfirm: target == null ? null : () => _merge(target),
          ),
        ],
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.confirmLabel, required this.loading, required this.onConfirm, this.icon});

  final String confirmLabel;
  final String? icon;
  final bool loading;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: CarliSpace.s12,
      children: [
        Expanded(
          child: CarliButton(
            label: 'Cancelar',
            variant: CarliButtonVariant.ghost,
            size: CarliButtonSize.md,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: CarliButton(
            label: confirmLabel,
            icon: icon == null ? null : carliIconNamed(icon),
            size: CarliButtonSize.md,
            loading: loading,
            onPressed: onConfirm,
          ),
        ),
      ],
    );
  }
}
