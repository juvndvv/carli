import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/field.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/money_input.dart';
import '../../../../ui/pressable.dart';
import '../../../../ui/select.dart';
import '../../../../ui/switch.dart';
import '../../data/accounts_admin.dart';
import '../../data/models.dart';
import '../transaction_tools.dart';

Future<Account?> showAccountForm(BuildContext context, {Account? account}) => showModalBottomSheet<Account>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (context) => FractionallySizedBox(heightFactor: 0.94, child: AccountFormSheet(account: account)),
);

int? _dayOf(String text) => int.tryParse(text.trim());

bool _validDay(String text) {
  if (text.trim().isEmpty) return true;
  final day = _dayOf(text);
  return day != null && day >= 1 && day <= 31;
}

class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({super.key, this.account});

  final Account? account;

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  late final Account? _account = widget.account;
  late final _name = TextEditingController(text: _account?.name ?? '');
  late final _statementDay = TextEditingController(text: _account?.statementDay?.toString() ?? '');
  late final _paymentDay = TextEditingController(text: _account?.paymentDay?.toString() ?? '');
  late var _type = _account?.type ?? AccountType.checking;
  late Cents? _initialBalance = _account?.initialBalanceCents ?? 0;
  late DateTime? _initialDate = _account == null ? today() : _account.initialBalanceDate;
  late Cents? _creditLimit = _account?.creditLimitCents;
  late String? _icon = _account == null ? AccountType.checking.icon : _account.icon;
  late String? _color = _account?.color;
  late var _includeInNetWorth = _account?.includeInNetWorth ?? true;
  var _submitted = false;
  var _saving = false;
  String? _error;

  bool get _isCard => _type == AccountType.creditCard;

  bool get _nameInvalid => _name.text.trim().isEmpty || _name.text.trim().length > 120;

  @override
  void dispose() {
    _name.dispose();
    _statementDay.dispose();
    _paymentDay.dispose();
    super.dispose();
  }

  void _changeType(AccountType type) => setState(() {
    final defaults = AccountType.values.map((type) => type.icon).toSet();
    if (_icon == null || defaults.contains(_icon)) _icon = type.icon;
    _type = type;
  });

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_nameInvalid || !_validDay(_statementDay.text) || !_validDay(_paymentDay.text)) return;
    final input = AccountInput(
      name: _name.text,
      type: _type,
      initialBalanceCents: _initialBalance ?? 0,
      initialBalanceDate: _initialDate,
      creditLimitCents: _creditLimit,
      statementDay: _dayOf(_statementDay.text),
      paymentDay: _dayOf(_paymentDay.text),
      icon: _icon,
      color: _color,
      includeInNetWorth: _includeInNetWorth,
    );
    setState(() => _saving = true);
    final repository = ref.read(accountsRepositoryProvider);
    try {
      final account = _account;
      final saved = account == null ? await repository.create(input) : await repository.save(account.id, input);
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido guardar la cuenta.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const dayError = 'Elige un día entre el 1 y el 31.';
    return Column(
      children: [
        _FormHeader(
          title: _account == null ? 'Nueva cuenta' : 'Editar cuenta',
          saving: _saving,
          onCancel: () => Navigator.pop(context),
          onSave: _save,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              CarliSpace.s20,
              CarliSpace.s16,
              CarliSpace.s20,
              CarliSpace.s32 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              CarliField(
                label: 'Nombre',
                error: _submitted && _nameInvalid ? 'Ponle un nombre.' : null,
                child: CarliInput(
                  controller: _name,
                  placeholder: 'Ej. Cuenta corriente',
                  invalid: _submitted && _nameInvalid,
                  autofocus: _account == null,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Tipo',
                child: CarliSelect<AccountType>(
                  title: 'Tipo',
                  value: _type,
                  onChanged: _changeType,
                  options: [
                    for (final type in AccountType.values)
                      CarliOption(type, type.label, icon: carliIconNamed(type.icon)),
                  ],
                ),
              ),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Saldo inicial',
                hint: _isCard ? 'En negativo si ya debías algo.' : null,
                child: CarliMoneyInput(
                  value: _initialBalance,
                  appearance: MoneyInputAppearance.field,
                  allowNegative: true,
                  semanticLabel: 'Saldo inicial',
                  onChanged: (value) => _initialBalance = value,
                ),
              ),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Fecha del saldo inicial',
                child: DateField(value: _initialDate, onChanged: (value) => setState(() => _initialDate = value)),
              ),
              if (_isCard) ...[
                const SizedBox(height: CarliSpace.s16),
                CarliField(
                  label: 'Límite de crédito',
                  child: CarliMoneyInput(
                    value: _creditLimit,
                    appearance: MoneyInputAppearance.field,
                    semanticLabel: 'Límite de crédito',
                    onChanged: (value) => _creditLimit = value,
                  ),
                ),
                const SizedBox(height: CarliSpace.s16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: CarliSpace.s12,
                  children: [
                    Expanded(
                      child: CarliField(
                        label: 'Día de corte',
                        error: _submitted && !_validDay(_statementDay.text) ? dayError : null,
                        child: _DayInput(controller: _statementDay, onChanged: () => setState(() {})),
                      ),
                    ),
                    Expanded(
                      child: CarliField(
                        label: 'Día de cargo',
                        error: _submitted && !_validDay(_paymentDay.text) ? dayError : null,
                        child: _DayInput(controller: _paymentDay, onChanged: () => setState(() {})),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: CarliSpace.s20),
              Text(
                'Icono',
                style: CarliType.small.copyWith(fontWeight: FontWeight.w600, color: colors.text2),
              ),
              const SizedBox(height: CarliSpace.s8),
              Wrap(
                spacing: CarliSpace.s8,
                runSpacing: CarliSpace.s8,
                children: [
                  for (final icon in accountIconChoices)
                    _IconChoice(icon: icon, selected: _icon == icon, onTap: () => setState(() => _icon = icon)),
                ],
              ),
              const SizedBox(height: CarliSpace.s20),
              Text(
                'Color en gráficos',
                style: CarliType.small.copyWith(fontWeight: FontWeight.w600, color: colors.text2),
              ),
              const SizedBox(height: CarliSpace.s8),
              Wrap(
                spacing: CarliSpace.s8,
                runSpacing: CarliSpace.s8,
                children: [
                  for (final (index, color) in accountColorChoices.indexed)
                    _ColorChoice(
                      color: colors.chart[index],
                      label: 'Color ${index + 1}',
                      selected: _color == color,
                      onTap: () => setState(() => _color = color),
                    ),
                ],
              ),
              const SizedBox(height: CarliSpace.s20),
              Row(
                spacing: CarliSpace.s12,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sumar al patrimonio neto', style: CarliType.body.copyWith(color: colors.text)),
                        Text(
                          'Desactívalo para dinero que no es tuyo.',
                          style: CarliType.small.copyWith(color: colors.text3),
                        ),
                      ],
                    ),
                  ),
                  CarliSwitch(
                    value: _includeInNetWorth,
                    semanticLabel: 'Sumar al patrimonio neto',
                    onChanged: (value) => setState(() => _includeInNetWorth = value),
                  ),
                ],
              ),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: CarliSpace.s16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(error, style: CarliType.small.copyWith(color: colors.negative)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayInput extends StatelessWidget {
  const _DayInput({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => CarliInput(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
    invalid: !_validDay(controller.text),
    onChanged: (_) => onChanged(),
  );
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({required this.icon, required this.selected, required this.onTap});

  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: icon,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? colors.primary : colors.surface2, shape: BoxShape.circle),
          child: CarliIcon(carliIconNamed(icon), size: 20, color: selected ? colors.onPrimary : colors.text),
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({required this.color, required this.label, required this.selected, required this.onTap});

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? colors.text : Colors.transparent, width: 2),
          ),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
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
