import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../ui/button.dart';
import '../../../../ui/category_picker.dart';
import '../../../../ui/field.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/money_input.dart';
import '../../../../ui/segmented.dart';
import '../../../../ui/select.dart';
import '../../../../ui/sheet.dart';
import '../../../../ui/toast.dart';
import '../../data/finance_providers.dart';
import '../../data/goals.dart';
import '../../data/models.dart';
import '../../ui/transaction_extras.dart';
import '../transaction_tools.dart' show DateField;
import '../../../../ui/full_sheet.dart';

enum GoalSheetOutcome { saved, deleted }

enum ProgressSource { manual, account }

Future<GoalSheetOutcome?> showGoalSheet(BuildContext context, {SavingsGoal? goal}) =>
    showFullSheet<GoalSheetOutcome>(context, (context) => GoalSheet(goal: goal));

List<Account> goalAccountChoices(List<Account> accounts) {
  final active = [
    for (final account in accounts)
      if (!account.archived) account,
  ];
  return [
    ...active.where((account) => account.type == AccountType.savings),
    ...active.where((account) => account.type != AccountType.savings),
  ];
}

class GoalSheet extends ConsumerStatefulWidget {
  const GoalSheet({super.key, this.goal});

  final SavingsGoal? goal;

  @override
  ConsumerState<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<GoalSheet> {
  late final _name = TextEditingController(text: widget.goal?.name ?? '');
  late int? _target = widget.goal?.targetCents;
  late String _icon = widget.goal?.icon ?? defaultGoalIcon;
  late bool _hasDate = widget.goal?.targetDate != null;
  late DateTime _targetDate = widget.goal?.targetDate ?? addMonths(today(), 12);
  late ProgressSource _source = widget.goal?.accountId == null ? ProgressSource.manual : ProgressSource.account;
  late String? _accountId = widget.goal?.accountId;
  var _submitted = false;
  var _saving = false;
  var _deleting = false;
  String? _error;

  SavingsGoal? get _goal => widget.goal;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _effectiveAccountId(List<Account> choices) =>
      _accountId ?? choices.where((account) => account.type == AccountType.savings).firstOrNull?.id;

  Future<void> _save(List<Account> choices) async {
    setState(() => _submitted = true);
    final name = _name.text.trim();
    final target = _target;
    final accountId = _effectiveAccountId(choices);
    if (name.isEmpty || target == null || target <= 0 || (_source == ProgressSource.account && accountId == null)) {
      return;
    }
    final draft = GoalDraft(
      name: name,
      targetCents: target,
      targetDate: _hasDate ? _targetDate : null,
      accountId: _source == ProgressSource.account ? accountId : null,
      icon: _icon,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(goalsRepositoryProvider);
    try {
      if (_goal case final goal?) {
        await repository.update(goal.id, draft);
      } else {
        await repository.create(draft);
      }
      ref.read(toastControllerProvider.notifier).show(_goal == null ? 'Objetivo creado' : 'Objetivo actualizado');
      if (mounted) Navigator.pop(context, GoalSheetOutcome.saved);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido guardar el objetivo.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(SavingsGoal goal) async {
    final confirmed = await confirmCarli(
      context,
      title: '¿Eliminar ${goal.name}?',
      message: 'Se borrará el objetivo y su historial de aportaciones. Tus cuentas y movimientos no cambian.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(goalsRepositoryProvider).remove(goal.id);
      ref.read(toastControllerProvider.notifier).show('${goal.name} eliminado');
      if (mounted) Navigator.pop(context, GoalSheetOutcome.deleted);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido eliminar el objetivo.'));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = goalAccountChoices(ref.watch(accountsProvider).value?.all ?? const []);
    final targetInvalid = _submitted && (_target == null || _target! <= 0);
    final nameInvalid = _submitted && _name.text.trim().isEmpty;
    final accountId = _effectiveAccountId(choices);

    return Column(
      children: [
        FullSheetHeader(
          title: _goal == null ? 'Nuevo objetivo' : 'Editar objetivo',
          onLeading: () => Navigator.pop(context),
          trailing: SaveHeaderAction(saving: _saving, onSave: () => _save(choices)),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              CarliSpace.s16,
              CarliSpace.s8,
              CarliSpace.s16,
              CarliSpace.s32 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              CarliMoneyInput(
                value: _target,
                autofocus: _goal == null,
                semanticLabel: 'Importe meta',
                onChanged: (value) => setState(() => _target = value),
              ),
              targetInvalid ? const FormError('Indica cuánto quieres ahorrar.', center: true) : const SizedBox.shrink(),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Nombre',
                error: nameInvalid ? 'Ponle un nombre al objetivo.' : null,
                child: CarliInput(
                  controller: _name,
                  placeholder: 'Fondo de emergencia, Viaje a Japón…',
                  invalid: nameInvalid,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Icono',
                child: CarliCategoryPicker(
                  categories: [
                    for (final (icon, label) in goalIcons)
                      CarliCategory(id: icon, name: label, icon: carliIconNamed(icon)),
                  ],
                  value: _icon,
                  onChanged: (icon) => setState(() => _icon = icon),
                ),
              ),
              const SizedBox(height: CarliSpace.s8),
              SwitchRow(
                label: 'Tiene fecha objetivo',
                value: _hasDate,
                onChanged: (value) => setState(() => _hasDate = value),
              ),
              if (_hasDate) ...[
                const SizedBox(height: CarliSpace.s12),
                CarliField(
                  label: 'Fecha objetivo',
                  hint: 'Calculamos cuánto aportar cada mes para llegar a tiempo.',
                  child: DateField(
                    value: _targetDate,
                    onChanged: (date) => setState(() {
                      if (date == null) {
                        _hasDate = false;
                      } else {
                        _targetDate = date;
                      }
                    }),
                  ),
                ),
              ],
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Cómo se mide el progreso',
                hint: _source == ProgressSource.account
                    ? 'El progreso es el saldo de la cuenta: ahorra con transferencias a ella.'
                    : 'Registra aportaciones a mano cuando apartes dinero.',
                child: CarliSegmented<ProgressSource>(
                  segments: const [
                    CarliSegment(ProgressSource.manual, 'Aportaciones'),
                    CarliSegment(ProgressSource.account, 'Saldo de una cuenta'),
                  ],
                  value: _source,
                  onChanged: (source) => setState(() => _source = source),
                ),
              ),
              if (_source == ProgressSource.account) ...[
                const SizedBox(height: CarliSpace.s16),
                CarliField(
                  label: 'Cuenta',
                  error: _submitted && accountId == null ? 'Elige una cuenta.' : null,
                  child: CarliSelect<String>(
                    title: 'Cuenta',
                    placeholder: 'Elige una cuenta de ahorro',
                    invalid: _submitted && accountId == null,
                    options: [
                      for (final account in choices)
                        CarliOption(account.id, account.name, icon: carliIconNamed(account.icon ?? account.type.icon)),
                    ],
                    value: accountId,
                    onChanged: (id) => setState(() => _accountId = id),
                  ),
                ),
              ],
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: CarliSpace.s12),
                  child: FormError(error),
                ),
              if (_goal case final goal?) ...[
                const SizedBox(height: CarliSpace.s24),
                CarliButton(
                  label: 'Eliminar',
                  icon: carliIconNamed('trash'),
                  variant: CarliButtonVariant.danger,
                  size: CarliButtonSize.md,
                  loading: _deleting,
                  onPressed: _saving ? null : () => _delete(goal),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
