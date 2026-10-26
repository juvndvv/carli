import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format/money.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

enum MoneyInputSign { none, negative, positive }

enum MoneyInputAppearance { display, field }

class CarliMoneyInput extends StatefulWidget {
  const CarliMoneyInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.sign = MoneyInputSign.none,
    this.appearance = MoneyInputAppearance.display,
    this.allowNegative = false,
    this.autofocus = false,
    this.placeholder = '0,00',
    this.semanticLabel = 'Importe',
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final MoneyInputSign sign;
  final MoneyInputAppearance appearance;
  final bool allowNegative;
  final bool autofocus;
  final String placeholder;
  final String semanticLabel;

  @override
  State<CarliMoneyInput> createState() => CarliMoneyInputState();
}

class CarliMoneyInputState extends State<CarliMoneyInput> {
  late final _controller = TextEditingController(text: formatCentsForInput(widget.value, grouping: true));
  final _focus = FocusNode();
  var _invalid = false;

  bool get invalid => _invalid;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(CarliMoneyInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value != oldWidget.value) {
      _invalid = false;
      _controller.text = formatCentsForInput(widget.value, grouping: true);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_invalid) return;
    final text = formatCentsForInput(widget.value, grouping: !_focus.hasFocus);
    _controller.value = TextEditingValue(
      text: text,
      selection: _focus.hasFocus
          ? TextSelection(baseOffset: 0, extentOffset: text.length)
          : TextSelection.collapsed(offset: text.length),
    );
  }

  void _onChanged(String raw) {
    final cents = parseMoneyInput(raw);
    final accepted = cents != null && (widget.allowNegative || cents >= 0);
    setState(() => _invalid = raw.trim().isNotEmpty && !accepted);
    final next = accepted ? cents : null;
    if (next != widget.value) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final display = widget.appearance == MoneyInputAppearance.display;
    final color = _invalid
        ? colors.negative
        : widget.sign == MoneyInputSign.positive
        ? colors.positive
        : colors.text;
    final style = display
        ? CarliType.money(
            CarliType.display.copyWith(fontSize: 40, height: 48 / 40, fontWeight: FontWeight.w600, letterSpacing: -0.8),
          )
        : CarliType.money(CarliType.body);
    final signSymbol = switch (widget.sign) {
      MoneyInputSign.none => '',
      MoneyInputSign.negative => minusSign,
      MoneyInputSign.positive => '+',
    };
    final allowed = widget.allowNegative ? RegExp(r'[0-9.,\-−]') : RegExp(r'[0-9.,]');

    final field = TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: true, signed: widget.allowNegative),
      inputFormatters: [FilteringTextInputFormatter.allow(allowed)],
      textAlign: display ? TextAlign.center : TextAlign.start,
      onChanged: _onChanged,
      style: style.copyWith(color: color),
      cursorColor: colors.primary,
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: widget.placeholder,
        hintStyle: style.copyWith(color: colors.text3),
      ),
    );

    final row = Row(
      mainAxisAlignment: display ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: CarliSpace.s4,
      children: [
        if (signSymbol.isNotEmpty) Text(signSymbol, style: style.copyWith(color: color)),
        if (display) Flexible(child: IntrinsicWidth(child: field)) else Expanded(child: field),
        Text('€', style: style.copyWith(color: colors.text3)),
      ],
    );

    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: GestureDetector(
        onTap: _focus.requestFocus,
        child: display
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: CarliSpace.s8),
                child: row,
              )
            : Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(CarliRadius.md),
                  border: Border.all(
                    color: _invalid ? colors.negative : (_focus.hasFocus ? colors.text : colors.border),
                  ),
                ),
                child: row,
              ),
      ),
    );
  }
}
