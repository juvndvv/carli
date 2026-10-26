import 'package:flutter/cupertino.dart';
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
import '../../data/models.dart';

const _keepTransactions = '';

Future<bool> showDeleteCategory(BuildContext context, Category category) async {
  if (category.hasChildren) {
    await showCupertinoDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Eliminar ${category.name}'),
        content: const Text('Tiene subcategorías. Muévelas o elimínalas antes de borrar esta categoría.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    return false;
  }
  final deleted = await showCarliSheet<bool>(
    context,
    title: 'Eliminar ${category.name}',
    builder: (context) => _DeleteCategorySheet(category: category),
  );
  return deleted ?? false;
}

class _DeleteCategorySheet extends ConsumerStatefulWidget {
  const _DeleteCategorySheet({required this.category});

  final Category category;

  @override
  ConsumerState<_DeleteCategorySheet> createState() => _DeleteCategorySheetState();
}

class _DeleteCategorySheetState extends ConsumerState<_DeleteCategorySheet> {
  var _target = _keepTransactions;
  var _deleting = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref
          .read(categoriesAdminRepositoryProvider)
          .remove(widget.category.id, reassignTo: _target == _keepTransactions ? null : _target);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(error, fallback: 'Tiene movimientos: elige una categoría a la que moverlos.'),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final targets = ref.watch(adminCategoriesProvider).value?.reassignTargets(widget.category) ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(
            'Si tiene movimientos, presupuestos o recurrentes, elige a qué categoría pasan. Esta acción no se puede deshacer.',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          CarliField(
            label: 'Mover sus movimientos a',
            error: _error,
            child: CarliSelect<String>(
              title: 'Mover sus movimientos a',
              value: _target,
              invalid: _error != null,
              onChanged: (id) => setState(() => _target = id),
              options: [
                const CarliOption(_keepTransactions, 'No mover (solo si no tiene movimientos)'),
                for (final entry in targets)
                  CarliOption(entry.category.id, entry.label, icon: carliIconNamed(entry.icon)),
              ],
            ),
          ),
          Row(
            spacing: CarliSpace.s12,
            children: [
              Expanded(
                child: CarliButton(
                  label: 'Cancelar',
                  variant: CarliButtonVariant.ghost,
                  size: CarliButtonSize.md,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              Expanded(
                child: CarliButton(
                  label: 'Eliminar',
                  icon: carliIconNamed('trash'),
                  variant: CarliButtonVariant.danger,
                  size: CarliButtonSize.md,
                  loading: _deleting,
                  onPressed: _confirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
