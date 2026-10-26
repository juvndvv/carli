import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/router/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../ui/async_view.dart';
import '../../../../ui/badge.dart';
import '../../../../ui/button.dart';
import '../../../../ui/card.dart';
import '../../../../ui/empty_state.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/list_item.dart';
import '../../../../ui/page.dart';
import '../../../../ui/pressable.dart';
import '../../../../ui/search.dart';
import '../../../../ui/sheet.dart';
import '../../../../ui/skeleton.dart';
import '../../../../ui/toast.dart';
import '../../data/bank.dart';
import '../../data/finance_changes.dart';
import '../../data/finance_providers.dart';

CarliBadgeTone badgeTone(BankTone tone) => switch (tone) {
  BankTone.positive => CarliBadgeTone.positive,
  BankTone.warning => CarliBadgeTone.warning,
  BankTone.negative => CarliBadgeTone.negative,
  BankTone.neutral => CarliBadgeTone.neutral,
};

Future<void> runBankAuthorization(
  BuildContext context,
  WidgetRef ref,
  Future<String> Function() start, {
  required ValueChanged<String> onError,
}) async {
  final url = await start();
  final result = await ref.read(bankAuthenticatorProvider).authorize(url);
  if (!context.mounted) return;
  switch (result) {
    case BankAuthCompleted(:final connectionId, :final renewed):
      ref.read(financeChangesProvider.notifier).notify(const [FinanceScope.bank]);
      await context.push(Routes.bankLink(connectionId, renewed: renewed));
    case BankAuthFailed():
      onError(result.message);
    case BankAuthCancelled():
      break;
  }
}

class BankConnectionsScreen extends ConsumerStatefulWidget {
  const BankConnectionsScreen({super.key});

  @override
  ConsumerState<BankConnectionsScreen> createState() => _BankConnectionsScreenState();
}

class _BankConnectionsScreenState extends ConsumerState<BankConnectionsScreen> {
  String? _syncing;
  String? _renewing;
  String? _disconnecting;
  String? _callbackError;

  BankRepository get _bank => ref.read(bankRepositoryProvider);

  ToastController get _toasts => ref.read(toastControllerProvider.notifier);

  void _showError(String message) => setState(() => _callbackError = message);

  Future<void> _connect() async {
    final aspsp = await showCarliSheet<Aspsp>(
      context,
      title: 'Conectar banco',
      scrollable: true,
      builder: (context) => const _ConnectBankSheet(),
    );
    if (aspsp == null || !mounted) return;
    try {
      await runBankAuthorization(context, ref, () => _bank.connect(aspsp), onError: _showError);
    } catch (error) {
      _toasts.error(apiErrorMessage(error, fallback: 'No se ha podido iniciar la conexión con el banco.'));
    }
  }

  Future<void> _sync(BankConnection connection) async {
    setState(() => _syncing = connection.id);
    final bool queued;
    try {
      queued = await _bank.sync(connection.id);
    } catch (error) {
      if (mounted) setState(() => _syncing = null);
      _toasts.error(apiErrorMessage(error, fallback: 'No se ha podido sincronizar el banco.'));
      return;
    }
    _toasts.show(
      queued ? 'Sincronizando ${connection.aspspName}…' : '${connection.aspspName} ya se está sincronizando…',
    );
    final current = await _bank.awaitSync(connection, active: () => mounted);
    if (!mounted) return;
    setState(() => _syncing = null);
    if (current?.status == BankConnectionStatus.error) {
      _toasts.error(current?.lastError ?? 'No se ha podido sincronizar ${current?.aspspName}.');
    } else if (current != null) {
      _toasts.show('${current.aspspName} sincronizado');
    }
  }

  Future<void> _renew(BankConnection connection) async {
    setState(() => _renewing = connection.id);
    try {
      await runBankAuthorization(context, ref, () => _bank.renew(connection.id), onError: _showError);
    } catch (error) {
      _toasts.error(apiErrorMessage(error, fallback: 'No se ha podido renovar el permiso del banco.'));
    } finally {
      if (mounted) setState(() => _renewing = null);
    }
  }

