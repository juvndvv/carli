import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/category_picker.dart';
import '../../../ui/date_picker.dart';
import '../../../ui/field.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/money_input.dart';
import '../../../ui/pressable.dart';
import '../../../ui/segmented.dart';
import '../../../ui/select.dart';
import '../../../ui/switch.dart';
import '../../../ui/toast.dart';
import '../../../core/format/dates.dart';
import '../data/finance_providers.dart';
import '../data/json.dart';
import '../data/models.dart';
import '../data/quick_categories.dart';
import '../data/recent_categories.dart';
import '../data/similar_categorization.dart';
import '../data/transaction_form.dart';
import '../data/transactions_repository.dart';
import '../ui/transaction_extras.dart';

class TransactionPreset {
  const TransactionPreset({this.kind = TransactionKind.expense, this.accountId, this.categoryId});

  final TransactionKind kind;
  final String? accountId;
  final String? categoryId;
}

sealed class SheetResult {
  const SheetResult();
}

final class SheetSaved extends SheetResult {
  const SheetSaved();
}

final class SheetDeleted extends SheetResult {
  const SheetDeleted();
}

final class SheetDuplicate extends SheetResult {
  const SheetDuplicate(this.transaction);

  final Transaction transaction;
}

Future<void> showTransactionSheet(
  BuildContext context, {
  Transaction? transaction,
  Transaction? duplicateOf,
  TransactionPreset preset = const TransactionPreset(),
}) async {
  final result = await showModalBottomSheet<SheetResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.94,
      child: TransactionSheet(transaction: transaction, duplicateOf: duplicateOf, preset: preset),
    ),
  );
  if (result is SheetDuplicate && context.mounted) {
    await showTransactionSheet(context, duplicateOf: result.transaction);
  }
}

String withPeriodsNotice(String message, bool periodsChanged) =>
    periodsChanged ? '$message · periodos recalculados' : message;

class TransactionSheet extends ConsumerStatefulWidget {
  const TransactionSheet({super.key, this.transaction, this.duplicateOf, this.preset = const TransactionPreset()});

  final Transaction? transaction;
  final Transaction? duplicateOf;
  final TransactionPreset preset;

