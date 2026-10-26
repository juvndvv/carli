import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../ui/field.dart';
import '../../../../ui/icon.dart';
import '../../../../ui/icon_names.dart';
import '../../../../ui/list_item.dart';
import '../../../../ui/page.dart';
import '../../../../ui/segmented.dart';
import '../../../../ui/select.dart';
import '../../../../ui/skeleton.dart';
import '../../../../ui/switch.dart';
import '../../../../ui/toast.dart';
import '../../data/finance_changes.dart';
import '../../data/finance_providers.dart';
import '../../data/finance_settings_admin.dart';
import '../../data/models.dart';
import 'period_date_sheet.dart';

class FinanceSettingsScreen extends ConsumerWidget {
  const FinanceSettingsScreen({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(financeSettingsProvider);
    return CarliPage(
      title: 'Ajustes de Finanzas',
      onRefresh: () async {
        ref.read(financeChangesProvider.notifier).notify(const [
          FinanceScope.settings,
          FinanceScope.categories,
          FinanceScope.periods,
        ]);
        await ref.read(financeSettingsProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverList.list(
            children: [
              _SettingsCard(
                title: 'General',
                child: AsyncView(
                  value: settings,
                  errorTitle: 'No se han podido cargar los ajustes',
                  onRetry: () => ref.invalidate(financeSettingsProvider),
                  loading: const Padding(
                    padding: EdgeInsets.all(CarliSpace.s16),
                    child: Column(
                      spacing: CarliSpace.s12,
                      children: [CarliSkeleton(height: 44), CarliSkeleton(height: 44), CarliSkeleton(height: 44)],
                    ),
                  ),
                  data: (data) => GeneralSettingsForm(settings: data),
                ),
              ),
              const SizedBox(height: CarliSpace.s12),
              const _BanksCard(),
              const SizedBox(height: CarliSpace.s12),
              const _OpeningCategoriesCard(),
              const SizedBox(height: CarliSpace.s12),
              _PeriodsCard(now: now),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child, this.intro, this.action});

  final String title;
  final String? intro;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CarliCard(
      padding: const EdgeInsets.only(bottom: CarliSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, CarliSpace.s4),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: CarliType.h2.copyWith(color: colors.text)),
                  ),
                ),
                ?action,
              ],
            ),
          ),
          if (intro case final intro?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
              child: Text(intro, style: CarliType.small.copyWith(color: colors.text2)),
            ),
          child,
        ],
      ),
    );
  }
}

int? _parseInt(String text) => int.tryParse(text.trim());

class GeneralSettingsForm extends ConsumerStatefulWidget {
  const GeneralSettingsForm({super.key, required this.settings});

  final FinanceSettings settings;

  @override
  ConsumerState<GeneralSettingsForm> createState() => _GeneralSettingsFormState();
}

class _GeneralSettingsFormState extends ConsumerState<GeneralSettingsForm> {
  static const _lastUsed = '';

  late FinanceSettings _baseline = widget.settings;
  late String? _accountId = _baseline.defaultAccountId;
  late final _threshold = TextEditingController(text: '${_baseline.budgetWarningThreshold}');
  late final _remind = TextEditingController(text: '${_baseline.remindDaysBefore}');
  late final _minDays = TextEditingController(text: '${_baseline.periodMinDays}');
  late PeriodMode _mode = _baseline.periodMode;
  var _submitted = false;
  var _saving = false;
  var _serverErrors = <String, String>{};

