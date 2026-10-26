import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/field.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/pressable.dart';
import '../../../../ui/segmented.dart';
import '../../../../ui/select.dart';
import '../../../../ui/switch.dart';
import '../../data/categories_admin.dart';
import '../../data/finance_providers.dart';
import '../../data/models.dart';

Future<Category?> showCategoryForm(
  BuildContext context, {
  required CategoryKind kind,
  Category? category,
  String? parentId,
}) => showModalBottomSheet<Category>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.94,
    child: CategoryFormSheet(kind: kind, category: category, parentId: parentId),
  ),
);

class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({super.key, required this.kind, this.category, this.parentId});

  final CategoryKind kind;
  final Category? category;
  final String? parentId;

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  late final _draft = switch (widget.category) {
    final category? => CategoryDraft.edit(category),
    null => CategoryDraft(kind: widget.kind, parentId: widget.parentId),
  };
  late final _name = TextEditingController(text: _draft.name);
  var _submitted = false;
  var _saving = false;
  String? _error;

  Category? get _category => widget.category;

  bool get _canChangeParent => !(_category?.hasChildren ?? false);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _draft.name = _name.text;
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_draft.valid) return;
    final payload = _draft.toPayload(creating: _category == null, canChangeParent: _canChangeParent);
    setState(() => _saving = true);
    final repository = ref.read(categoriesAdminRepositoryProvider);
    try {
      final saved = switch (_category) {
        final category? => await repository.update(category.id, payload),
        null => await repository.create(payload),
      };
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido guardar la categoría.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tree = ref.watch(adminCategoriesProvider).value;
    final parents = [
      for (final parent in tree?.topLevel(_draft.kind) ?? const <Category>[])
        if (parent.id != _category?.id) parent,
    ];
    final nameError = _submitted && !_draft.valid ? 'Ponle un nombre.' : null;

    return Column(
      children: [
        _FormHeader(
          title: _category == null ? 'Nueva categoría' : 'Editar categoría',
          saving: _saving,
          onCancel: () => Navigator.pop(context),
          onSave: _save,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, CarliSpace.s32),
            children: [
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(bottom: CarliSpace.s16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(error, style: CarliType.small.copyWith(color: colors.negative)),
                  ),
                ),
              if (_category == null) ...[
                CarliSegmented<CategoryKind>(
                  value: _draft.kind,
                  onChanged: (value) => setState(() => _draft.changeKind(value)),
                  segments: const [
                    CarliSegment(CategoryKind.expense, 'Gasto'),
                    CarliSegment(CategoryKind.income, 'Ingreso'),
                  ],
                ),
                const SizedBox(height: CarliSpace.s16),
              ],
              CarliField(
                label: 'Nombre',
                error: nameError,
                child: CarliInput(
                  controller: _name,
                  placeholder: 'Ej. Mascotas',
                  invalid: nameError != null,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(80)],
                  onChanged: (value) {
                    _draft.name = value;
                    if (_submitted) setState(() {});
                  },
                ),
              ),
              if (_canChangeParent) ...[
                const SizedBox(height: CarliSpace.s16),
                CarliField(
                  label: 'Dentro de',
                  child: CarliSelect<String?>(
                    title: 'Dentro de',
                    value: _draft.parentId,
                    onChanged: (id) => setState(() => _draft.parentId = id),
                    options: [
                      const CarliOption<String?>(null, 'Ninguna (categoría principal)'),
                      for (final parent in parents)
                        CarliOption<String?>(
                          parent.id,
                          parent.name,
                          icon: carliIconNamed(parent.icon ?? fallbackCategoryIcon),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Icono',
                child: Wrap(
                  spacing: CarliSpace.s8,
                  runSpacing: CarliSpace.s8,
                  children: [
                    for (final icon in categoryIconChoices)
                      _IconChoice(
                        name: icon,
                        selected: _draft.icon == icon,
                        onTap: () => setState(() => _draft.icon = icon),
                      ),
                  ],
                ),
              ),
              if (_draft.parentId == null) ...[
                const SizedBox(height: CarliSpace.s16),
                CarliField(
                  label: 'Color en gráficos',
                  child: Wrap(
                    spacing: CarliSpace.s8,
                    runSpacing: CarliSpace.s8,
                    children: [
                      for (final (index, color) in categoryColorChoices.indexed)
                        _ColorChoice(
                          index: index,
                          color: colors.chart[index],
                          selected: _draft.color == color,
                          onTap: () => setState(() => _draft.color = color),
                        ),
                    ],
                  ),
                ),
              ],
              if (_draft.kind == CategoryKind.income) ...[
                const SizedBox(height: CarliSpace.s16),
                Row(
                  spacing: CarliSpace.s12,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Abre periodo', style: CarliType.body.copyWith(color: colors.text)),
                          Text(
                            'Al registrar este ingreso empieza un periodo nuevo (p. ej. la nómina).',
                            style: CarliType.small.copyWith(color: colors.text3),
                          ),
                        ],
                      ),
                    ),
                    CarliSwitch(
                      value: _draft.opensPeriod,
                      semanticLabel: 'Abre periodo',
                      onChanged: (value) => setState(() => _draft.opensPeriod = value),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.title, required this.saving, required this.onCancel, required this.onSave});

  final String title;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(foregroundColor: colors.text2, textStyle: CarliType.body),
            child: const Text('Cancelar'),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: CarliType.h2.copyWith(color: colors.text),
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: saving
                ? const Center(child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton(onPressed: onSave, child: const Text('Guardar')),
          ),
        ],
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({required this.name, required this.selected, required this.onTap});

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: CarliMotion.hover,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? colors.primary : colors.surface2, shape: BoxShape.circle),
          child: CarliIcon(carliIconNamed(name), size: 20, color: selected ? colors.onPrimary : colors.text),
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({required this.index, required this.color, required this.selected, required this.onTap});

  final int index;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Color ${index + 1}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? colors.text : colors.border, width: selected ? 2 : 1),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
