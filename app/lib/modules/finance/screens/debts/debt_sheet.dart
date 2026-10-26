import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/date_picker.dart';
import '../../../../ui/field.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/money_input.dart';
import '../../../../ui/segmented.dart';
import '../../../../ui/select.dart';
import '../../../../ui/toast.dart';
import '../../data/debts.dart';
import '../../data/finance_providers.dart';
import '../../data/models.dart';
import '../../ui/transaction_extras.dart';
import '../../../../ui/full_sheet.dart';
import '../transaction_tools.dart' show DateField;

const newContact = '__new';

Future<Debt?> showDebtSheet(BuildContext context, {Debt? debt}) =>
    showFullSheet<Debt>(context, (context) => DebtSheet(debt: debt));

String? preferredDebtAccountId(List<Account> accounts) {
  final active = accounts.where((account) => !account.archived).toList();
  return (active.where((account) => account.type == AccountType.checking).firstOrNull ?? active.firstOrNull)?.id;
}

List<CarliOption<String>> debtAccountOptions(List<Account> accounts) => [
  for (final account in accounts)
    if (!account.archived)
      CarliOption(account.id, account.name, icon: carliIconNamed(account.icon ?? account.type.icon)),
];

class DebtSheet extends ConsumerStatefulWidget {
  const DebtSheet({super.key, this.debt});

  final Debt? debt;

