import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/button.dart';
import '../../../../ui/date_picker.dart';
import '../../../../ui/field.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/select.dart';
import '../../../../ui/sheet.dart';
import '../../../../ui/toast.dart';
import '../../data/contacts.dart';
import '../../data/finance_providers.dart';
import '../../data/transactions_repository.dart';
import '../transaction_sheet.dart';

enum ContactSheetResult { saved, archived, deleted }

Future<ContactSheetResult?> showContactSheet(BuildContext context, {FinanceContactDetail? detail}) =>
    showCarliSheet<ContactSheetResult>(
      context,
      title: detail == null ? 'Nuevo contacto' : 'Editar contacto',
      builder: (context) => ContactForm(detail: detail),
    );

class ContactForm extends ConsumerStatefulWidget {
  const ContactForm({super.key, this.detail});

  final FinanceContactDetail? detail;

  @override
  ConsumerState<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<ContactForm> {
  late final _name = TextEditingController(text: widget.detail?.contact.name ?? '');
  late final _notes = TextEditingController(text: widget.detail?.contact.notes ?? '');
  var _submitted = false;
  var _saving = false;
  String? _error;

  FinanceContact? get _contact => widget.detail?.contact;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _run(Future<ContactSheetResult> Function() action, String fallback) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await action();
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: fallback));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 120) return;
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final repository = ref.read(contactsRepositoryProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    await _run(() async {
      if (_contact case final contact?) {
        await repository.update(contact.id, name: name, notes: notes);
        toasts.show('Contacto actualizado');
      } else {
        final saved = await repository.create(name: name, notes: notes);
        toasts.show('${saved.contact.name} añadido');
      }
      return ContactSheetResult.saved;
    }, 'No se ha podido guardar el contacto.');
  }

  Future<void> _toggleArchive(FinanceContact contact) async {
    final archived = !contact.archived;
    final repository = ref.read(contactsRepositoryProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    await _run(() async {
      await repository.setArchived(contact.id, archived);
      if (archived) {
        toasts.withUndo('${contact.name} archivado', () => repository.setArchived(contact.id, false));
      }
      return ContactSheetResult.archived;
    }, 'No se ha podido archivar el contacto.');
  }

  Future<void> _remove(FinanceContact contact) async {
    final repository = ref.read(contactsRepositoryProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    await _run(() async {
      await repository.remove(contact.id);
      toasts.withUndo('${contact.name} eliminado', () => repository.create(name: contact.name, notes: contact.notes));
      return ContactSheetResult.deleted;
    }, 'Este contacto tiene gastos o deudas: archívalo en su lugar.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final contact = _contact;
    final nameInvalid = _submitted && (_name.text.trim().isEmpty || _name.text.trim().length > 120);
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          if (contact == null)
            Text(
              'Solo necesitas un nombre; no tendrá acceso a la app.',
              style: CarliType.small.copyWith(color: colors.text2),
            ),
          CarliField(
            label: 'Nombre',
            error: nameInvalid ? 'Escribe un nombre.' : null,
            child: CarliInput(
              controller: _name,
              placeholder: 'Ana, Piso compartido…',
              autofocus: contact == null,
              invalid: nameInvalid,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(120)],
              onChanged: (_) {
                if (_submitted) setState(() {});
              },
            ),
          ),
          CarliField(
            label: 'Notas',
            child: CarliInput(
              controller: _notes,
              placeholder: 'Opcional',
              maxLines: 2,
              inputFormatters: [LengthLimitingTextInputFormatter(2000)],
            ),
          ),
          if (_error case final error?)
            Semantics(
              liveRegion: true,
              child: Text(error, style: CarliType.small.copyWith(color: colors.negative)),
            ),
          CarliButton(label: contact == null ? 'Añadir contacto' : 'Guardar', loading: _saving, onPressed: _save),
          if (contact != null)
            Row(
              spacing: CarliSpace.s8,
              children: [
                Expanded(
                  child: CarliButton(
                    label: contact.archived ? 'Desarchivar' : 'Archivar',
                    icon: carliIconNamed('archive'),
                    variant: CarliButtonVariant.ghost,
                    size: CarliButtonSize.md,
                    onPressed: _saving ? null : () => _toggleArchive(contact),
                  ),
                ),
                if (widget.detail!.deletable)
                  Expanded(
                    child: CarliButton(
                      label: 'Eliminar',
                      icon: carliIconNamed('trash'),
                      variant: CarliButtonVariant.ghost,
                      size: CarliButtonSize.md,
                      onPressed: _saving ? null : () => _remove(contact),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

Future<bool> showSettleSheet(BuildContext context, FinanceContact contact, {DateTime? now}) async {
  final settled = await showCarliSheet<bool>(
    context,
    title: 'Liquidar con ${contact.name}',
    builder: (context) => SettleForm(contact: contact, now: now),
  );
  return settled ?? false;
}

class SettleForm extends ConsumerStatefulWidget {
  const SettleForm({super.key, required this.contact, this.now});

  final FinanceContact contact;
  final DateTime? now;

  @override
  ConsumerState<SettleForm> createState() => _SettleFormState();
}

class _SettleFormState extends ConsumerState<SettleForm> {
  String? _accountId;
  var _accountTouched = false;
  late var _date = today(widget.now);
  var _saving = false;
  String? _error;

  FinanceContact get contact => widget.contact;

  Future<void> _settle(String? accountId, String? accountName) async {
    if (accountId == null) {
      setState(() => _error = 'Elige la cuenta donde recibes el dinero.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final toasts = ref.read(toastControllerProvider.notifier);
    final transactions = ref.read(transactionsRepositoryProvider);
    try {
      final result = await ref.read(contactsRepositoryProvider).settle(contact.id, accountId: accountId, date: _date);
      toasts.withUndo('Liquidado con ${contact.name}: ${formatMoney(result.netCents, display: MoneyDisplay.signed)}'
          '${accountName == null ? '' : ' en $accountName'}', () async {
        for (final id in result.transactionIds) {
          await transactions.remove(id);
        }
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido liquidar.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accounts = ref.watch(accountsProvider).value?.active ?? const [];
    final accountId = _accountTouched ? _accountId : (_accountId ?? preferredSettleAccountId(accounts));
    final accountName = accounts.where((account) => account.id == accountId).firstOrNull?.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(
            'Registra el cobro de los gastos compartidos pendientes.',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          Column(
            spacing: CarliSpace.s4,
            children: [
              Text('${contact.name} te paga', style: CarliType.caption.copyWith(color: colors.text2)),
              Text(
                formatMoney(contact.sharesPendingCents, display: MoneyDisplay.signed),
                style: CarliType.display.copyWith(color: colors.positive),
              ),
            ],
          ),
          CarliField(
            label: 'Cuenta donde lo recibes',
            child: CarliSelect<String>(
              title: 'Cuenta donde lo recibes',
              placeholder: 'Elige una cuenta',
              value: accountId,
              invalid: _error != null && accountId == null,
              options: [
                for (final account in accounts)
                  CarliOption(
                    account.id,
                    account.name,
                    icon: carliIconNamed(account.icon ?? accountTypeIconName(account.type)),
                  ),
              ],
              onChanged: (value) => setState(() {
                _accountId = value;
                _accountTouched = true;
              }),
            ),
          ),
          CarliField(
            label: 'Fecha',
            child: CarliDatePicker(
              value: _date,
              now: widget.now,
              lastDate: today(widget.now),
              onChanged: (value) => setState(() => _date = value),
            ),
          ),
          Text(
            'Se crea un ingreso que no cuenta como ingreso del periodo: solo te devuelve lo que adelantaste.',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          if (contact.iOweCents > 0 || contact.owedToMeCents > 0)
            Text(
              'Las deudas con ${contact.name} se gestionan aparte, en Deudas.',
              style: CarliType.small.copyWith(color: colors.text3),
            ),
          if (_error case final error?)
            Semantics(
              liveRegion: true,
              child: Text(error, style: CarliType.small.copyWith(color: colors.negative)),
            ),
          CarliButton(
            label: 'Registrar cobro',
            icon: carliIconNamed('check'),
            loading: _saving,
            onPressed: () => _settle(accountId, accountName),
          ),
        ],
      ),
    );
  }
}
