import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/pending/pending_models.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../modules/finance/data/finance_providers.dart';
import '../../modules/finance/data/models.dart';
import '../../modules/finance/data/quick_categories.dart';
import '../../modules/finance/data/recent_categories.dart';
import '../../modules/finance/data/recurring.dart';
import '../../modules/finance/data/similar_categorization.dart';
import '../../modules/finance/data/transactions_repository.dart';
import '../../modules/finance/screens/recurring/confirm_occurrence_sheet.dart';
import '../../ui/button.dart';
import '../../ui/category_picker.dart';
import '../../ui/icon_names.dart';
import '../../ui/sheet.dart';
import '../../ui/skeleton.dart';
import '../../ui/toast.dart';

String pendingTransactionId(PendingItem item) => item.metaString('transaction_id') ?? item.id;

CategoryKind pendingCategoryKind(PendingItem item) => CategoryKind.of(item.metaString('kind'));

typedef ChosenCategory = ({String id, String label});

class CategorizePendingAction extends ConsumerWidget {
  const CategorizePendingAction({super.key, required this.item, required this.onResolved});

  final PendingItem item;
  final ValueChanged<PendingItem> onResolved;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(transactionsRepositoryProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    final offerSimilar = ref.read(similarCategorizationProvider);
    final transactionId = pendingTransactionId(item);
    final chosen = await showCarliSheet<ChosenCategory>(
      context,
      title: 'Elegir categoría',
      builder: (context) => CategorizePendingSheet(item: item),
    );
    if (chosen == null) return;
    onResolved(item);
    final message = '${item.title} → ${chosen.label}';
    if (item.metaString('source') == 'bank') {
      toasts.withUndo(message, () async {
        try {
          await repository.update(transactionId, {'category_id': null});
        } catch (error) {
          toasts.error(apiErrorMessage(error, fallback: 'No se ha podido deshacer.'));
        }
      });
    } else {
      toasts.show(message);
    }
    await offerSimilar(transactionId, chosen.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => CarliButton(
    label: 'Elegir categoría',
    icon: carliIconNamed('tag'),
    variant: CarliButtonVariant.secondary,
    size: CarliButtonSize.sm,
    block: false,
    onPressed: () => _open(context, ref),
  );
}

class CategorizePendingSheet extends ConsumerStatefulWidget {
  const CategorizePendingSheet({super.key, required this.item});

  final PendingItem item;

  @override
  ConsumerState<CategorizePendingSheet> createState() => _CategorizePendingSheetState();
}

class _CategorizePendingSheetState extends ConsumerState<CategorizePendingSheet> {
  var _showAll = false;
  var _saving = false;
  String? _chosen;

  CategoryKind get _kind => pendingCategoryKind(widget.item);

  Future<void> _choose(CategoryIndex index, String categoryId) async {
    if (_saving) return;
    final toasts = ref.read(toastControllerProvider.notifier);
    setState(() {
      _chosen = categoryId;
      _saving = true;
    });
    try {
      await ref.read(transactionsRepositoryProvider).update(pendingTransactionId(widget.item), {
        'category_id': categoryId,
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _chosen = null;
          _saving = false;
        });
      }
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido guardar la categoría.'));
      return;
    }
    if (!mounted) return;
    ref.read(recentCategoriesProvider.notifier).remember(_kind, categoryId);
    final label = index.find(categoryId)?.label ?? 'la categoría elegida';
    Navigator.of(context).pop<ChosenCategory>((id: categoryId, label: label));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final categories = ref.watch(categoriesProvider);
    final recents = ref.watch(recentCategoriesProvider);
    final index = categories.value;

    final Widget body;
    if (index != null) {
      final selectable = index.selectable(_kind);
      final hasMore = selectable.length > quickCategoryCount;
      final shown = _showAll || !hasMore
          ? selectable
          : quickCategoryEntries(selectable, recents[_kind] ?? const [], quickCategoryCount, selectedId: _chosen);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s8,
        children: [
          if (selectable.isEmpty)
            Text('No tienes categorías de este tipo todavía.', style: CarliType.small.copyWith(color: colors.text2))
          else
            AnimatedOpacity(
              duration: CarliMotion.hover,
              opacity: _saving ? 0.6 : 1,
              child: IgnorePointer(
                ignoring: _saving,
                child: Semantics(
                  label: 'Categoría para ${widget.item.title}',
                  container: true,
                  child: CarliCategoryPicker(
                    categories: [
                      for (final entry in shown)
                        CarliCategory(
                          id: entry.category.id,
                          name: entry.category.name,
                          icon: carliIconNamed(entry.icon),
                        ),
                    ],
                    value: _chosen,
                    onChanged: (id) => _choose(index, id),
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              if (hasMore)
                TextButton(
                  onPressed: _saving ? null : () => setState(() => _showAll = !_showAll),
                  child: Text(_showAll ? 'Ver menos' : 'Ver todas'),
                ),
            ],
          ),
        ],
      );
    } else if (categories.hasError) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        spacing: CarliSpace.s12,
        children: [
          Text('No se han podido cargar las categorías.', style: CarliType.small.copyWith(color: colors.text2)),
          CarliButton(
            label: 'Reintentar',
            variant: CarliButtonVariant.secondary,
            size: CarliButtonSize.sm,
            block: false,
            onPressed: () => ref.invalidate(categoriesProvider),
          ),
        ],
      );
    } else {
      body = Wrap(
        spacing: CarliSpace.s16,
        runSpacing: CarliSpace.s16,
        children: [for (var i = 0; i < quickCategoryCount; i++) const CarliSkeleton.circle(size: 48)],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(widget.item.title, style: CarliType.small.copyWith(color: colors.text2)),
          body,
        ],
      ),
    );
  }
}

