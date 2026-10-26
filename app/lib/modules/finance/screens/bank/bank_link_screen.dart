import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/button.dart';
import '../../../../ui/card.dart';
import '../../../../ui/empty_state.dart';
import '../../../../ui/field.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/page.dart';
import '../../../../ui/select.dart';
import '../../../../ui/skeleton.dart';
import '../../../../ui/toast.dart';
import '../../data/bank.dart';
import '../../data/finance_providers.dart';
import '../../data/json.dart';
import '../../data/models.dart';
import '../transaction_tools.dart';

class _LinkRow {
  _LinkRow({required this.candidate, required this.target, required this.name, required this.type, required this.from});

  final BankAccountCandidate candidate;
  String? target;
  final TextEditingController name;
  AccountType type;
  DateTime from;
}

class BankLinkScreen extends ConsumerStatefulWidget {
  const BankLinkScreen({super.key, required this.connectionId, this.renewed = false});

  final String connectionId;
  final bool renewed;

  @override
  ConsumerState<BankLinkScreen> createState() => _BankLinkScreenState();
}

class _BankLinkScreenState extends ConsumerState<BankLinkScreen> {
  BankConnection? _connection;
  List<_LinkRow> _rows = const [];
  var _loading = true;
  String? _failed;
  var _saving = false;
  String? _error;

