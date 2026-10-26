import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/pending/pending_models.dart';
import '../../core/pending/pending_providers.dart';
import '../../core/pending/pending_types.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../ui/badge.dart';
import '../../ui/button.dart';
import '../../ui/card.dart';
import '../../ui/chip.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon.dart';
import '../../ui/icon_names.dart';
import '../../ui/page.dart';
import '../../ui/skeleton.dart';
import 'pending_actions.dart';
import 'pending_item_row.dart';

class PendingTypeGroup {
  PendingTypeGroup({required this.type, required this.descriptor, required this.count, required this.route});

  final String type;
  final PendingTypeDescriptor descriptor;
  int count;
  final String route;
  final List<PendingItem> items = [];
}

class PendingModuleGroup {
  PendingModuleGroup({required this.module, required this.name, required this.icon});

  final String module;
  final String name;
  final String icon;
  final List<PendingTypeGroup> types = [];
}

List<PendingModuleGroup> groupPendingItems(
  List<PendingItem> items,
  List<PendingSummaryEntry> entries,
  PendingTypeRegistry registry,
) {
  final groups = <PendingModuleGroup>[];
  for (final item in items) {
    var group = groups.where((current) => current.module == item.module).firstOrNull;
    if (group == null) {
      final info = registry.module(item.module);
      final name =
          info?.name ?? entries.where((entry) => entry.module == item.module).firstOrNull?.moduleName ?? item.module;
      group = PendingModuleGroup(module: item.module, name: name, icon: info?.icon ?? fallbackPendingIcon);
      groups.add(group);
    }
    var typeGroup = group.types.where((current) => current.type == item.type).firstOrNull;
    if (typeGroup == null) {
      final entry = entries.where((current) => current.module == item.module && current.type == item.type).firstOrNull;
      typeGroup = PendingTypeGroup(
        type: item.type,
        descriptor: registry.describe(item.module, item.type),
        count: entry?.count ?? 0,
        route: item.route,
      );
      group.types.add(typeGroup);
    }
    typeGroup.items.add(item);
  }
  for (final typeGroup in groups.expand((group) => group.types)) {
    if (typeGroup.items.length > typeGroup.count) typeGroup.count = typeGroup.items.length;
  }
  return groups;
}

class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key, this.module, this.type});

  final String? module;
  final String? type;

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  late PendingFilter _filter = _filterOf(widget);

  static PendingFilter _filterOf(PendingScreen widget) => PendingFilter(
    module: widget.module == null || widget.module!.isEmpty ? null : widget.module,
    type: widget.type == null || widget.type!.isEmpty ? null : widget.type,
  );

  @override
  void initState() {
    super.initState();
    ref.read(pendingSummaryProvider.notifier).refreshIfStale().ignore();
  }

  @override
  void didUpdateWidget(PendingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _filterOf(widget);
    if (next != _filter) setState(() => _filter = next);
  }

  void _select(PendingFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    ref.read(pendingSummaryProvider.notifier).refreshIfStale().ignore();
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final current = router.routerDelegate.currentConfiguration.uri;
    final parameters = {
      for (final MapEntry(:key, :value) in current.queryParameters.entries)
        if (key != PendingQuery.module && key != PendingQuery.type) key: value,
      ...filter.queryParameters,
    };
    router.replace(Uri(path: current.path, queryParameters: parameters.isEmpty ? null : parameters).toString());
  }

  Future<void> _refresh() async {
    ref.invalidate(pendingListProvider(_filter));
    await Future.wait([
      ref.read(pendingSummaryProvider.notifier).refresh(),
      ref.read(pendingListProvider(_filter).future).then((_) {}, onError: (_) {}),
    ]);
  }

  void _resolve(PendingItem item) => ref.read(pendingListProvider(_filter).notifier).resolve(item);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = ref.watch(pendingTypeRegistryProvider);
    final summary = ref.watch(pendingSummaryProvider);
    final entries = summary.value?.entries ?? const <PendingSummaryEntry>[];
    final total = summary.value?.total ?? 0;
    final list = ref.watch(pendingListProvider(_filter));
    final crumb = summary.hasValue ? pendingTotalLabel(total) : 'Todo lo que requiere tu atención';

    return CarliPage(
      title: 'Pendientes',
      onRefresh: _refresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: Text(crumb, style: CarliType.small.copyWith(color: colors.text2)),
          ),
        ),
        if (entries.length > 1 || _filter.isFiltered)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: CarliSpace.s16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
                child: Semantics(
                  label: 'Filtrar pendientes',
                  container: true,
                  child: Row(
                    spacing: CarliSpace.s8,
                    children: [
                      CarliChip(
                        label: 'Todo ($total)',
                        selected: !_filter.isFiltered,
                        onTap: () => _select(PendingFilter.all),
                      ),
                      for (final entry in entries)
                        CarliChip(
                          label: '${types.describe(entry.module, entry.type).label} (${entry.count})',
                          icon: carliIconNamed(types.describe(entry.module, entry.type).icon),
                          selected: _filter.matches(entry),
                          onTap: () => _select(PendingFilter(module: entry.module, type: entry.type)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverToBoxAdapter(child: _body(list, entries, types)),
        ),
      ],
    );
  }

  Widget _body(AsyncValue<PendingListState> list, List<PendingSummaryEntry> entries, PendingTypeRegistry types) {
    final value = list.value;
    if (list.hasError && !list.isLoading && (value == null || value.items.isEmpty)) {
      return CarliCard(
        child: CarliEmptyState(
          icon: carliIconNamed('circle-alert'),
          title: 'No se han podido cargar los pendientes',
          message: apiErrorMessage(list.error!, fallback: pendingListErrorMessage),
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(pendingListProvider(_filter)),
        ),
      );
    }
    if (value == null) return const _PendingSkeleton();
    final groups = groupPendingItems(value.items, entries, types);
    if (groups.isEmpty) {
      return CarliCard(
        child: _filter.isFiltered
            ? CarliEmptyState(
                icon: carliIconNamed('circle-check'),
                title: 'Nada pendiente de este tipo',
                message: 'Ya lo has revisado todo en esta sección.',
                actionLabel: 'Ver todos los pendientes',
                onAction: () => _select(PendingFilter.all),
              )
            : CarliEmptyState(
                icon: carliIconNamed('circle-check'),
                title: 'Todo al día',
                message: 'Aquí aparecerá lo que necesite tu atención, como movimientos sin categoría o recurrentes por confirmar.',
              ),
      );
    }
    final showModuleHeads = groups.length > 1 || !_filter.isFiltered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s16,
      children: [
        for (final group in groups) _ModuleSection(group: group, showHead: showModuleHeads, onResolved: _resolve),
        if (value.loadMoreError case final error?)
          Text(
            error,
            textAlign: TextAlign.center,
            style: CarliType.small.copyWith(color: context.colors.negative),
          ),
        if (value.hasMore)
          Center(
            child: CarliButton(
              label: 'Cargar más',
              variant: CarliButtonVariant.ghost,
              size: CarliButtonSize.sm,
              block: false,
              loading: value.loadingMore,
              onPressed: () => ref.read(pendingListProvider(_filter).notifier).loadMore(),
            ),
          ),
      ],
    );
  }
}

