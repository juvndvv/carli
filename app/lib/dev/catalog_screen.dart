import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../core/format/dates.dart';
import '../core/format/money.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../ui/amount.dart';
import '../ui/avatar.dart';
import '../ui/badge.dart';
import '../ui/button.dart';
import '../ui/card.dart';
import '../ui/category_picker.dart';
import '../ui/chart.dart';
import '../ui/chip.dart';
import '../ui/date_picker.dart';
import '../ui/empty_state.dart';
import '../ui/field.dart';
import '../ui/list_item.dart';
import '../ui/logo.dart';
import '../ui/money_input.dart';
import '../ui/page.dart';
import '../ui/progress.dart';
import '../ui/search.dart';
import '../ui/segmented.dart';
import '../ui/select.dart';
import '../ui/sheet.dart';
import '../ui/skeleton.dart';
import '../ui/stat.dart';
import '../ui/switch.dart';
import '../ui/tabs.dart';
import '../ui/toast.dart';

const _categories = [
  CarliCategory(id: 'food', name: 'Comida', icon: HugeIconsStrokeRounded.restaurant01),
  CarliCategory(id: 'shopping', name: 'Compras', icon: HugeIconsStrokeRounded.shoppingCart01),
  CarliCategory(id: 'transport', name: 'Transporte', icon: HugeIconsStrokeRounded.bus01),
  CarliCategory(id: 'home', name: 'Casa', icon: HugeIconsStrokeRounded.home01),
  CarliCategory(id: 'coffee', name: 'Cafés', icon: HugeIconsStrokeRounded.coffee01),
  CarliCategory(id: 'health', name: 'Salud', icon: HugeIconsStrokeRounded.medicine01),
  CarliCategory(id: 'travel', name: 'Viajes', icon: HugeIconsStrokeRounded.airplane01),
  CarliCategory(id: 'gifts', name: 'Regalos', icon: HugeIconsStrokeRounded.gift),
];