  BankRepository get _bank => ref.read(bankRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.name.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = null;
    });
    try {
      final (connection, candidates) = await (
        _bank.connection(widget.connectionId),
        _bank.bankAccounts(widget.connectionId),
      ).wait;
      final unlinkedTarget = connection.linkedAccounts.isEmpty && !widget.renewed ? newAccountTarget : null;
      final current = today();
      if (!mounted) return;
      setState(() {
        _connection = connection;
        _rows = [
          for (final candidate in candidates)
            _LinkRow(
              candidate: candidate,
              target: candidate.linkedAccountId ?? (isEuroAccount(candidate) ? unlinkedTarget : null),
              name: TextEditingController(text: defaultNewAccountName(connection.aspspName, candidate)),
              type: candidate.suggestedAccountType,
              from: candidate.linkedSyncFromDate ?? current,
            ),
        ];
      });
    } catch (error) {
      if (mounted) {
        setState(() => _failed = apiErrorMessage(error, fallback: 'Vuelve a la lista de bancos e inténtalo de nuevo.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Set<String> get _duplicates => duplicateTargets([for (final row in _rows) row.target]);

  Future<void> _save() async {
    if (_duplicates.isNotEmpty) return;
    final current = today();
    final items = <Json>[
      for (final row in _rows)
        if (row.target == null)
          {'external_account_uid': row.candidate.externalAccountUid, 'account_id': null}
        else
          {
            'external_account_uid': row.candidate.externalAccountUid,
            'account_id': row.target,
            'sync_from_date': isoDate(row.from.isAfter(current) ? current : row.from),
            if (row.target == newAccountTarget) ...{
              'name': row.name.text.trim().isEmpty ? null : row.name.text.trim(),
              'type': row.type.api,
            },
          },
    ];
    setState(() {
      _saving = true;
      _error = null;
    });
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      final connection = await _bank.link(widget.connectionId, items);
      final linked = items.where((item) => item['account_id'] != null).length;
      if (linked > 0) _bank.awaitSync(connection).ignore();
      toasts.show(
        linked == 0
            ? '${connection.aspspName}: no se importará ninguna cuenta'
            : '${connection.aspspName} vinculado · importando movimientos',
      );
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se han podido vincular las cuentas.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accounts = ref.watch(accountsProvider).value;
    final connection = _connection;
    final duplicates = _duplicates;
    final selectable = [
      for (final account in accounts?.active ?? const <Account>[])
        if (account.type != AccountType.cash || account.bank != null) account,
    ];
    final targetOptions = [
      CarliOption<String?>(newAccountTarget, 'Crear cuenta nueva', icon: carliIconNamed('plus')),
      for (final account in selectable)
        CarliOption<String?>(
          account.id,
          account.name,
          icon: carliIconNamed(account.icon ?? account.type.icon),
          subtitle:
              account.bank != null && !(_connection?.linkedAccounts.any((linked) => linked.id == account.id) ?? false)
              ? 'Ya vinculada a ${account.bank!.aspspName}'
              : null,
        ),
      CarliOption<String?>(null, 'No importar', icon: carliIconNamed('eye-off')),
    ];
    final typeOptions = [
      for (final type in AccountType.values) CarliOption(type, type.label, icon: carliIconNamed(type.icon)),
    ];

    Widget body;
    if (_failed case final message?) {
      body = CarliCard(
        child: CarliEmptyState(
          icon: carliIconNamed('triangle-alert'),
          title: 'No se han podido cargar las cuentas',
          message: message,
          actionLabel: 'Volver a bancos',
          onAction: () => context.pop(),
        ),
      );
    } else if (_loading) {
      body = const CarliCard(child: CarliSkeleton(height: 160));
    } else if (_rows.isEmpty) {
      body = CarliCard(
        child: CarliEmptyState(
          icon: carliIconNamed('landmark'),
          title: 'El banco no ha devuelto cuentas',
          message: 'Puede que no hayas autorizado ninguna. Renueva la conexión y elige las cuentas en el banco.',
          actionLabel: 'Volver a bancos',
          onAction: () => context.pop(),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s12,
        children: [
          Text(
            'Elige a qué cuenta de la app va cada cuenta del banco. Los movimientos se importan desde la fecha que indiques: si ya apuntaste a mano los anteriores, deja la de hoy para no duplicarlos.',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          for (final row in _rows)
            CarliCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: CarliSpace.s12,
                children: [
                  Row(
                    spacing: CarliSpace.s12,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
                        child: CarliIcon(
                          carliIconNamed(row.candidate.suggestedAccountType.icon),
                          size: 20,
                          color: colors.text,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candidateTitle(row.candidate),
                              style: CarliType.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                            ),
                            Text(
                              candidateSubtitle(row.candidate),
                              style: CarliType.small.copyWith(color: colors.text3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  CarliField(
                    label: 'Vincular con',
                    error: row.target != null && duplicates.contains(row.target)
                        ? 'Esta cuenta ya está elegida para otra cuenta del banco.'
                        : null,
                    child: CarliSelect<String?>(
                      title: 'Vincular con',
                      options: targetOptions,
                      value: row.target,
                      invalid: row.target != null && duplicates.contains(row.target),
                      onChanged: (target) => setState(() => row.target = target),
                    ),
                  ),
                  if (row.target != null)
                    CarliField(
                      label: 'Importar desde',
                      hint: 'Los movimientos anteriores a esta fecha no se importan.',
                      child: DateField(
                        value: row.from,
                        onChanged: (date) => setState(() => row.from = date ?? today()),
                      ),
                    ),
                  if (row.target == newAccountTarget) ...[
                    CarliField(
                      label: 'Nombre de la cuenta nueva',
                      child: CarliInput(controller: row.name),
                    ),
                    CarliField(
                      label: 'Tipo',
                      child: CarliSelect<AccountType>(
                        title: 'Tipo',
                        options: typeOptions,
                        value: row.type,
                        onChanged: (type) => setState(() => row.type = type),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (_error case final error?) Text(error, style: CarliType.small.copyWith(color: colors.negative)),
          CarliButton(
            label: 'Guardar y sincronizar',
            icon: carliIconNamed('check'),
            loading: _saving,
            onPressed: duplicates.isEmpty ? _save : null,
          ),
          CarliButton(
            label: 'Más tarde',
            variant: CarliButtonVariant.ghost,
            size: CarliButtonSize.md,
            onPressed: () => context.pop(),
          ),
        ],
      );
    }

    return CarliPage(
      title: connection == null ? 'Vincular cuentas' : 'Vincular cuentas de ${connection.aspspName}',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverList.list(
            children: [
              if (widget.renewed)
                Padding(
                  padding: const EdgeInsets.only(bottom: CarliSpace.s12),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(CarliSpace.s12),
                      decoration: BoxDecoration(
                        color: colors.positiveSoft,
                        borderRadius: BorderRadius.circular(CarliRadius.md),
                      ),
                      child: Row(
                        spacing: CarliSpace.s8,
                        children: [
                          CarliIcon(carliIconNamed('circle-check'), size: 18, color: colors.positive),
                          Expanded(
                            child: Text(
                              'Permiso renovado. Tus cuentas siguen vinculadas; revisa que todo esté bien y guarda.',
                              style: CarliType.small.copyWith(color: colors.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              body,
            ],
          ),
        ),
      ],
    );
  }
}