class ConfirmRecurringPendingAction extends ConsumerStatefulWidget {
  const ConfirmRecurringPendingAction({super.key, required this.item, required this.onResolved});

  final PendingItem item;
  final ValueChanged<PendingItem> onResolved;

  @override
  ConsumerState<ConfirmRecurringPendingAction> createState() => _ConfirmRecurringPendingActionState();
}

class _ConfirmRecurringPendingActionState extends ConsumerState<ConfirmRecurringPendingAction> {
  var _loading = false;

  Future<void> _confirm() async {
    final item = widget.item;
    final ruleId = item.metaString('rule_id');
    if (ruleId == null || _loading) return;
    final toasts = ref.read(toastControllerProvider.notifier);
    final onResolved = widget.onResolved;
    setState(() => _loading = true);
    final RecurringRule rule;
    try {
      rule = await ref.read(recurringRepositoryProvider).get(ruleId);
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido cargar el recurrente.'));
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;
    final result = await showConfirmOccurrenceSheet(context, rule: rule);
    if (result != null) onResolved(item);
  }

  @override
  Widget build(BuildContext context) => CarliButton(
    label: 'Confirmar cargo',
    icon: carliIconNamed('check'),
    variant: CarliButtonVariant.secondary,
    size: CarliButtonSize.sm,
    block: false,
    loading: _loading,
    onPressed: _confirm,
  );
}

class TransferSuggestionPendingAction extends ConsumerStatefulWidget {
  const TransferSuggestionPendingAction({super.key, required this.item, required this.onResolved});

  final PendingItem item;
  final ValueChanged<PendingItem> onResolved;

  @override
  ConsumerState<TransferSuggestionPendingAction> createState() => _TransferSuggestionPendingActionState();
}

enum _SuggestionAnswer { confirm, dismiss }

class _TransferSuggestionPendingActionState extends ConsumerState<TransferSuggestionPendingAction> {
  _SuggestionAnswer? _saving;

  Future<void> _answer(_SuggestionAnswer answer) async {
    final item = widget.item;
    final outgoingId = item.metaString('outgoing_transaction_id');
    final incomingId = item.metaString('incoming_transaction_id');
    if (outgoingId == null || incomingId == null || _saving != null) return;
    final repository = ref.read(transactionsRepositoryProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    final onResolved = widget.onResolved;
    setState(() => _saving = answer);
    try {
      if (answer == _SuggestionAnswer.confirm) {
        await repository.confirmTransferSuggestion(outgoingId: outgoingId, incomingId: incomingId);
      } else {
        await repository.dismissTransferSuggestion(outgoingId: outgoingId, incomingId: incomingId);
      }
    } catch (error) {
      if (mounted) setState(() => _saving = null);
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido guardar la respuesta.'));
      return;
    }
    onResolved(item);
    if (answer == _SuggestionAnswer.confirm) {
      toasts.withUndo('Guardada como transferencia', () async {
        try {
          await repository.undoTransfer(outgoingId);
        } catch (error) {
          toasts.error(apiErrorMessage(error, fallback: 'No se ha podido deshacer.'));
        }
      });
    } else {
      toasts.show('Entendido: no es una transferencia');
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: CarliSpace.s8,
    runSpacing: CarliSpace.s8,
    children: [
      CarliButton(
        label: 'Confirmar',
        icon: carliIconNamed('check'),
        variant: CarliButtonVariant.secondary,
        size: CarliButtonSize.sm,
        block: false,
        loading: _saving == _SuggestionAnswer.confirm,
        onPressed: _saving == null ? () => _answer(_SuggestionAnswer.confirm) : null,
      ),
      CarliButton(
        label: 'No es transferencia',
        icon: carliIconNamed('x'),
        variant: CarliButtonVariant.ghost,
        size: CarliButtonSize.sm,
        block: false,
        loading: _saving == _SuggestionAnswer.dismiss,
        onPressed: _saving == null ? () => _answer(_SuggestionAnswer.dismiss) : null,
      ),
    ],
  );
}