  @override
  ConsumerState<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<TransactionSheet> {
  final _payee = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  final _tagDraft = TextEditingController();
  List<String> _tags = [];
  var _shareEnabled = false;
  var _shareMode = ShareMode.equal;
  var _includeSelf = true;
  final List<ShareDraft> _shares = [];
  var _sharesDirty = false;
  var _splitEnabled = false;
  final List<SplitDraft> _splits = [];
  var _splitsDirty = false;

  late TransactionKind _kind;
  int? _amount;
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  late DateTime _date;
  var _pending = false;
  var _showMore = false;
  var _showAllCategories = false;
  var _categoryTouched = false;
  var _accountTouched = false;
  var _submitted = false;
  var _saving = false;
  var _deleting = false;
  String? _error;
  String? _suggestion;
  List<PayeeSuggestion> _suggestions = const [];
  Timer? _payeeTimer;

  Transaction? get _original => widget.transaction;
  bool get _editing => _original != null;
  bool get _fromBank => _original?.fromBank ?? false;
  bool get _splitting => _splitEnabled && _kind != TransactionKind.adjustment && _kind != TransactionKind.transfer;
  bool get _sharesLocked => _original?.sharesLocked ?? false;
  CategoryKind get _categoryKind => _kind == TransactionKind.income ? CategoryKind.income : CategoryKind.expense;

  @override
  void initState() {
    super.initState();
    final source = widget.transaction ?? widget.duplicateOf;
    if (source == null) {
      _kind = widget.preset.kind;
      _accountId = widget.preset.accountId;
      _categoryId = widget.preset.categoryId;
      _date = today();
      _accountTouched = widget.preset.accountId != null;
      return;
    }
    final transfer = source.kind == TransactionKind.transfer;
    final outgoing = !transfer || source.amountCents < 0;
    _kind = source.kind;
    _amount = source.amountCents.abs();
    _categoryId = source.categoryId;
    _accountId = transfer && !outgoing ? source.transferAccountId : source.accountId;
    _toAccountId = transfer ? (outgoing ? source.transferAccountId : source.accountId) : null;
    _date = widget.duplicateOf != null ? today() : source.date;
    _payee.text = source.payee ?? '';
    _description.text = source.description ?? '';
    _notes.text = source.notes ?? '';
    _pending = widget.duplicateOf == null && source.status == TransactionStatus.pending;
    _tags = [...source.tags];
    _splitEnabled = source.isSplit;
    _splits.addAll([
      for (final split in source.splits) SplitDraft(categoryId: split.categoryId, amount: split.amountCents.abs()),
    ]);
    _shareEnabled = source.shares.isNotEmpty;
    _shareMode = ShareMode.amount;
    _shares.addAll([
      for (final share in source.shares)
        ShareDraft(contactId: share.contactId, name: share.name, amount: share.amountCents),
    ]);
    if (widget.duplicateOf != null) {
      _sharesDirty = true;
      _splitsDirty = true;
    }
    _showMore =
        (source.description?.isNotEmpty ?? false) ||
        (source.notes?.isNotEmpty ?? false) ||
        source.tags.isNotEmpty ||
        source.isSplit ||
        source.shares.isNotEmpty;
    _accountTouched = true;
    _categoryTouched = true;
  }

  @override
  void dispose() {
    _payeeTimer?.cancel();
    _payee.dispose();
    _description.dispose();
    _notes.dispose();
    _tagDraft.dispose();
    super.dispose();
  }

  void _setKind(TransactionKind kind) {
    final categories = ref.read(categoriesProvider).value;
    final category = categories?.find(_categoryId);
    setState(() {
      _kind = kind;
      if (category != null && category.category.kind != _categoryKind) _categoryId = null;
      _suggestion = null;
      _suggestions = const [];
      _showAllCategories = false;
      if (kind != TransactionKind.expense) _shareEnabled = false;
      if (kind == TransactionKind.transfer && _toAccountId == null) {
        _toAccountId = ref.read(accountsProvider).value?.active.where((a) => a.id != _accountId).firstOrNull?.id;
      }
    });
  }

  void _searchPayees(String query) {
    _payeeTimer?.cancel();
    setState(() => _suggestion = null);
    if (query.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _payeeTimer = Timer(const Duration(milliseconds: 200), () async {
      try {
        final found = await ref.read(transactionsRepositoryProvider).suggestPayees(query, _categoryKind);
        if (mounted) setState(() => _suggestions = found);
      } on Object {
        if (mounted) setState(() => _suggestions = const []);
      }
    });
  }

  void _applySuggestion(PayeeSuggestion suggestion) {
    _payee.text = suggestion.payee;
    setState(() {
      _suggestions = const [];
      final category = suggestion.category;
      if (category != null && category.kind == _categoryKind && (!_categoryTouched || _categoryId == null)) {
        _categoryId = category.id;
        _suggestion = category.name;
      }
    });
  }

  void _addTags() {
    final additions = parseTagInput(_tagDraft.text);
    _tagDraft.clear();
    if (additions.isEmpty) return;
    setState(() => _tags = {..._tags, ...additions}.toList());
  }

  List<SharePreview> _sharePreview(Cents amount) => previewShares(amount, _shareMode, _includeSelf, _shares);

  bool _shareOverflow(Cents amount) =>
      _sharePreview(amount).fold<int>(0, (sum, item) => sum + item.amount) > amount.abs();

  void _toggleShare(ContactOption contact) => setState(() {
    _sharesDirty = true;
    final index = _shares.indexWhere((share) => share.contactId == contact.id);
    if (index >= 0) {
      _shares.removeAt(index);
    } else {
      _shares.add(ShareDraft(contactId: contact.id, name: contact.name, percentage: _shares.isEmpty ? 50 : null));
    }
  });

  void _setSplitEnabled(bool enabled) => setState(() {
    _splitEnabled = enabled;
    _splitsDirty = true;
    if (enabled && _splits.isEmpty) {
      _splits.addAll([SplitDraft(categoryId: _categoryId, amount: _amount), SplitDraft()]);
    }
  });

  String? get _transferError {
    if (_toAccountId == null) return 'Elige la cuenta de destino.';
    return _toAccountId == _accountId ? 'Elige dos cuentas distintas.' : null;
  }

  String? _trimmed(TextEditingController controller) => controller.text.trim().isEmpty ? null : controller.text.trim();

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    final amount = _amount;
    if (amount == null || amount <= 0) return;
    if (_kind == TransactionKind.transfer && !_editing && _transferError != null) return;
    if (_kind != TransactionKind.transfer && _accountId == null) return;

    setState(() => _saving = true);
    final repository = ref.read(transactionsRepositoryProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    final offerSimilar = ref.read(similarCategorizationProvider);
    final status = _pending ? TransactionStatus.pending.api : TransactionStatus.cleared.api;
    _addTags();
    final tags = _tags;
    if (_splitting && splitRemaining(amount, _splits) != 0) {
      setState(() {
        _saving = false;
        _error = 'El reparto entre categorías debe sumar el importe total.';
      });
      return;
    }
    if (_kind == TransactionKind.expense && _shareEnabled && _shareOverflow(amount)) {
      setState(() {
        _saving = false;
        _error = 'La parte compartida supera el importe del gasto.';
      });
      return;
    }
    try {
      if (_kind == TransactionKind.transfer) {
        final common = <String, dynamic>{
          'amount_cents': amount,
          'date': isoDate(_date),
          'description': _trimmed(_description),
          'notes': _trimmed(_notes),
          'status': status,
          'tags': tags,
        };
        if (_original case final original?) {
          final saved = await repository.update(original.id, common);
          _close(const SheetSaved());
          toasts.show(withPeriodsNotice('Cambios guardados', saved.periodsChanged));
        } else {
          final created = await repository.transfer({
            ...common,
            'from_account_id': _accountId,
            'to_account_id': _toAccountId,
          });
          _close(const SheetSaved());
          toasts.withUndo('Movimiento guardado', () => repository.remove(created.id));
        }
        return;
      }

      final Json input = {
        'account_id': _accountId,
        'kind': _kind.api,
        'amount_cents': signedAmount(_kind, amount),
        'date': isoDate(_date),
        'category_id': _splitting || _kind == TransactionKind.adjustment ? null : _categoryId,
        'payee': _kind == TransactionKind.adjustment ? _original?.payee : _trimmed(_payee),
        'description': _trimmed(_description),
        'notes': _trimmed(_notes),
        'status': status,
        'tags': tags,
      };
      if (_original == null || _splitsDirty) {
        if (_splitting) {
          input['splits'] = toSplitInputs(_kind, _splits);
        } else if (_original?.isSplit ?? false) {
          input['splits'] = null;
        }
      }
      if (!_sharesLocked && (_original == null || _sharesDirty)) {
        final sharing = _kind == TransactionKind.expense && _shareEnabled && _shares.isNotEmpty;
        if (sharing) {
          input['shares'] = toSharesInput(_shareMode, _includeSelf, _shares);
        } else if (_original?.shares.isNotEmpty ?? false) {
          input['shares'] = null;
        }
      }
      if (_categoryId case final category? when !_splitting && _kind != TransactionKind.adjustment) {
        ref.read(recentCategoriesProvider.notifier).remember(_categoryKind, category);
      }
      if (_original case final original?) {
        final saved = await repository.update(original.id, input);
        _close(const SheetSaved());
        toasts.show(withPeriodsNotice('Cambios guardados', saved.periodsChanged));
        if (categorizedImport(_original, saved.value)) offerSimilar(saved.value.id, saved.value.categoryId!).ignore();
      } else {
        final saved = await repository.create(input);
        _close(const SheetSaved());
        toasts.withUndo(withPeriodsNotice('Movimiento guardado', saved.periodsChanged), () async {
          if (await repository.remove(saved.value.id)) {
            toasts.show(withPeriodsNotice('Movimiento deshecho', true));
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido guardar el movimiento.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final original = _original;
    if (original == null) return;
    setState(() => _deleting = true);
    final repository = ref.read(transactionsRepositoryProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      final periodsChanged = await repository.remove(original.id);
      _close(const SheetDeleted());
      final base = original.kind == TransactionKind.transfer ? 'Transferencia eliminada' : 'Movimiento eliminado';
      toasts.withUndo(withPeriodsNotice(base, periodsChanged), () async {
        final restored = await repository.restore(original.id);
        if (restored.periodsChanged) toasts.show(withPeriodsNotice('Movimiento restaurado', true));
      });
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido eliminar el movimiento.'));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _close(SheetResult result) {
    if (mounted) Navigator.of(context).pop(result);
  }

  List<CarliSegment<TransactionKind>> get _kindSegments {
    if (_original?.kind == TransactionKind.transfer) {
      return const [CarliSegment(TransactionKind.transfer, 'Transferencia')];
    }
    if (_original?.kind == TransactionKind.adjustment) {
      return const [CarliSegment(TransactionKind.adjustment, 'Ajuste')];
    }
    return [
      const CarliSegment(TransactionKind.expense, 'Gasto'),
      const CarliSegment(TransactionKind.income, 'Ingreso'),
      if (!_editing) const CarliSegment(TransactionKind.transfer, 'Transferencia'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accounts = ref.watch(accountsProvider).value;
    final categories = ref.watch(categoriesProvider).value;
    final settings = ref.watch(financeSettingsProvider).value;
    final recents = ref.watch(recentCategoriesProvider);

    if (!_accountTouched && !_editing && _accountId == null && accounts != null) {
      final active = accounts.active;
      _accountId = active.where((a) => a.id == settings?.preferredAccountId).firstOrNull?.id ?? active.firstOrNull?.id;
    }

    final involved = {_original?.accountId, _original?.transferAccountId};
    final accountOptions = [
      for (final account in accounts?.all ?? const <Account>[])
        if (!account.archived || involved.contains(account.id))
          CarliOption(
            account.id,
            account.name,
            icon: carliIconNamed(account.icon ?? accountTypeIconName(account.type)),
          ),
    ];

    final selectable = categories?.selectable(_categoryKind) ?? const <CategoryEntry>[];
    final hasMore = selectable.length > quickCategoryCount;
    final shown = _showAllCategories || !hasMore
        ? selectable
        : quickCategoryEntries(
            selectable,
            recents[_categoryKind] ?? const [],
            quickCategoryCount,
            selectedId: _categoryId,
          );

    final amountInvalid = _submitted && (_amount == null || _amount! <= 0);
    final title = !_editing
        ? 'Nuevo movimiento'
        : (_kind == TransactionKind.transfer ? 'Editar transferencia' : 'Editar movimiento');

    return Column(
      children: [
        _Header(title: title, saving: _saving, onCancel: () => Navigator.of(context).pop(), onSave: _save),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              CarliSpace.s16,
              CarliSpace.s8,
              CarliSpace.s16,
              CarliSpace.s32 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              if (_fromBank)
                Padding(
                  padding: const EdgeInsets.only(bottom: CarliSpace.s12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: CarliSpace.s8,
                    children: [
                      CarliIcon(carliIconNamed('landmark'), size: 14, color: colors.text3),
                      Expanded(
                        child: Text(
                          '${_original!.bankName == null ? 'Importado del banco' : 'Importado de ${_original!.bankName}'}. '
                          'Importe, fecha y cuenta vienen del banco. Si lo eliminas, no volverá en la siguiente sincronización.',
                          style: CarliType.small.copyWith(color: colors.text3),
                        ),
                      ),
                    ],
                  ),
                ),
              IgnorePointer(
                ignoring: _fromBank,
                child: CarliSegmented<TransactionKind>(segments: _kindSegments, value: _kind, onChanged: _setKind),
              ),
              const SizedBox(height: CarliSpace.s8),
              IgnorePointer(
                ignoring: _fromBank,
                child: CarliMoneyInput(
                  key: ValueKey(_kind),
                  value: _amount,
                  autofocus: !_editing,
                  allowNegative: _kind == TransactionKind.adjustment,
                  sign: switch (_kind) {
                    TransactionKind.expense => MoneyInputSign.negative,
                    TransactionKind.income => MoneyInputSign.positive,
                    _ => MoneyInputSign.none,
                  },
                  onChanged: (value) => setState(() => _amount = value),
                ),
              ),
              if (amountInvalid)
                Text(
                  'Introduce un importe mayor que 0.',
                  textAlign: TextAlign.center,
                  style: CarliType.small.copyWith(color: colors.negative),
                ),
              const SizedBox(height: CarliSpace.s16),
              if (_kind == TransactionKind.transfer) ...[
                CarliField(
                  label: 'Desde',
                  child: IgnorePointer(
                    ignoring: _editing,
                    child: CarliSelect<String>(
                      title: 'Cuenta de origen',
                      placeholder: 'Cuenta de origen',
                      options: accountOptions,
                      value: _accountId,
                      onChanged: (id) => setState(() => _accountId = id),
                    ),
                  ),
                ),
                const SizedBox(height: CarliSpace.s16),
                CarliField(
                  label: 'Hacia',
                  error: _submitted && !_editing ? _transferError : null,
                  child: IgnorePointer(
                    ignoring: _editing,
                    child: CarliSelect<String>(
                      title: 'Cuenta de destino',
                      placeholder: 'Cuenta de destino',
                      options: accountOptions,
                      value: _toAccountId,
                      invalid: _submitted && !_editing && _transferError != null,
                      onChanged: (id) => setState(() => _toAccountId = id),
                    ),
                  ),
                ),
              ] else ...[
                if (_kind != TransactionKind.adjustment) ...[
                  if (!_splitting)
                    CarliField(
                      label: 'Categoría',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: CarliSpace.s8,
                        children: [
                          CarliCategoryPicker(
                            categories: [
                              for (final entry in shown)
                                CarliCategory(
                                  id: entry.category.id,
                                  name: entry.category.name,
                                  icon: carliIconNamed(entry.icon),
                                ),
                            ],
                            value: _categoryId,
                            onChanged: (id) => setState(() {
                              _categoryId = id;
                              _categoryTouched = true;
                              _suggestion = null;
                            }),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _suggestion == null
                                    ? const SizedBox.shrink()
                                    : Row(
                                        spacing: CarliSpace.s4,
                                        children: [
                                          CarliIcon(carliIconNamed('sparkles'), size: 13, color: colors.text3),
                                          Flexible(
                                            child: Text(
                                              'Sugerida: $_suggestion (por usos anteriores)',
                                              style: CarliType.caption.copyWith(color: colors.text3),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              if (hasMore)
                                TextButton(
                                  onPressed: () => setState(() => _showAllCategories = !_showAllCategories),
                                  child: Text(_showAllCategories ? 'Ver menos' : 'Ver todas'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: CarliSpace.s16),
                ],
                CarliField(
                  label: 'Cuenta',
                  error: _submitted && _accountId == null ? 'Elige una cuenta.' : null,
                  child: IgnorePointer(
                    ignoring: _fromBank,
                    child: CarliSelect<String>(
                      title: 'Cuenta',
                      placeholder: 'Elige una cuenta',
                      options: accountOptions,
                      value: _accountId,
                      invalid: _submitted && _accountId == null,
                      onChanged: (id) => setState(() {
                        _accountId = id;
                        _accountTouched = true;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: CarliSpace.s16),
                if (_kind != TransactionKind.adjustment) ...[
                  CarliField(
                    label: _kind == TransactionKind.income ? 'Pagador o concepto' : 'Comercio o concepto',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CarliInput(
                          controller: _payee,
                          placeholder: _kind == TransactionKind.income ? 'Ej. Acme S.L.' : 'Ej. Mercadona',
                          onChanged: _searchPayees,
                          textInputAction: TextInputAction.done,
                        ),
                        for (final suggestion in _suggestions.take(4))
                          _SuggestionRow(suggestion: suggestion, onTap: () => _applySuggestion(suggestion)),
                      ],
                    ),
                  ),
                  const SizedBox(height: CarliSpace.s16),
                ],
              ],
              CarliField(
                label: 'Fecha',
                child: IgnorePointer(
                  ignoring: _fromBank,
                  child: CarliDatePicker(value: _date, onChanged: (date) => setState(() => _date = date)),
                ),
              ),
              const SizedBox(height: CarliSpace.s12),
              Semantics(
                button: true,
                expanded: _showMore,
                child: Pressable(
                  onTap: () => setState(() => _showMore = !_showMore),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: CarliSpace.s8),
                    child: Row(
                      spacing: CarliSpace.s4,
                      children: [
                        CarliIcon(
                          carliIconNamed(_showMore ? 'chevron-up' : 'chevron-down'),
                          size: 16,
                          color: colors.text2,
                        ),
                        Flexible(
                          child: Text(switch (_kind) {
                            TransactionKind.expense => 'Más opciones: etiquetas, nota, compartir, dividir',
                            TransactionKind.income => 'Más opciones: etiquetas, nota, dividir',
                            _ => 'Más opciones: concepto, etiquetas, nota',
                          }, style: CarliType.small.copyWith(fontWeight: FontWeight.w600, color: colors.text2)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showMore) ...[
                const SizedBox(height: CarliSpace.s8),
                CarliField(
                  label: 'Concepto',
                  child: CarliInput(controller: _description, placeholder: 'Opcional'),
                ),
                const SizedBox(height: CarliSpace.s16),
                CarliField(
                  label: 'Etiquetas',
                  child: TagEditor(
                    tags: _tags,
                    controller: _tagDraft,
                    suggestions: [
                      for (final tag in ref.watch(tagsProvider).value ?? const <Tag>[])
                        if (!_tags.contains(tag.name)) tag.name,
                    ],
                    onAdd: _addTags,
                    onPick: (name) => setState(() => _tags = [..._tags, name]),
                    onRemove: (name) => setState(() => _tags = [..._tags]..remove(name)),
                  ),
                ),
                const SizedBox(height: CarliSpace.s16),
                CarliField(
                  label: 'Nota',
                  child: CarliInput(controller: _notes, maxLines: null),
                ),
                const SizedBox(height: CarliSpace.s12),
                Row(
                  children: [
                    Expanded(
                      child: Text('Pendiente de confirmar', style: CarliType.body.copyWith(color: colors.text)),
                    ),
                    CarliSwitch(
                      value: _pending,
                      semanticLabel: 'Pendiente de confirmar',
                      onChanged: (value) => setState(() => _pending = value),
                    ),
                  ],
                ),
                if (_kind == TransactionKind.expense) ...[
                  SwitchRow(
                    label: 'Gasto compartido',
                    value: _shareEnabled,
                    onChanged: _sharesLocked
                        ? null
                        : (value) => setState(() {
                            _shareEnabled = value;
                            _sharesDirty = true;
                          }),
                  ),
                  if (_shareEnabled)
                    SharesPanel(
                      locked: _sharesLocked,
                      lockedShares: _original?.shares ?? const [],
                      contacts: [
                        for (final contact in ref.watch(contactOptionsProvider).value ?? const <ContactOption>[])
                          if (!contact.archived) contact,
                      ],
                      mode: _shareMode,
                      includeSelf: _includeSelf,
                      shares: _shares,
                      preview: _sharePreview(_amount ?? 0),
                      total: _amount ?? 0,
                      onMode: (mode) => setState(() {
                        _shareMode = mode;
                        _sharesDirty = true;
                      }),
                      onIncludeSelf: (value) => setState(() {
                        _includeSelf = value;
                        _sharesDirty = true;
                      }),
                      onToggle: _toggleShare,
                      onChanged: () => setState(() => _sharesDirty = true),
                    ),
                ],
                if (_kind == TransactionKind.expense || _kind == TransactionKind.income) ...[
                  SwitchRow(label: 'Dividir en varias categorías', value: _splitEnabled, onChanged: _setSplitEnabled),
                  if (_splitEnabled)
                    SplitsPanel(
                      splits: _splits,
                      remaining: splitRemaining(_amount ?? 0, _splits),
                      categories: [
                        for (final entry in selectable)
                          CarliOption(entry.category.id, entry.label, icon: carliIconNamed(entry.icon)),
                      ],
                      onChanged: () => setState(() => _splitsDirty = true),
                      onAdd: () => setState(() {
                        _splits.add(SplitDraft());
                        _splitsDirty = true;
                      }),
                      onRemove: (index) => setState(() {
                        _splits.removeAt(index);
                        _splitsDirty = true;
                        if (_splits.isEmpty) _splitEnabled = false;
                      }),
                    ),
                ],
              ],
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: CarliSpace.s12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(error, style: CarliType.small.copyWith(color: colors.negative)),
                  ),
                ),
              if (_editing) ...[
                const SizedBox(height: CarliSpace.s24),
                CarliButton(
                  label: 'Duplicar',
                  icon: carliIconNamed('copy'),
                  variant: CarliButtonVariant.secondary,
                  size: CarliButtonSize.md,
                  onPressed: () => _close(SheetDuplicate(_original!)),
                ),
                const SizedBox(height: CarliSpace.s8),
                CarliButton(
                  label: _kind == TransactionKind.transfer ? 'Eliminar transferencia' : 'Eliminar movimiento',
                  icon: carliIconNamed('trash'),
                  variant: CarliButtonVariant.danger,
                  size: CarliButtonSize.md,
                  loading: _deleting,
                  onPressed: _delete,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String accountTypeIconName(AccountType type) => switch (type) {
  AccountType.checking => 'landmark',
  AccountType.savings => 'piggy-bank',
  AccountType.creditCard => 'credit-card',
  AccountType.cash => 'banknote',
};

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.saving, required this.onCancel, required this.onSave});

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

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion, required this.onTap});

  final PayeeSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4, vertical: 10),
          child: Row(
            spacing: CarliSpace.s8,
            children: [
              CarliIcon(carliIconNamed('search'), size: 14, color: colors.text3),
              Expanded(
                child: Text(suggestion.payee, style: CarliType.body.copyWith(color: colors.text)),
              ),
              if (suggestion.category case final category?)
                Text(category.name, style: CarliType.small.copyWith(color: colors.text3)),
            ],
          ),
        ),
      ),
    );
  }
}