  @override
  void didUpdateWidget(GeneralSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.settings, oldWidget.settings) && !_dirty && !_saving) _reset(widget.settings);
  }

  @override
  void dispose() {
    _threshold.dispose();
    _remind.dispose();
    _minDays.dispose();
    super.dispose();
  }

  void _reset(FinanceSettings settings) {
    _baseline = settings;
    _accountId = settings.defaultAccountId;
    _threshold.text = '${settings.budgetWarningThreshold}';
    _remind.text = '${settings.remindDaysBefore}';
    _minDays.text = '${settings.periodMinDays}';
    _mode = settings.periodMode;
    _submitted = false;
  }

  bool get _dirty =>
      _accountId != _baseline.defaultAccountId ||
      _threshold.text.trim() != '${_baseline.budgetWarningThreshold}' ||
      _remind.text.trim() != '${_baseline.remindDaysBefore}' ||
      _minDays.text.trim() != '${_baseline.periodMinDays}' ||
      _mode != _baseline.periodMode;

  String? _error(String field, TextEditingController controller, int baseline, int min, int max, String fallback) {
    if (_serverErrors[field] case final server?) return server;
    final value = _parseInt(controller.text);
    final valid = value != null && value >= min && value <= max;
    final touched = _submitted || controller.text.trim() != '$baseline';
    return !valid && touched ? fallback : null;
  }

  bool _inRange(TextEditingController controller, int min, int max) {
    final value = _parseInt(controller.text);
    return value != null && value >= min && value <= max;
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final valid =
        _inRange(_threshold, 1, 100) &&
        _inRange(_remind, 0, 30) &&
        (_mode == PeriodMode.calendar || _inRange(_minDays, 1, 60));
    if (!valid) return;
    final values = FinanceSettings(
      defaultAccountId: _accountId,
      budgetWarningThreshold: _parseInt(_threshold.text)!,
      remindDaysBefore: _parseInt(_remind.text)!,
      periodMode: _mode,
      periodMinDays: _inRange(_minDays, 1, 60) ? _parseInt(_minDays.text)! : _baseline.periodMinDays,
    );
    setState(() {
      _saving = true;
      _serverErrors = {};
    });
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      final periodsChanged = await ref.read(financeSettingsAdminRepositoryProvider).update(values);
      if (mounted) setState(() => _reset(values));
      toasts.show(periodsChanged ? 'Ajustes guardados · periodos recalculados' : 'Ajustes guardados');
    } catch (error) {
      if (mounted) setState(() => _serverErrors = _fieldErrors(error));
      toasts.error(apiErrorMessage(error, fallback: 'No se han podido guardar los ajustes.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, String> _fieldErrors(Object error) {
    final body = error is DioException ? error.response?.data : null;
    final errors = body is Map ? body['errors'] : null;
    if (errors is! Map) return {};
    return {
      for (final MapEntry(:key, :value) in errors.entries)
        if (value is List && value.isNotEmpty) '$key': '${value.first}',
    };
  }

  Widget _numberInput(TextEditingController controller, String semanticLabel, bool invalid) => Semantics(
    label: semanticLabel,
    child: CarliInput(
      controller: controller,
      keyboardType: TextInputType.number,
      invalid: invalid,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
      onChanged: (_) => setState(() => _serverErrors = {}),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value?.active ?? const [];
    final thresholdError = _error(
      'budget_warning_threshold',
      _threshold,
      _baseline.budgetWarningThreshold,
      1,
      100,
      'Entre 1 y 100.',
    );
    final remindError = _error('remind_days_before', _remind, _baseline.remindDaysBefore, 0, 30, 'Entre 0 y 30 días.');
    final minDaysError = _error('period_min_days', _minDays, _baseline.periodMinDays, 1, 60, 'Entre 1 y 60 días.');
    final accountError = _serverErrors['default_account_id'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s12, CarliSpace.s16, CarliSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          CarliField(
            label: 'Cuenta por defecto',
            hint: 'Si no eliges ninguna, se usa la última con la que apuntaste un movimiento.',
            error: accountError,
            child: CarliSelect<String>(
              title: 'Cuenta por defecto',
              placeholder: 'La última usada',
              value: _accountId ?? _lastUsed,
              invalid: accountError != null,
              options: [
                const CarliOption(_lastUsed, 'La última usada'),
                for (final account in accounts)
                  CarliOption(account.id, account.name, icon: carliIconNamed(account.icon ?? account.type.icon)),
              ],
              onChanged: (value) => setState(() {
                _accountId = value == _lastUsed ? null : value;
                _serverErrors = {};
              }),
            ),
          ),
          CarliField(
            label: 'Aviso de presupuesto (%)',
            hint: 'Te avisamos al llegar a este porcentaje y al superar el 100 %.',
            error: thresholdError,
            child: _numberInput(_threshold, 'Aviso de presupuesto (%)', thresholdError != null),
          ),
          CarliField(
            label: 'Avisar de cargos recurrentes',
            hint: 'Días de antelación para el aviso push.',
            error: remindError,
            child: _numberInput(_remind, 'Avisar de cargos recurrentes', remindError != null),
          ),
          CarliField(
            label: 'Periodo financiero',
            hint: _mode == PeriodMode.payroll
                ? 'Cada periodo empieza el día que registras la nómina y termina el día antes de la siguiente.'
                : 'Cada periodo va del día 1 al último día del mes.',
            child: CarliSegmented<PeriodMode>(
              value: _mode,
              onChanged: (value) => setState(() => _mode = value),
              segments: const [
                CarliSegment(PeriodMode.payroll, 'De nómina a nómina'),
                CarliSegment(PeriodMode.calendar, 'Mes natural'),
              ],
            ),
          ),
          if (_mode == PeriodMode.payroll)
            CarliField(
              label: 'Días mínimos entre nóminas',
              hint: 'Una paga extra antes de este plazo no abre periodo nuevo.',
              error: minDaysError,
              child: _numberInput(_minDays, 'Días mínimos entre nóminas', minDaysError != null),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: CarliButton(
              label: 'Guardar',
              size: CarliButtonSize.md,
              block: false,
              loading: _saving,
              onPressed: _dirty ? _save : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _BanksCard extends StatelessWidget {
  const _BanksCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _SettingsCard(
      title: 'Bancos',
      intro: 'Importa movimientos de Revolut, BBVA o MyInvestor y gestiona las reglas de categorización.',
      child: CarliListItem(
        title: 'Bancos y reglas',
        icon: carliIconNamed('landmark'),
        trailing: CarliIcon(carliIconNamed('chevron-right'), size: 18, color: colors.text3),
        onTap: () => context.push(Routes.banks),
      ),
    );
  }
}

class _OpeningCategoriesCard extends ConsumerStatefulWidget {
  const _OpeningCategoriesCard();

  @override
  ConsumerState<_OpeningCategoriesCard> createState() => _OpeningCategoriesCardState();
}

class _OpeningCategoriesCardState extends ConsumerState<_OpeningCategoriesCard> {
  final _pending = <String, bool>{};

  Future<void> _toggle(Category category, bool opensPeriod) async {
    setState(() => _pending[category.id] = opensPeriod);
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      await ref.read(financeSettingsAdminRepositoryProvider).setOpensPeriod(category.id, opensPeriod);
      toasts.show(opensPeriod ? '${category.name} abrirá periodo' : '${category.name} ya no abre periodo');
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido actualizar la categoría.'));
      ref.invalidate(categoriesProvider);
    } finally {
      if (mounted) setState(() => _pending.remove(category.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final categories = ref.watch(periodOpeningCategoriesProvider);
    return _SettingsCard(
      title: 'Categorías que abren periodo',
      intro: 'Al registrar un ingreso de estas categorías empieza un periodo nuevo.',
      child: AsyncView(
        value: categories,
        errorTitle: 'No se han podido cargar las categorías',
        onRetry: () => ref.invalidate(categoriesProvider),
        loading: const Padding(padding: EdgeInsets.all(CarliSpace.s16), child: CarliSkeleton(height: 44)),
        data: (items) => items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(CarliSpace.s16),
                child: Text('No tienes categorías de ingreso.', style: CarliType.small.copyWith(color: colors.text3)),
              )
            : Column(
                children: [
                  for (final (index, category) in items.indexed) ...[
                    if (index > 0) Divider(indent: 68, color: colors.border),
                    CarliListItem(
                      title: category.name,
                      icon: carliIconNamed(category.icon ?? fallbackCategoryIcon),
                      trailing: CarliSwitch(
                        value: _pending[category.id] ?? category.opensPeriod,
                        semanticLabel: 'Abre periodo: ${category.name}',
                        onChanged: _pending.containsKey(category.id) ? null : (value) => _toggle(category, value),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PeriodsCard extends ConsumerWidget {
  const _PeriodsCard({this.now});

  final DateTime? now;

  Future<void> _openManual(BuildContext context, WidgetRef ref) async {
    final date = await showPeriodDateSheet(
      context,
      title: 'Abrir periodo a mano',
      description: 'Útil si cobras en efectivo o se retrasa la nómina. El periodo anterior terminará el día antes.',
      confirmLabel: 'Abrir periodo',
      now: now,
    );
    if (date == null) return;
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      final period = await ref.read(financeSettingsAdminRepositoryProvider).openPeriod(date);
      toasts.show('Abierto el ${period.name.toLowerCase()}');
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido abrir el periodo.'));
    }
  }

  Future<void> _moveStart(BuildContext context, WidgetRef ref, Period period) async {
    final date = await showPeriodDateSheet(
      context,
      title: 'Mover inicio del periodo',
      description: '${period.label}. El periodo anterior se ajusta para terminar el día antes.',
      confirmLabel: 'Mover inicio',
      initial: period.startDate,
      now: now,
    );
    if (date == null || date == period.startDate) return;
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      await ref.read(financeSettingsAdminRepositoryProvider).movePeriodStart(period.id, date);
      toasts.show('Inicio del periodo actualizado');
    } catch (error) {
      toasts.error(apiErrorMessage(error, fallback: 'No se ha podido mover el periodo.'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final periods = ref.watch(periodsProvider.select((value) => value.whenData((periods) => periods.all)));
    return _SettingsCard(
      title: 'Periodos',
      action: CarliButton(
        label: 'Abrir periodo',
        icon: carliIconNamed('calendar-plus'),
        variant: CarliButtonVariant.ghost,
        size: CarliButtonSize.sm,
        block: false,
        onPressed: () => _openManual(context, ref),
      ),
      child: AsyncView(
        value: periods,
        errorTitle: 'No se han podido cargar los periodos',
        onRetry: () => ref.invalidate(periodsProvider),
        loading: const Padding(padding: EdgeInsets.all(CarliSpace.s16), child: CarliSkeleton(height: 44)),
        data: (items) => Column(
          children: [
            for (final (index, period) in items.take(6).indexed) ...[
              if (index > 0) Divider(indent: CarliSpace.s16, color: colors.border),
              CarliListItem(
                title: period.name,
                subtitle: period.subtitle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: CarliSpace.s4,
                  children: [
                    if (period.isCurrent)
                      const CarliBadge('En curso', tone: CarliBadgeTone.primary)
                    else
                      CarliBadge(period.openedBy.label),
                    CarliButton.icon(
                      icon: carliIconNamed('pencil'),
                      semanticLabel: 'Mover el inicio del ${period.name}',
                      size: CarliButtonSize.sm,
                      onPressed: () => _moveStart(context, ref, period),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
