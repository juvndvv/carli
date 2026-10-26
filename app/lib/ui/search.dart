import 'package:flutter/material.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'icon.dart';
import 'pressable.dart';

class CarliSearchField extends StatefulWidget {
  const CarliSearchField({
    super.key,
    required this.controller,
    this.placeholder = 'Buscar',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<CarliSearchField> createState() => _CarliSearchFieldState();
}

class _CarliSearchFieldState extends State<CarliSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final noBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(CarliRadius.control),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autocorrect: false,
      style: CarliType.body.copyWith(color: colors.text),
      decoration: InputDecoration(
        hintText: widget.placeholder,
        filled: true,
        fillColor: colors.surface2,
        border: noBorder,
        enabledBorder: noBorder,
        focusedBorder: noBorder,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: CarliSpace.s12, right: CarliSpace.s8),
          child: CarliIcon(HugeIconsStrokeRounded.search01, size: 18, color: colors.text3),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 20),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : Semantics(
                button: true,
                label: 'Borrar búsqueda',
                child: Pressable(
                  onTap: _clear,
                  child: Padding(
                    padding: const EdgeInsets.all(CarliSpace.s12),
                    child: CarliIcon(HugeIconsStrokeRounded.cancelCircle, size: 18, color: colors.text3),
                  ),
                ),
              ),
      ),
    );
  }
}