class _ModuleSection extends ConsumerWidget {
  const _ModuleSection({required this.group, required this.showHead, required this.onResolved});

  final PendingModuleGroup group;
  final bool showHead;
  final ValueChanged<PendingItem> onResolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final actions = ref.watch(pendingActionRegistryProvider);
    final canOpen = actions.canOpen(group.module);
    return Semantics(
      label: group.name,
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s12,
        children: [
          if (showHead)
            Padding(
              padding: const EdgeInsets.only(left: CarliSpace.s4, top: CarliSpace.s4),
              child: Semantics(
                header: true,
                child: Row(
                  spacing: CarliSpace.s8,
                  children: [
                    CarliIcon(carliIconNamed(group.icon), size: 18, color: colors.text2),
                    Text(group.name, style: CarliType.h2.copyWith(color: colors.text)),
                  ],
                ),
              ),
            ),
          for (final typeGroup in group.types)
            CarliCard(
              padding: const EdgeInsets.only(top: CarliSpace.s4, bottom: CarliSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s12, CarliSpace.s12, CarliSpace.s4),
                    child: Row(
                      spacing: CarliSpace.s8,
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(typeGroup.descriptor.label, style: CarliType.h2.copyWith(color: colors.text)),
                          ),
                        ),
                        CarliBadge('${typeGroup.count}', tone: CarliBadgeTone.warning),
                        if (canOpen)
                          CarliButton(
                            label: 'Ver todos',
                            variant: CarliButtonVariant.ghost,
                            size: CarliButtonSize.sm,
                            block: false,
                            onPressed: () => actions.open(context, ref, group.module, typeGroup.route),
                          ),
                      ],
                    ),
                  ),
                  for (final (index, item) in typeGroup.items.indexed) ...[
                    if (index > 0) Divider(height: 1, thickness: 1, indent: CarliSpace.s16, color: colors.border),
                    PendingItemRow(
                      key: ValueKey(item.key),
                      item: item,
                      descriptor: typeGroup.descriptor,
                      action: actions.action(item.module, item.type)?.call(item, onResolved),
                      onReview: canOpen ? () => actions.open(context, ref, item.module, item.route) : null,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingSkeleton extends StatelessWidget {
  const _PendingSkeleton();

  @override
  Widget build(BuildContext context) {
    return CarliCard(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s8),
      child: Column(
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: CarliSpace.s12),
              child: Row(
                spacing: CarliSpace.s12,
                children: [
                  CarliSkeleton.circle(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: CarliSpace.s8,
                      children: [
                        FractionallySizedBox(widthFactor: 0.45, child: CarliSkeleton(height: 14)),
                        FractionallySizedBox(widthFactor: 0.3, child: CarliSkeleton(height: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