  @override
  ConsumerState<DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends ConsumerState<DebtSheet> {
  late var _direction = widget.debt?.direction ?? DebtDirection.iOwe;
  late int? _principal = widget.debt?.principalCents;
  late final _name = TextEditingController(text: widget.debt?.name ?? '');
  late String? _contact = widget.debt?.contactId;
  final _contactName = TextEditingController();
  late var _startDate = widget.debt?.startDate ?? today();
  late var _hasDue = widget.debt?.dueDate != null;
  late var _dueDate = widget.debt?.dueDate ?? addMonths(today(), 1);
  late final _notes = TextEditingController(text: widget.debt?.notes ?? '');
  var _hasPlan = false;
  int? _installment;
  final _count = TextEditingController(text: '12');
  var _firstPaymentDate = addMonths(today(), 1);
  String? _planAccountId;
  String? _planCategoryId;
  var _submitted = false;
  var _saving = false;
  String? _error;

  Debt? get _debt => widget.debt;

  bool get _canPlan => _debt?.recurringRuleId == null;

  bool get _owesMe => _direction == DebtDirection.owedToMe;

  int? get _installmentsCount => int.tryParse(_count.text.trim());

  @override
  void dispose() {
    _name.dispose();
    _contactName.dispose();
    _notes.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _save(List<Account> accounts) async {
    setState(() => _submitted = true);
    final name = _name.text.trim();
    final principal = _principal;
    final planAccountId = _planAccountId ?? preferredDebtAccountId(accounts);
    final count = _installmentsCount;
    final installment = _installment;
    final planInvalid =
        _hasPlan &&
        _canPlan &&
        (installment == null || installment <= 0 || count == null || count < 1 || count > 600 || planAccountId == null);
    final contactInvalid = _contact == newContact && _contactName.text.trim().isEmpty;
    if (name.isEmpty || principal == null || principal <= 0 || planInvalid || contactInvalid) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(debtsRepositoryProvider);
    try {
      final contactId = switch (_contact) {
        newContact => (await repository.createContact(_contactName.text.trim())).id,
        final id => id,
      };
      if (contactId != null && _contact == newContact && mounted) setState(() => _contact = contactId);
      final notes = _notes.text.trim();
      final draft = DebtDraft(
        name: name,
        direction: _direction,
        principalCents: principal,
        startDate: _startDate,
        contactId: contactId,
        dueDate: _hasDue ? _dueDate : null,
        notes: notes.isEmpty ? null : notes,
        plan: _hasPlan && _canPlan
            ? DebtPlanDraft(
                accountId: planAccountId!,
                installmentCents: installment!,
                installmentsCount: count!,
                firstPaymentDate: _firstPaymentDate,
                categoryId: _owesMe ? null : _planCategoryId,
              )
            : null,
      );
      final saved = switch (_debt) {
        final debt? => await repository.update(debt.id, draft),
        null => await repository.create(draft),
      };
      ref.read(toastControllerProvider.notifier).show(_debt == null ? 'Deuda creada' : 'Deuda actualizada');
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido guardar la deuda.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _planError(bool invalid) => _submitted && _hasPlan && invalid ? 'Obligatorio.' : null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accounts = ref.watch(accountsProvider).value?.all ?? const <Account>[];
    final contacts = ref.watch(contactOptionsProvider).value ?? const <ContactOption>[];
    final categories = ref.watch(categoriesProvider).value;
    final principalInvalid = _submitted && (_principal == null || _principal! <= 0);
    final nameInvalid = _submitted && _name.text.trim().isEmpty;
    final planAccountId = _planAccountId ?? preferredDebtAccountId(accounts);
    final count = _installmentsCount;

    return Column(
      children: [
        FullSheetHeader(
          title: _debt == null ? 'Nueva deuda' : 'Editar deuda',
          onLeading: () => Navigator.pop(context),
          trailing: SaveHeaderAction(saving: _saving, onSave: () => _save(accounts)),
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
              CarliSegmented<DebtDirection>(
                segments: const [
                  CarliSegment(DebtDirection.iOwe, 'Debo'),
                  CarliSegment(DebtDirection.owedToMe, 'Me deben'),
                ],
                value: _direction,
                onChanged: (direction) => setState(() => _direction = direction),
              ),
              const SizedBox(height: CarliSpace.s8),
              CarliMoneyInput(
                value: _principal,
                autofocus: _debt == null,
                semanticLabel: 'Importe total',
                onChanged: (value) => setState(() => _principal = value),
              ),
              principalInvalid ? const FormError('Indica el importe total.', center: true) : const SizedBox.shrink(),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Concepto',
                error: nameInvalid ? 'Ponle un nombre, por ejemplo Préstamo coche.' : null,
                child: CarliInput(
                  controller: _name,
                  placeholder: 'Préstamo coche, Dinero a Luis…',
                  invalid: nameInvalid,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: _owesMe ? 'Quién te lo debe' : 'A quién se lo debes',
                child: CarliSelect<String?>(
                  title: _owesMe ? 'Quién te lo debe' : 'A quién se lo debes',
                  options: [
                    CarliOption<String?>(null, 'Sin contacto', icon: carliIconNamed('user')),
                    for (final contact in contacts)
                      if (!contact.archived || contact.id == _contact)
                        CarliOption<String?>(contact.id, contact.name, icon: carliIconNamed('user')),
                    CarliOption<String?>(newContact, 'Nuevo contacto…', icon: carliIconNamed('user-plus')),
                  ],
                  value: _contact,
                  onChanged: (value) => setState(() => _contact = value),
                ),
              ),
              if (_contact == newContact) ...[
                const SizedBox(height: CarliSpace.s16),
                CarliField(
                  label: 'Nombre del contacto',
                  error: _submitted && _contactName.text.trim().isEmpty ? 'Escribe el nombre.' : null,
                  child: CarliInput(
                    controller: _contactName,
                    placeholder: 'Cetelem, Luis…',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Fecha',
                child: CarliDatePicker(value: _startDate, onChanged: (date) => setState(() => _startDate = date)),
              ),
              SwitchRow(
                label: 'Fecha de vencimiento',
                value: _hasDue,
                onChanged: (value) => setState(() => _hasDue = value),
              ),
              if (_hasDue) ...[
                const SizedBox(height: CarliSpace.s12),
                CarliField(
                  label: 'Vence',
                  child: DateField(
                    value: _dueDate,
                    onChanged: (date) => setState(() {
                      if (date == null) {
                        _hasDue = false;
                      } else {
                        _dueDate = date;
                      }
                    }),
                  ),
                ),
              ],
              if (_canPlan) ...[
                SwitchRow(
                  label: _owesMe ? 'Cobrar en cuotas mensuales' : 'Pagar en cuotas mensuales',
                  value: _hasPlan,
                  onChanged: (value) => setState(() => _hasPlan = value),
                ),
                if (_hasPlan)
                  Container(
                    margin: const EdgeInsets.only(top: CarliSpace.s12),
                    padding: const EdgeInsets.all(CarliSpace.s16),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(CarliRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: CarliSpace.s16,
                      children: [
                        CarliField(
                          label: 'Cuota mensual',
                          error: _planError(_installment == null || _installment! <= 0),
                          child: CarliMoneyInput(
                            value: _installment,
                            appearance: MoneyInputAppearance.field,
                            semanticLabel: 'Cuota mensual',
                            onChanged: (value) => setState(() => _installment = value),
                          ),
                        ),
                        CarliField(
                          label: 'Número de cuotas',
                          error: _planError(count == null || count < 1 || count > 600),
                          child: CarliInput(
                            controller: _count,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        CarliField(
                          label: 'Primera cuota',
                          child: DateField(
                            value: _firstPaymentDate,
                            onChanged: (date) => setState(() => _firstPaymentDate = date ?? _firstPaymentDate),
                          ),
                        ),
                        CarliField(
                          label: 'Cuenta',
                          error: _submitted && planAccountId == null ? 'Elige una cuenta.' : null,
                          child: CarliSelect<String>(
                            title: 'Cuenta',
                            placeholder: 'Elige una cuenta',
                            invalid: _submitted && planAccountId == null,
                            options: debtAccountOptions(accounts),
                            value: planAccountId,
                            onChanged: (id) => setState(() => _planAccountId = id),
                          ),
                        ),
                        if (!_owesMe)
                          CarliField(
                            label: 'Categoría',
                            child: CarliSelect<String?>(
                              title: 'Categoría',
                              placeholder: 'Sin categoría',
                              options: [
                                CarliOption<String?>(null, 'Sin categoría', icon: carliIconNamed('circle')),
                                for (final entry in categories?.selectable(CategoryKind.expense) ?? const [])
                                  CarliOption<String?>(
                                    entry.category.id,
                                    entry.label,
                                    icon: carliIconNamed(entry.icon),
                                  ),
                              ],
                              value: _planCategoryId,
                              onChanged: (id) => setState(() => _planCategoryId = id),
                            ),
                          ),
                        Text(
                          'Creamos un recurrente mensual con la cuota; cada cargo se descuenta de la deuda.',
                          style: CarliType.small.copyWith(color: colors.text2),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: CarliSpace.s16),
              CarliField(
                label: 'Notas',
                child: CarliInput(controller: _notes, placeholder: 'Opcional', maxLines: null),
              ),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: CarliSpace.s12),
                  child: FormError(error),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
