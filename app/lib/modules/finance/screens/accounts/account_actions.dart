import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';
import '../../../../core/router/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/button.dart';
import '../../../../ui/field.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/money_input.dart';
import '../../../../ui/pressable.dart';
import '../../../../ui/sheet.dart';
import '../../../../ui/toast.dart';
import '../../data/accounts_admin.dart';
import '../../data/models.dart';
import '../transaction_tools.dart';
import 'account_form_sheet.dart';

enum AccountAction { detail, edit, reconcile, toggleNetWorth, toggleArchived, delete }

Future<AccountDetails?> editAccount(BuildContext context, WidgetRef ref, [AccountDetails? account]) async {
  final toasts = ref.read(toastControllerProvider.notifier);
  final saved = await showAccountForm(context, account: account);
  if (saved != null) toasts.show(account == null ? 'Cuenta creada' : 'Cuenta actualizada');
  return saved;
}

Future<ReconcileResult?> reconcileAccount(BuildContext context, AccountDetails account) =>
    showCarliSheet<ReconcileResult>(
      context,
      title: 'Conciliar cuenta',
      builder: (context) => ReconcileSheet(account: account),
    );

Future<void> setAccountArchived(WidgetRef ref, AccountDetails account, bool archived) async {
  final repository = ref.read(accountsRepositoryProvider);
  final toasts = ref.read(toastControllerProvider.notifier);
  try {
    await repository.setArchived(account.id, archived);
    toasts.withUndo(
      archived ? '${account.name} archivada' : '${account.name} vuelve a estar activa',
      () => repository.setArchived(account.id, !archived),
    );
  } catch (error) {
    toasts.error(apiErrorMessage(error, fallback: 'No se ha podido actualizar la cuenta.'));
  }
}

Future<void> setAccountIncludedInNetWorth(WidgetRef ref, AccountDetails account, bool include) async {
  final repository = ref.read(accountsRepositoryProvider);
  final toasts = ref.read(toastControllerProvider.notifier);
  try {
    await repository.setIncludedInNetWorth(account.id, include);
    toasts.withUndo(
      include ? '${account.name} suma al patrimonio' : '${account.name} ya no suma al patrimonio',
      () => repository.setIncludedInNetWorth(account.id, !include),
    );
  } catch (error) {
    toasts.error(apiErrorMessage(error, fallback: 'No se ha podido actualizar la cuenta.'));
  }
}

Future<bool> removeAccount(BuildContext context, WidgetRef ref, AccountDetails account) async {
  final repository = ref.read(accountsRepositoryProvider);
  final toasts = ref.read(toastControllerProvider.notifier);
  final confirmed = await confirmCarli(
    context,
    title: '¿Eliminar ${account.name}?',
    message: 'Solo se pueden eliminar cuentas sin movimientos. Esta acción no se puede deshacer.',
    confirmLabel: 'Eliminar',
    destructive: true,
  );
  if (!confirmed) return false;
  try {
    await repository.remove(account.id);
    toasts.show('Cuenta eliminada');
    return true;
  } catch (error) {
    toasts.error(apiErrorMessage(error, fallback: 'Tiene movimientos: archívala en lugar de eliminarla.'));
    return false;
  }
}

Future<void> runAccountAction(
  BuildContext context,
  WidgetRef ref,
  AccountDetails account,
  AccountAction action, {
  VoidCallback? onDeleted,
}) async {
  switch (action) {
    case AccountAction.detail:
      await context.push(Routes.account(account.id));
    case AccountAction.edit:
      await editAccount(context, ref, account);
    case AccountAction.reconcile:
      await reconcileAccount(context, account);
    case AccountAction.toggleNetWorth:
      await setAccountIncludedInNetWorth(ref, account, !account.includeInNetWorth);
    case AccountAction.toggleArchived:
      await setAccountArchived(ref, account, !account.archived);
    case AccountAction.delete:
      if (await removeAccount(context, ref, account)) onDeleted?.call();
  }
}

