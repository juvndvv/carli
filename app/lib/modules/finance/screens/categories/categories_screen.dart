import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
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
import '../../../../ui/pressable.dart';
import '../../../../ui/segmented.dart';
import '../../../../ui/sheet.dart';
import '../../../../ui/skeleton.dart';
import '../../../../ui/toast.dart';
import '../../data/categories_admin.dart';
import '../../data/finance_changes.dart';
import '../../data/finance_providers.dart';
import '../../data/models.dart';
import 'category_form_sheet.dart';
import 'delete_category_sheet.dart';
import 'tag_sheets.dart';

enum CategoriesView { expense, income, tags }

enum _CategoryAction { edit, addChild, archive, delete }

enum _TagAction { rename, merge, delete }

String _childrenLabel(Category category) => switch (category.children.length) {
  0 => '',
  1 => '1 subcategoría',
  final count => '$count subcategorías',
};

String _movementsLabel(int count) => count == 1 ? '1 movimiento' : '$count movimientos';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key, this.initialView = CategoriesView.expense});

  final CategoriesView initialView;

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  late var _view = widget.initialView;
  var _showArchived = false;

  CategoryKind get _kind => _view == CategoriesView.income ? CategoryKind.income : CategoryKind.expense;

  ToastController get _toasts => ref.read(toastControllerProvider.notifier);

  Future<void> _refresh() async {
    ref.read(financeChangesProvider.notifier).notify(const [FinanceScope.categories, FinanceScope.tags]);
    await Future.wait([
      ref.read(adminCategoriesProvider.future).then((_) {}, onError: (_) {}),
      ref.read(tagsProvider.future).then((_) {}, onError: (_) {}),
    ]);
  }

  Future<void> _create({String? parentId}) async {
    if (await showCategoryForm(context, kind: _kind, parentId: parentId) != null) {
      _toasts.show('Categoría creada');
    }
  }

  Future<void> _edit(Category category) async {
    if (await showCategoryForm(context, kind: category.kind, category: category) != null) {
      _toasts.show('Categoría actualizada');
    }
  }

  Future<void> _setArchived(Category category, bool archived) async {
    final repository = ref.read(categoriesAdminRepositoryProvider);
    try {
      await repository.setArchived(category.id, archived);
      _toasts.withUndo(
        archived ? '${category.name} archivada' : '${category.name} recuperada',
        () => repository.setArchived(category.id, !archived),
      );
    } catch (error) {
      _toasts.error(apiErrorMessage(error, fallback: 'No se ha podido actualizar la categoría.'));
    }
  }

  Future<void> _remove(Category category) async {
    if (await showDeleteCategory(context, category)) _toasts.show('Categoría eliminada');
  }

  Future<void> _categoryMenu(Category category, {required bool child}) async {
    final action = await _showActions<_CategoryAction>(context, category.name, [
      (_CategoryAction.edit, 'Editar', false),
      if (!child) (_CategoryAction.addChild, 'Añadir subcategoría', false),
      (_CategoryAction.archive, category.archived ? 'Desarchivar' : 'Archivar', false),
      (_CategoryAction.delete, 'Eliminar', true),
    ]);
    if (!mounted) return;
    switch (action) {
      case _CategoryAction.edit:
        await _edit(category);
      case _CategoryAction.addChild:
        await _create(parentId: category.id);
      case _CategoryAction.archive:
        await _setArchived(category, !category.archived);
      case _CategoryAction.delete:
        await _remove(category);
      case null:
        break;
    }
  }

  Future<void> _tagMenu(Tag tag) async {
    final action = await _showActions<_TagAction>(context, '#${tag.name}', const [
      (_TagAction.rename, 'Renombrar', false),
      (_TagAction.merge, 'Fusionar con…', false),
      (_TagAction.delete, 'Eliminar', true),
    ]);
    if (!mounted) return;
    switch (action) {
      case _TagAction.rename:
        if (await showRenameTag(context, tag) != null) _toasts.show('Etiqueta renombrada');
      case _TagAction.merge:
        if (await showMergeTag(context, tag) case final target?) {
          _toasts.show('#${tag.name} fusionada con #${target.name}');
        }
      case _TagAction.delete:
        await _deleteTag(tag);
      case null:
        break;
    }
  }

  Future<void> _deleteTag(Tag tag) async {
    final confirmed = await confirmCarli(
      context,
      title: '¿Eliminar #${tag.name}?',
      message: 'Se quitará de todos sus movimientos. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(categoriesAdminRepositoryProvider).removeTag(tag.id);
      _toasts.show('Etiqueta eliminada');
    } catch (error) {
      _toasts.error(apiErrorMessage(error, fallback: 'No se ha podido eliminar la etiqueta.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(adminCategoriesProvider);
    final tags = ref.watch(tagsProvider);
    final showingTags = _view == CategoriesView.tags;

    return CarliPage(
      title: 'Categorías y etiquetas',
      trailing: showingTags
          ? null
          : CarliButton.icon(
              icon: carliIconNamed('plus'),
              semanticLabel: 'Nueva categoría',
              size: CarliButtonSize.sm,
              onPressed: _create,
            ),
      onRefresh: _refresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s12),
          sliver: SliverToBoxAdapter(
            child: CarliSegmented<CategoriesView>(
              value: _view,
              onChanged: (view) => setState(() => _view = view),
              segments: const [
                CarliSegment(CategoriesView.expense, 'Gastos'),
                CarliSegment(CategoriesView.income, 'Ingresos'),
                CarliSegment(CategoriesView.tags, 'Etiquetas'),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: showingTags
                ? AsyncView(
                    value: tags,
                    errorTitle: 'No se han podido cargar las etiquetas',
                    onRetry: () => ref.invalidate(tagsProvider),
                    loading: const _ListSkeleton(rows: 1),
                    data: (tags) => _TagList(tags: tags, onMenu: _tagMenu),
                  )
                : AsyncView(
                    value: tree,
                    errorTitle: 'No se han podido cargar las categorías',
                    onRetry: () => ref.invalidate(categoriesProvider),
                    loading: const _ListSkeleton(rows: 2),
                    data: (tree) => _CategoryList(
                      categories: tree.visible(_kind, showArchived: _showArchived),
                      archivedCount: tree.archivedCount(_kind),
                      showArchived: _showArchived,
                      onToggleArchived: () => setState(() => _showArchived = !_showArchived),
                      onCreate: _create,
                      onMenu: _categoryMenu,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

Future<T?> _showActions<T>(BuildContext context, String title, List<(T, String, bool)> actions) =>
    showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
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

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.archivedCount,
    required this.showArchived,
    required this.onToggleArchived,
    required this.onCreate,
    required this.onMenu,
  });

  final List<Category> categories;
  final int archivedCount;
  final bool showArchived;
  final VoidCallback onToggleArchived;
  final VoidCallback onCreate;
  final Future<void> Function(Category category, {required bool child}) onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = <Widget>[
      for (final parent in categories) ...[
        _CategoryRow(
          category: parent,
          icon: parent.icon ?? fallbackCategoryIcon,
          subtitle: _childrenLabel(parent),
          onMenu: () => onMenu(parent, child: false),
        ),
        for (final child in parent.children)
          _CategoryRow(
            category: child,
            icon: child.icon ?? parent.icon ?? fallbackCategoryIcon,
            child: true,
            onMenu: () => onMenu(child, child: true),
          ),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: CarliSpace.s12,
      children: [
        CarliCard(
          padding: const EdgeInsets.symmetric(vertical: CarliSpace.s4),
          child: rows.isEmpty
              ? CarliEmptyState(
                  icon: carliIconNamed('tag'),
                  title: 'Sin categorías',
                  message: 'Crea categorías para clasificar tus movimientos.',
                  actionLabel: 'Nueva categoría',
                  onAction: onCreate,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, row) in rows.indexed) ...[
                      if (index > 0) Divider(indent: 68, color: colors.border),
                      row,
                    ],
                  ],
                ),
        ),
        if (archivedCount > 0)
          Semantics(
            button: true,
            child: Pressable(
              onTap: onToggleArchived,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CarliSpace.s8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    CarliIcon(carliIconNamed('archive'), size: 14, color: colors.text3),
                    Text(
                      '${archivedCount == 1 ? '1 archivada' : '$archivedCount archivadas'} · ${showArchived ? 'ocultar' : 'mostrar'}',
                      style: CarliType.small.copyWith(color: colors.text3),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.icon,
    required this.onMenu,
    this.subtitle = '',
    this.child = false,
  });

  final Category category;
  final String icon;
  final String subtitle;
  final bool child;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = child ? 32.0 : 40.0;
    final badges = [
      if (category.opensPeriod)
        CarliBadge('Abre periodo', tone: CarliBadgeTone.primary, icon: carliIconNamed('calendar-range')),
      if (category.archived) CarliBadge('Archivada', icon: carliIconNamed('archive')),
    ];
    return Opacity(
      opacity: category.archived ? 0.6 : 1,
      child: Semantics(
        button: true,
        hint: 'Opciones',
        child: Pressable(
          onTap: onMenu,
          pressedOpacity: 0.5,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              child ? CarliSpace.s16 + CarliSpace.s32 : CarliSpace.s16,
              CarliSpace.s12,
              CarliSpace.s8,
              CarliSpace.s12,
            ),
            child: Row(
              spacing: CarliSpace.s12,
              children: [
                Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: child ? colors.primarySoft : colors.surface2,
                    shape: BoxShape.circle,
                  ),
                  child: CarliIcon(
                    carliIconNamed(icon),
                    size: child ? 16 : 20,
                    color: child ? colors.brandInk : colors.text,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CarliType.body.copyWith(
                          fontWeight: child ? FontWeight.w400 : FontWeight.w500,
                          color: colors.text,
                        ),
                      ),
                      if (subtitle.isNotEmpty) Text(subtitle, style: CarliType.small.copyWith(color: colors.text2)),
                      if (badges.isNotEmpty) Wrap(spacing: CarliSpace.s4, runSpacing: CarliSpace.s4, children: badges),
                    ],
                  ),
                ),
                Semantics(
                  container: true,
                  child: CarliButton.icon(
                    icon: carliIconNamed('ellipsis'),
                    semanticLabel: 'Opciones de ${category.name}',
                    size: CarliButtonSize.sm,
                    onPressed: onMenu,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagList extends StatelessWidget {
  const _TagList({required this.tags, required this.onMenu});

  final List<Tag> tags;
  final Future<void> Function(Tag tag) onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CarliCard(
      padding: const EdgeInsets.symmetric(vertical: CarliSpace.s4),
      child: tags.isEmpty
          ? CarliEmptyState(
              icon: carliIconNamed('hash'),
              title: 'Aún no hay etiquetas',
              message: 'Añádelas al apuntar un movimiento (por ejemplo #vacaciones-2026) para agrupar gastos de distintas categorías.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, tag) in tags.indexed) ...[
                  if (index > 0) Divider(indent: 68, color: colors.border),
                  Semantics(
                    button: true,
                    hint: 'Opciones',
                    child: Pressable(
                      onTap: () => onMenu(tag),
                      pressedOpacity: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          CarliSpace.s16,
                          CarliSpace.s12,
                          CarliSpace.s8,
                          CarliSpace.s12,
                        ),
                        child: Row(
                          spacing: CarliSpace.s12,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: colors.primarySoft, shape: BoxShape.circle),
                              child: CarliIcon(carliIconNamed('hash'), size: 20, color: colors.brandInk),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#${tag.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: CarliType.body.copyWith(fontWeight: FontWeight.w500, color: colors.text),
                                  ),
                                  Text(
                                    _movementsLabel(tag.transactionsCount),
                                    style: CarliType.small.copyWith(color: colors.text2),
                                  ),
                                ],
                              ),
                            ),
                            Semantics(
                              container: true,
                              child: CarliButton.icon(
                                icon: carliIconNamed('ellipsis'),
                                semanticLabel: 'Opciones de #${tag.name}',
                                size: CarliButtonSize.sm,
                                onPressed: () => onMenu(tag),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return CarliCard(
      child: Column(
        spacing: CarliSpace.s16,
        children: [
          for (var index = 0; index < rows; index++)
            const Row(
              spacing: CarliSpace.s12,
              children: [
                CarliSkeleton.circle(size: 40),
                Expanded(child: CarliSkeleton(height: 16)),
              ],
            ),
        ],
      ),
    );
  }
}