enum _Period { week, month, year }

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _text = TextEditingController(text: 'Mercadona');
  final _search = TextEditingController();
  int? _amount = 4250;
  int? _fieldAmount = 123456;
  String? _account = 'main';
  var _period = _Period.month;
  var _chip = 'all';
  var _switch = true;
  var _date = today();
  String? _category = 'food';
  var _tab = 0;

  @override
  void dispose() {
    _text.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final toast = ref.read(toastControllerProvider.notifier);
    final now = today();
    return CarliPage(
      title: 'Catálogo',
      bottomInset: 120,
      slivers: [
        SliverList.list(
          children: [
            CarliSection(
              title: 'Marca',
              child: Row(
                spacing: CarliSpace.s16,
                children: [
                  const CarliLogo(size: 30),
                  const CarliLogo(size: 48),
                  const CarliLogo(size: 48, eyeOpenness: 0.1),
                  Text('carli', style: CarliType.h1.copyWith(fontSize: 20, color: colors.text, letterSpacing: -0.6)),
                ],
              ),
            ),
            CarliSection(
              title: 'Botones',
              child: Column(
                spacing: CarliSpace.s8,
                children: [
                  CarliButton(label: 'Primario', icon: HugeIconsStrokeRounded.add01, onPressed: () {}),
                  CarliButton(
                    label: 'Secundario',
                    variant: CarliButtonVariant.secondary,
                    size: CarliButtonSize.md,
                    onPressed: () {},
                  ),
                  CarliButton(
                    label: 'Ghost',
                    variant: CarliButtonVariant.ghost,
                    size: CarliButtonSize.md,
                    onPressed: () {},
                  ),
                  CarliButton(
                    label: 'Eliminar',
                    variant: CarliButtonVariant.danger,
                    size: CarliButtonSize.md,
                    icon: HugeIconsStrokeRounded.delete02,
                    onPressed: () {},
                  ),
                  Wrap(
                    spacing: CarliSpace.s8,
                    runSpacing: CarliSpace.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CarliButton(label: 'Pequeño', size: CarliButtonSize.sm, block: false, onPressed: () {}),
                      CarliButton(
                        label: 'Cargando',
                        size: CarliButtonSize.sm,
                        block: false,
                        loading: true,
                        onPressed: () {},
                      ),
                      const CarliButton(label: 'Desactivado', size: CarliButtonSize.sm, block: false, onPressed: null),
                      CarliButton.icon(
                        icon: HugeIconsStrokeRounded.moreHorizontal,
                        semanticLabel: 'Más opciones',
                        onPressed: () {},
                      ),
                      CarliButton.icon(
                        icon: HugeIconsStrokeRounded.add01,
                        semanticLabel: 'Añadir',
                        variant: CarliButtonVariant.primary,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CarliSection(
              title: 'Campos',
              child: Column(
                spacing: CarliSpace.s16,
                children: [
                  CarliField(
                    label: 'Concepto',
                    child: CarliInput(controller: _text, placeholder: 'Ej. Mercadona'),
                  ),
                  CarliField(
                    label: 'Nota',
                    error: 'Máximo 200 caracteres.',
                    child: CarliInput(controller: TextEditingController(), placeholder: 'Opcional', invalid: true),
                  ),
                  CarliSearchField(controller: _search, placeholder: 'Buscar movimientos'),
                  CarliCard(
                    child: Column(
                      children: [
                        CarliMoneyInput(
                          value: _amount,
                          sign: MoneyInputSign.negative,
                          onChanged: (v) => setState(() => _amount = v),
                        ),
                        Text(
                          'Valor: ${_amount ?? '—'} céntimos',
                          style: CarliType.caption.copyWith(color: colors.text3),
                        ),
                      ],
                    ),
                  ),
                  CarliField(
                    label: 'Importe',
                    child: CarliMoneyInput(
                      value: _fieldAmount,
                      appearance: MoneyInputAppearance.field,
                      onChanged: (v) => setState(() => _fieldAmount = v),
                    ),
                  ),
                  CarliField(
                    label: 'Cuenta',
                    child: CarliSelect<String>(
                      title: 'Cuenta',
                      value: _account,
                      onChanged: (v) => setState(() => _account = v),
                      options: const [
                        CarliOption(
                          'main',
                          'Cuenta corriente',
                          icon: HugeIconsStrokeRounded.wallet01,
                          subtitle: 'BBVA · 4821',
                        ),
                        CarliOption('savings', 'Ahorro', icon: HugeIconsStrokeRounded.wallet01, subtitle: 'ING · 1093'),
                        CarliOption('cash', 'Efectivo', icon: HugeIconsStrokeRounded.wallet01),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            CarliSection(
              title: 'Selección',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: CarliSpace.s16,
                children: [
                  CarliSegmented<_Period>(
                    value: _period,
                    onChanged: (v) => setState(() => _period = v),
                    segments: const [
                      CarliSegment(_Period.week, 'Semana'),
                      CarliSegment(_Period.month, 'Mes'),
                      CarliSegment(_Period.year, 'Año'),
                    ],
                  ),
                  Wrap(
                    spacing: CarliSpace.s8,
                    children: [
                      for (final (id, label) in const [('all', 'Todos'), ('expense', 'Gastos'), ('income', 'Ingresos')])
                        CarliChip(label: label, selected: _chip == id, onTap: () => setState(() => _chip = id)),
                      CarliChip(icon: HugeIconsStrokeRounded.tag01, label: 'Etiqueta', onTap: () {}),
                    ],
                  ),
                  CarliDatePicker(value: _date, onChanged: (v) => setState(() => _date = v)),
                  Text(
                    formatRelativeDay(_date, style: RelativeDateStyle.title),
                    style: CarliType.small.copyWith(color: colors.text2),
                  ),
                  CarliCategoryPicker(
                    categories: _categories,
                    value: _category,
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  CarliTabs<int>(
                    tabs: const [(0, 'Gastos'), (1, 'Ingresos'), (2, 'Transferencias')],
                    value: _tab,
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                  CarliCard(
                    padding: EdgeInsets.zero,
                    child: CarliListItem(
                      title: 'Bloquear con Face ID',
                      icon: HugeIconsStrokeRounded.scanFace,
                      trailing: CarliSwitch(value: _switch, onChanged: (v) => setState(() => _switch = v)),
                    ),
                  ),
                ],
              ),
            ),
            CarliSection(
              title: 'Datos',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: CarliSpace.s12,
                children: [
                  const IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: CarliSpace.s12,
                      children: [
                        Expanded(
                          child: CarliStat(
                            label: 'Gastado este mes',
                            value: '1.234,56 €',
                            icon: HugeIconsStrokeRounded.wallet01,
                            delta: '12 % menos que septiembre',
                            deltaIcon: HugeIconsStrokeRounded.arrowDownLeft01,
                            deltaTone: CarliTone.positive,
                          ),
                        ),
                        Expanded(
                          child: CarliStat(label: 'Ingresos', value: '+2.695,00 €', tone: CarliTone.positive),
                        ),
                      ],
                    ),
                  ),
                  CarliCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: CarliSpace.s16,
                      children: [
                        for (final (name, spent, limit) in const [
                          ('Comida', 9000, 30000),
                          ('Ocio', 14100, 15000),
                          ('Ropa', 18250, 15000),
                        ])
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: CarliSpace.s8,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: CarliType.body.copyWith(fontWeight: FontWeight.w500, color: colors.text),
                                    ),
                                  ),
                                  CarliProgressFigure(spent: spent, limit: limit),
                                ],
                              ),
                              CarliProgress(ratio: ratioOf(spent, limit), label: name),
                            ],
                          ),
                        const CarliProgress(ratio: 0.42, tone: ProgressTone.goal, label: 'Objetivo'),
                      ],
                    ),
                  ),
                  const Wrap(
                    spacing: CarliSpace.s8,
                    runSpacing: CarliSpace.s8,
                    children: [
                      CarliBadge('Pendiente', icon: HugeIconsStrokeRounded.alert02),
                      CarliBadge('Nuevo', tone: CarliBadgeTone.primary),
                      CarliBadge('Pagado', tone: CarliBadgeTone.positive),
                      CarliBadge('Revisar', tone: CarliBadgeTone.warning),
                      CarliBadge('Error', tone: CarliBadgeTone.negative),
                    ],
                  ),
                  CarliCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        CarliListItem(
                          title: 'Mercadona',
                          subtitle: '${formatRelativeDay(now)} · Comida',
                          icon: HugeIconsStrokeRounded.shoppingCart01,
                          trailing: const CarliAmount(-4250),
                          onTap: () {},
                        ),
                        Divider(indent: 68, color: colors.border),
                        CarliListItem(
                          title: 'Nómina',
                          subtitle: '${formatRelativeDay(now.subtract(const Duration(days: 1)))} · Ingresos',
                          icon: HugeIconsStrokeRounded.wallet01,
                          trailing: const CarliAmount(269500),
                          onTap: () {},
                        ),
                        Divider(indent: 68, color: colors.border),
                        CarliListItem(
                          title: 'A ahorro',
                          subtitle: formatRelativeDay(now.subtract(const Duration(days: 4))),
                          icon: HugeIconsStrokeRounded.arrowRight01,
                          trailing: const CarliAmount(50000, kind: AmountKind.transfer),
                        ),
                        Divider(indent: 68, color: colors.border),
                        const CarliListItem(
                          title: 'Juanda',
                          subtitle: 'Compartido contigo',
                          leading: CarliAvatar(name: 'Juan Daniel'),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${formatMoney(123456789)} · ${formatMoneyCompact(150000)} · ${formatLongDate(now)}',
                    style: CarliType.small.copyWith(color: colors.text2),
                  ),
                ],
              ),
            ),
            CarliSection(
              title: 'Gráficos',
              child: Column(
                spacing: CarliSpace.s12,
                children: [
                  const CarliCard(
                    child: CarliChart(
                      type: CarliChartType.bar,
                      semanticLabel: 'Gastos e ingresos de los últimos cuatro meses',
                      labels: ['jul', 'ago', 'sep', 'oct'],
                      series: [
                        CarliSeries('Gastos', [182000, 151000, 167500, 123456]),
                        CarliSeries('Ingresos', [269500, 269500, 281000, 269500]),
                      ],
                    ),
                  ),
                  const CarliCard(
                    child: CarliChart(
                      type: CarliChartType.line,
                      semanticLabel: 'Saldo de los últimos seis meses',
                      labels: ['may', 'jun', 'jul', 'ago', 'sep', 'oct'],
                      series: [
                        CarliSeries('Saldo', [420000, 455000, 498000, 512000, 560000, 604000]),
                      ],
                    ),
                  ),
                  const CarliCard(
                    child: CarliChart(
                      type: CarliChartType.donut,
                      height: 180,
                      semanticLabel: 'Gasto por categoría este mes',
                      labels: ['Comida', 'Casa', 'Ocio', 'Transporte'],
                      series: [
                        CarliSeries('Octubre', [32000, 65000, 14100, 8200]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            CarliSection(
              title: 'Estados',
              child: Column(
                spacing: CarliSpace.s12,
                children: [
                  CarliCard(
                    child: CarliEmptyState(
                      icon: HugeIconsStrokeRounded.inbox,
                      title: 'Aún no hay movimientos',
                      message: 'Conecta un banco o añade tu primer gasto para empezar.',
                      actionLabel: 'Añadir gasto',
                      onAction: () {},
                    ),
                  ),
                  const CarliCard(
                    child: Row(
                      spacing: CarliSpace.s12,
                      children: [
                        CarliSkeleton.circle(size: 40),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: CarliSpace.s8,
                            children: [CarliSkeleton(width: 140), CarliSkeleton(width: 90, height: 12)],
                          ),
                        ),
                        CarliSkeleton(width: 60),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            CarliSection(
              title: 'Avisos y hojas',
              child: Column(
                spacing: CarliSpace.s8,
                children: [
                  CarliButton(
                    label: 'Toast con Deshacer',
                    variant: CarliButtonVariant.secondary,
                    size: CarliButtonSize.md,
                    onPressed: () => toast.withUndo('Movimiento eliminado', () => toast.show('Restaurado')),
                  ),
                  CarliButton(
                    label: 'Toast de error',
                    variant: CarliButtonVariant.secondary,
                    size: CarliButtonSize.md,
                    onPressed: () => toast.error('No se puede conectar con el servidor.'),
                  ),
                  CarliButton(
                    label: 'Abrir hoja',
                    variant: CarliButtonVariant.secondary,
                    size: CarliButtonSize.md,
                    onPressed: () => showCarliSheet<void>(
                      context,
                      title: 'Nuevo gasto',
                      builder: (context) => Padding(
                        padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s24),
                        child: Column(
                          spacing: CarliSpace.s16,
                          children: [
                            CarliMoneyInput(value: null, sign: MoneyInputSign.negative, onChanged: (_) {}),
                            CarliButton(label: 'Guardar', onPressed: () => Navigator.pop(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  CarliButton(
                    label: 'Confirmar borrado',
                    variant: CarliButtonVariant.secondary,
                    size: CarliButtonSize.md,
                    onPressed: () => confirmCarli(
                      context,
                      title: '¿Eliminar la cuenta?',
                      message: 'Se borrarán sus movimientos y no se puede deshacer.',
                      confirmLabel: 'Eliminar',
                      destructive: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