Future<AccountAction?> showAccountMenu(
  BuildContext context,
  AccountDetails account, {
  Set<AccountAction> actions = const {
    AccountAction.detail,
    AccountAction.edit,
    AccountAction.toggleNetWorth,
    AccountAction.toggleArchived,
    AccountAction.delete,
  },
}) => showCarliSheet<AccountAction>(
  context,
  title: account.name,
  builder: (context) => Padding(
    padding: const EdgeInsets.fromLTRB(CarliSpace.s8, 0, CarliSpace.s8, CarliSpace.s16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (action, icon, label) in [
          (AccountAction.detail, 'chart-line', 'Ver detalle'),
          (AccountAction.edit, 'pencil', 'Editar'),
          (AccountAction.reconcile, 'check-check', 'Conciliar'),
          (
            AccountAction.toggleNetWorth,
            account.includeInNetWorth ? 'eye-off' : 'eye',
            account.includeInNetWorth ? 'Excluir del patrimonio' : 'Incluir en el patrimonio',
          ),
          (
            AccountAction.toggleArchived,
            account.archived ? 'archive-restore' : 'archive',
            account.archived ? 'Desarchivar' : 'Archivar',
          ),
          (AccountAction.delete, 'trash', 'Eliminar'),
        ])
          if (actions.contains(action))
            _MenuRow(
              icon: icon,
              label: label,
              destructive: action == AccountAction.delete,
              onTap: () => Navigator.pop(context, action),
            ),
      ],
    ),
  ),
);

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap, this.destructive = false});

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = destructive ? colors.negative : colors.text;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        pressedOpacity: 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s12, vertical: 14),
          child: Row(
            spacing: CarliSpace.s12,
            children: [
              CarliIcon(carliIconNamed(icon), size: 20, color: color),
              Expanded(
                child: Text(label, style: CarliType.body.copyWith(color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReconcileSheet extends ConsumerStatefulWidget {
  const ReconcileSheet({super.key, required this.account});

  final AccountDetails account;

  @override
  ConsumerState<ReconcileSheet> createState() => _ReconcileSheetState();
}

class _ReconcileSheetState extends ConsumerState<ReconcileSheet> {
  late Cents? _actual = reconcileStartingBalance(widget.account);
  DateTime? _date = today();
  var _saving = false;
  String? _error;

  AccountDetails get account => widget.account;

  Cents? get _difference => _actual == null ? null : _actual! - account.clearedBalanceCents;

  Future<void> _save() async {
    final actual = _actual;
    if (actual == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      final result = await ref.read(accountsRepositoryProvider).reconcile(account.id, actual, _date);
      toasts.show(
        result.adjustment != null
            ? 'Cuenta conciliada · ajuste de ${formatMoney(result.differenceCents, display: MoneyDisplay.signed)}'
            : 'Cuenta conciliada · el saldo ya cuadraba',
      );
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido conciliar la cuenta.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bank = account.bank;
    final bankAt = bank?.balanceAt;
    final pending = account.balanceCents - account.clearedBalanceCents;
    final difference = _difference;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(account.name, style: CarliType.small.copyWith(color: colors.text2)),
          Row(
            children: [
              Expanded(
                child: Text('Saldo confirmado en la app', style: CarliType.small.copyWith(color: colors.text2)),
              ),
              Text(
                formatMoney(account.clearedBalanceCents),
                style: CarliType.money(CarliType.small).copyWith(fontWeight: FontWeight.w600, color: colors.text),
              ),
            ],
          ),
          if (pending != 0)
            Text(
              'No cuenta los movimientos pendientes (${formatMoney(pending, display: MoneyDisplay.signed)}).',
              style: CarliType.small.copyWith(color: colors.text2),
            ),
          CarliField(
            label: 'Saldo real en el banco',
            hint: bank == null || bank.balanceCents == null
                ? null
                : 'Precargado con el saldo que informa ${bank.aspspName}${bankAt == null ? '' : ' (${formatDateTime(bankAt)})'}.',
            child: CarliMoneyInput(
              value: _actual,
              appearance: MoneyInputAppearance.field,
              allowNegative: true,
              semanticLabel: 'Saldo real en el banco',
              onChanged: (value) => setState(() => _actual = value),
            ),
          ),
          CarliField(
            label: 'Fecha',
            child: DateField(value: _date, onChanged: (value) => setState(() => _date = value)),
          ),
          if (difference != null)
            Semantics(
              liveRegion: true,
              child: difference == 0
                  ? Text(
                      'El saldo cuadra. No hace falta ningún ajuste.',
                      style: CarliType.small.copyWith(color: colors.text2),
                    )
                  : Text.rich(
                      TextSpan(
                        style: CarliType.small.copyWith(color: colors.text),
                        children: [
                          const TextSpan(text: 'Se creará un movimiento de ajuste de '),
                          TextSpan(
                            text: formatMoney(difference, display: MoneyDisplay.signed),
                            style: CarliType.money(CarliType.small).copyWith(fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
            ),
          if (_error case final error?) Text(error, style: CarliType.small.copyWith(color: colors.negative)),
          Row(
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
                  label: 'Conciliar',
                  icon: carliIconNamed('check-check'),
                  size: CarliButtonSize.md,
                  loading: _saving,
                  onPressed: _actual == null ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BankBalanceLine extends StatelessWidget {
  const BankBalanceLine({super.key, required this.link, this.detailed = false});

  final BankLinkDetails link;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final info = bankBalanceSummary(link)!;
    final strong = CarliType.money(CarliType.small).copyWith(fontWeight: FontWeight.w600, color: colors.text);
    final balance = info.balance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CarliIcon(carliIconNamed('landmark'), size: 14, color: colors.text2),
            ),
            Flexible(
              child: Text.rich(
                TextSpan(
                  style: CarliType.small.copyWith(color: colors.text2),
                  children: balance == null
                      ? [TextSpan(text: 'Vinculada a ${info.bank} · sin saldo todavía')]
                      : [
                          TextSpan(text: '${info.bank}: '),
                          TextSpan(text: balance, style: strong),
                          if (info.matches)
                            const TextSpan(text: ' · cuadra')
                          else if (info.difference case final difference?) ...[
                            const TextSpan(text: ' · diferencia '),
                            TextSpan(text: difference, style: strong),
                          ],
                        ],
                ),
              ),
            ),
          ],
        ),
        if (detailed && info.updated != null)
          Text('Saldo del banco ${info.updated}', style: CarliType.caption.copyWith(color: colors.text3)),
      ],
    );
  }
}