  Future<void> _disconnect(BankConnection connection) async {
    final confirmed = await confirmCarli(
      context,
      title: '¿Desconectar ${connection.aspspName}?',
      message: 'Se revoca el permiso de lectura en el banco y se dejan de importar movimientos. Los movimientos ya importados se conservan en tus cuentas.',
      confirmLabel: 'Desconectar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _disconnecting = connection.id);
    try {
      await _bank.disconnect(connection.id);
      _toasts.show('${connection.aspspName} desconectado · los movimientos importados se conservan');
    } catch (error) {
      _toasts.error(apiErrorMessage(error, fallback: 'No se ha podido desconectar el banco.'));
    } finally {
      if (mounted) setState(() => _disconnecting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(bankConnectionsProvider);
    return CarliPage(
      title: 'Bancos',
      trailing: CarliButton.icon(
        icon: carliIconNamed('plus'),
        semanticLabel: 'Conectar banco',
        size: CarliButtonSize.sm,
        variant: CarliButtonVariant.primary,
        onPressed: _connect,
      ),
      onRefresh: () async {
        ref.read(financeChangesProvider.notifier).notify(const [FinanceScope.bank, FinanceScope.rules]);
        await ref.read(bankConnectionsProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverList.list(
            children: [
              if (_callbackError case final message?)
                Padding(
                  padding: const EdgeInsets.only(bottom: CarliSpace.s12),
                  child: _Notice(message: message, onClose: () => setState(() => _callbackError = null)),
                ),
              AsyncView(
                value: connections,
                errorTitle: 'No se han podido cargar los bancos',
                onRetry: () => ref.invalidate(bankConnectionsProvider),
                loading: const CarliCard(child: CarliSkeleton(height: 120)),
                data: (list) => list.isEmpty
                    ? CarliCard(
                        child: CarliEmptyState(
                          icon: carliIconNamed('landmark'),
                          title: 'Conecta tu banco',
                          message: 'Importa los movimientos de Revolut, BBVA o MyInvestor automáticamente varias veces al día. Solo lectura: entran sin categoría y los revisas en Pendientes.',
                          actionLabel: 'Conectar banco',
                          onAction: _connect,
                        ),
                      )
                    : Column(
                        spacing: CarliSpace.s12,
                        children: [
                          for (final connection in list)
                            _ConnectionCard(
                              connection: connection,
                              syncing: _syncing == connection.id,
                              renewing: _renewing == connection.id,
                              disconnecting: _disconnecting == connection.id,
                              onSync: () => _sync(connection),
                              onRenew: () => _renew(connection),
                              onLink: () => context.push(Routes.bankLink(connection.id)),
                              onDisconnect: () => _disconnect(connection),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: CarliSpace.s16),
              const CategoryRulesCard(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.only(left: CarliSpace.s12),
        decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(CarliRadius.md)),
        child: Row(
          spacing: CarliSpace.s12,
          children: [
            CarliIcon(carliIconNamed('triangle-alert'), size: 18, color: colors.text2),
            Expanded(
              child: Text(message, style: CarliType.small.copyWith(color: colors.text)),
            ),
            CarliButton.icon(
              icon: carliIconNamed('x'),
              semanticLabel: 'Cerrar aviso',
              size: CarliButtonSize.sm,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connection,
    required this.syncing,
    required this.renewing,
    required this.disconnecting,
    required this.onSync,
    required this.onRenew,
    required this.onLink,
    required this.onDisconnect,
  });

  final BankConnection connection;
  final bool syncing;
  final bool renewing;
  final bool disconnecting;
  final VoidCallback onSync;
  final VoidCallback onRenew;
  final VoidCallback onLink;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = bankConnectionState(connection);
    return CarliCard(
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
                child: CarliIcon(carliIconNamed('landmark'), size: 20, color: colors.text),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.aspspName,
                      style: CarliType.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    Text(lastSyncLabel(connection), style: CarliType.small.copyWith(color: colors.text3)),
                  ],
                ),
              ),
              CarliBadge(state.label, tone: badgeTone(state.tone)),
            ],
          ),
          if (connection.status == BankConnectionStatus.error && connection.lastError != null)
            Text(connection.lastError!, style: CarliType.small.copyWith(color: colors.negative)),
          if (connection.status == BankConnectionStatus.expired)
            Text(
              'El permiso del banco ha caducado. Renuévalo para seguir importando movimientos.',
              style: CarliType.small.copyWith(color: colors.text2),
            ),
          if (connection.linkedAccounts.isEmpty)
            Text(
              'Ninguna cuenta vinculada: no se importa nada de este banco.',
              style: CarliType.small.copyWith(color: colors.text2),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: CarliSpace.s4,
              children: [
                for (final account in connection.linkedAccounts)
                  Semantics(
                    button: true,
                    child: Pressable(
                      onTap: () => context.push(Routes.account(account.id)),
                      child: Text(
                        linkedAccountLabel(account),
                        style: CarliType.small.copyWith(color: colors.brandInk, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            ),
          Wrap(
            spacing: CarliSpace.s8,
            runSpacing: CarliSpace.s8,
            children: [
              if (state.canSync)
                CarliButton(
                  label: 'Sincronizar ahora',
                  icon: carliIconNamed('refresh-cw'),
                  variant: CarliButtonVariant.secondary,
                  size: CarliButtonSize.sm,
                  block: false,
                  loading: syncing,
                  onPressed: connection.linkedAccounts.isEmpty ? null : onSync,
                ),
              if (state.canRenew)
                CarliButton(
                  label: 'Renovar',
                  icon: carliIconNamed('key-round'),
                  variant: state.tone == BankTone.positive ? CarliButtonVariant.ghost : CarliButtonVariant.primary,
                  size: CarliButtonSize.sm,
                  block: false,
                  loading: renewing,
                  onPressed: onRenew,
                ),
              CarliButton(
                label: 'Cuentas',
                icon: carliIconNamed('link'),
                variant: CarliButtonVariant.ghost,
                size: CarliButtonSize.sm,
                block: false,
                onPressed: onLink,
              ),
              CarliButton(
                label: 'Desconectar',
                icon: carliIconNamed('trash'),
                variant: CarliButtonVariant.ghost,
                size: CarliButtonSize.sm,
                block: false,
                loading: disconnecting,
                onPressed: onDisconnect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectBankSheet extends ConsumerStatefulWidget {
  const _ConnectBankSheet();

  @override
  ConsumerState<_ConnectBankSheet> createState() => _ConnectBankSheetState();
}

class _ConnectBankSheetState extends ConsumerState<_ConnectBankSheet> {
  final _query = TextEditingController();
  late final Future<List<Aspsp>> _aspsps = ref.read(bankRepositoryProvider).aspsps();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: CarliSpace.s12,
            children: [
              Text(
                'Solo lectura: la app nunca puede mover tu dinero. Te llevaremos a la web de tu banco para que autorices el acceso. Al volver, eliges a qué cuenta va cada una y desde qué fecha importar movimientos.',
                style: CarliType.small.copyWith(color: colors.text2),
              ),
              CarliSearchField(controller: _query, placeholder: 'Buscar banco', onChanged: (_) => setState(() {})),
            ],
          ),
        ),
        Flexible(
          child: FutureBuilder<List<Aspsp>>(
            future: _aspsps,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(CarliSpace.s20),
                  child: Text(
                    apiErrorMessage(snapshot.error!, fallback: 'No se ha podido cargar la lista de bancos.'),
                    style: CarliType.small.copyWith(color: colors.negative),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(CarliSpace.s20),
                  child: Column(
                    spacing: CarliSpace.s8,
                    children: [CarliSkeleton(height: 44), CarliSkeleton(height: 44), CarliSkeleton(height: 44)],
                  ),
                );
              }
              final visible = [
                for (final aspsp in snapshot.data!)
                  if (matchesAspsp(aspsp, _query.text)) aspsp,
              ];
              if (visible.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(CarliSpace.s20),
                  child: Text(
                    'No hay bancos que coincidan con «${_query.text}».',
                    style: CarliType.small.copyWith(color: colors.text3),
                  ),
                );
              }
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: CarliSpace.s16),
                children: [
                  for (final aspsp in visible)
                    CarliListItem(
                      title: aspsp.name,
                      subtitle: aspspSubtitle(aspsp),
                      icon: carliIconNamed('landmark'),
                      onTap: () => Navigator.pop(context, aspsp),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class CategoryRulesCard extends ConsumerStatefulWidget {
  const CategoryRulesCard({super.key});

  @override
  ConsumerState<CategoryRulesCard> createState() => _CategoryRulesCardState();
}

class _CategoryRulesCardState extends ConsumerState<CategoryRulesCard> {
  static const _searchThreshold = 8;

  final _query = TextEditingController();
  String? _removing;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _remove(CategoryRule rule) async {
    setState(() => _removing = rule.id);
    final bank = ref.read(bankRepositoryProvider);
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      await bank.deleteRule(rule.id);
      toasts.withUndo('Regla «${rule.pattern}» eliminada', () async {
        try {
          await bank.createRule(rule.pattern, rule.categoryId);
        } catch (error) {
          toasts.error(apiErrorMessage(error, fallback: 'No se ha podido recuperar la regla.'));
        }
      });
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido eliminar la regla.'));
    } finally {
      if (mounted) setState(() => _removing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rules = ref.watch(categoryRulesProvider);
    final categories = ref.watch(categoriesProvider).value;
    String label(CategoryRule rule) => rule.categoryLabel(categories?.find(rule.categoryId)?.parent?.name);

    return CarliCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s12,
        children: [
          Semantics(
            header: true,
            child: Text('Reglas de categorización', style: CarliType.h2.copyWith(color: colors.text)),
          ),
          Text(
            'Los movimientos importados cuyo comercio o concepto contiene el texto de una regla entran ya categorizados y no pasan por Pendientes.',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          switch (rules) {
            AsyncValue(hasValue: true, :final value) =>
              value!.isEmpty
                  ? Text(
                      'Aún no hay reglas. Al categorizar un movimiento importado te ofreceremos aplicarlo a los parecidos y recordarlo.',
                      style: CarliType.small.copyWith(color: colors.text3),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (value.length > _searchThreshold)
                          Padding(
                            padding: const EdgeInsets.only(bottom: CarliSpace.s8),
                            child: CarliSearchField(
                              controller: _query,
                              placeholder: 'Buscar regla',
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ..._visible(value, label).map(
                          (rule) => Row(
                            children: [
                              Expanded(
                                child: CarliListItem(
                                  title: rule.pattern,
                                  subtitle: label(rule),
                                  icon: carliIconNamed(rule.category?.icon ?? fallbackCategoryIcon),
                                ),
                              ),
                              CarliButton.icon(
                                icon: carliIconNamed('trash'),
                                semanticLabel: 'Eliminar la regla ${rule.pattern}',
                                size: CarliButtonSize.sm,
                                loading: _removing == rule.id,
                                onPressed: () => _remove(rule),
                              ),
                            ],
                          ),
                        ),
                        if (_visible(value, label).isEmpty)
                          Text(
                            'Ninguna regla coincide con «${_query.text}».',
                            style: CarliType.small.copyWith(color: colors.text3),
                          ),
                      ],
                    ),
            AsyncValue(hasError: true) => CarliEmptyState(
              icon: carliIconNamed('circle-alert'),
              title: 'No se han podido cargar las reglas',
              message: 'Comprueba tu conexión e inténtalo de nuevo.',
              actionLabel: 'Reintentar',
              onAction: () => ref.invalidate(categoryRulesProvider),
            ),
            _ => const Column(spacing: CarliSpace.s8, children: [CarliSkeleton(height: 44), CarliSkeleton(height: 44)]),
          },
        ],
      ),
    );
  }

  List<CategoryRule> _visible(List<CategoryRule> rules, String Function(CategoryRule) label) {
    final query = _query.text.trim().toUpperCase();
    if (query.isEmpty) return rules;
    return [
      for (final rule in rules)
        if (rule.pattern.toUpperCase().contains(query) || label(rule).toUpperCase().contains(query)) rule,
    ];
  }
}
